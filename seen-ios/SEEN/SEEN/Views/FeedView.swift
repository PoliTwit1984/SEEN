//
//  FeedView.swift
//  SEEN
//
//  Activity feed showing pod members' check-ins
//

import SwiftUI

struct FeedView: View {
    let podId: String?
    
    @State private var feedItems: [FeedItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    init(podId: String? = nil) {
        self.podId = podId
    }
    
    var body: some View {
        Group {
            if isLoading && feedItems.isEmpty {
                LoadingView(message: "Loading feed...")
            } else if feedItems.isEmpty {
                emptyState
            } else {
                feedList
            }
        }
        .task {
            await loadFeed()
        }
        .refreshable {
            await loadFeed()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No Activity Yet",
            message: "Check-ins from your pods will appear here"
        )
    }
    
    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(feedItems) { item in
                    FeedItemCard(item: item) { updatedItem in
                        if let index = feedItems.firstIndex(where: { $0.id == updatedItem.id }) {
                            feedItems[index] = updatedItem
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func loadFeed() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let podId = podId {
                feedItems = try await FeedService.shared.getPodFeed(podId: podId)
            } else {
                feedItems = try await FeedService.shared.getFeed()
            }
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to load feed"
            print("Load feed error: \(error)")
        }
    }
}

// MARK: - Feed Item Card

struct FeedItemCard: View {
    let item: FeedItem
    let onUpdate: (FeedItem) -> Void
    
    @State private var isReacting = false
    @State private var showingReactions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.seenGreen.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    Text(String(item.user.name.prefix(1)))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.user.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 4) {
                        Text("completed")
                            .foregroundStyle(.white.opacity(0.5))
                        Text(item.goal.title)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.seenGreen)
                    }
                    .font(.subheadline)
                    .lineLimit(1)
                }
                
                Spacer()
                
                Text(timeAgo)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            // Proof photo if any
            if let proofUrl = item.checkIn.proofUrl, !proofUrl.isEmpty {
                AsyncImage(url: URL(string: proofUrl)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 100)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.leading, 56)
            }
            
            // Comment if any
            if let comment = item.checkIn.comment, !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.leading, 56)
            }
            
            // Pod badge
            if let pod = item.pod {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.caption2)
                    Text(pod.name)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.leading, 56)
            }
            
            // Reactions bar
            HStack {
                // Existing reactions
                if item.interactionCount > 0 {
                    reactionsSummary
                }
                
                Spacer()
                
                // Add reaction button
                Button {
                    showingReactions = true
                } label: {
                    HStack(spacing: 4) {
                        if let myType = item.myInteractionType {
                            Text(myType.emoji)
                        } else {
                            Image(systemName: "hand.thumbsup")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .font(.title3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(item.hasInteracted ? Color.seenGreen.opacity(0.3) : .white.opacity(0.1))
                    )
                }
                .disabled(isReacting)
            }
            .padding(.leading, 56)
        }
        .padding()
        .glassBackground()
        .confirmationDialog("React", isPresented: $showingReactions) {
            ForEach(InteractionType.allCases, id: \.self) { type in
                Button("\(type.emoji) \(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)") {
                    Task { await addReaction(type) }
                }
            }
            if item.hasInteracted {
                Button("Remove Reaction", role: .destructive) {
                    Task { await removeReaction() }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var reactionsSummary: some View {
        HStack(spacing: -4) {
            // Show unique reaction emojis
            let uniqueTypes = Set(item.interactions.map { $0.type })
            ForEach(Array(uniqueTypes.prefix(3)), id: \.self) { type in
                Text(type.emoji)
                    .font(.caption)
            }
            
            Text("\(item.interactionCount)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 4)
        }
    }
    
    private var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: item.createdAt) else {
            return ""
        }
        
        let elapsed = Date().timeIntervalSince(date)
        
        if elapsed < 60 {
            return "now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m"
        } else if elapsed < 86400 {
            return "\(Int(elapsed / 3600))h"
        } else {
            return "\(Int(elapsed / 86400))d"
        }
    }
    
    private func addReaction(_ type: InteractionType) async {
        isReacting = true
        defer { isReacting = false }
        
        do {
            _ = try await FeedService.shared.addInteraction(checkInId: item.id, type: type)
            
            // Update local state
            var updatedItem = item
            let newInteraction = FeedInteraction(
                id: UUID().uuidString,
                type: type,
                userId: "", // Will be filled by server
                userName: ""
            )
            
            // This is a simplified update - in production you'd refetch
            var interactions = item.interactions
            if let existingIndex = interactions.firstIndex(where: { $0.userId == "" }) {
                interactions[existingIndex] = newInteraction
            } else {
                interactions.append(newInteraction)
            }
            
            // Create updated item with new values
            updatedItem = FeedItem(
                id: item.id,
                type: item.type,
                user: item.user,
                goal: item.goal,
                pod: item.pod,
                checkIn: item.checkIn,
                interactions: interactions,
                interactionCount: item.hasInteracted ? item.interactionCount : item.interactionCount + 1,
                hasInteracted: true,
                myInteractionType: type,
                createdAt: item.createdAt
            )
            
            onUpdate(updatedItem)
        } catch {
            print("Add reaction error: \(error)")
        }
    }
    
    private func removeReaction() async {
        isReacting = true
        defer { isReacting = false }
        
        do {
            try await FeedService.shared.removeInteraction(checkInId: item.id)
            
            // Update local state
            let updatedItem = FeedItem(
                id: item.id,
                type: item.type,
                user: item.user,
                goal: item.goal,
                pod: item.pod,
                checkIn: item.checkIn,
                interactions: item.interactions.filter { $0.userId != "" },
                interactionCount: max(0, item.interactionCount - 1),
                hasInteracted: false,
                myInteractionType: nil,
                createdAt: item.createdAt
            )
            
            onUpdate(updatedItem)
        } catch {
            print("Remove reaction error: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        FeedView()
    }
}
