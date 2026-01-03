//
//  FeedView.swift
//  SEEN
//
//  Visual activity feed with photo-first design
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
            icon: "camera.fill",
            title: "No Check-ins Yet",
            message: "When you and your pod members complete goals, they'll appear here"
        )
    }
    
    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(feedItems) { item in
                    PhotoFeedCard(item: item) { updatedItem in
                        if let index = feedItems.firstIndex(where: { $0.id == updatedItem.id }) {
                            feedItems[index] = updatedItem
                        }
                    }
                }
            }
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

// MARK: - Photo Feed Card (Instagram-style)

struct PhotoFeedCard: View {
    let item: FeedItem
    let onUpdate: (FeedItem) -> Void
    
    @State private var isReacting = false
    @State private var showDoubleTapHeart = false
    @State private var showingReactions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - User and Pod info
            headerSection
            
            // Photo (main content)
            photoSection
            
            // Action bar
            actionBar
            
            // Reactions summary
            if item.interactionCount > 0 {
                reactionsSummary
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            
            // Goal and comment
            captionSection
        }
        .padding(.bottom, 16)
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
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.seenGreen, Color.seenMint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text(String(item.user.name.prefix(1)))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.user.name)
                    .font(.subheadline.weight(.semibold))
                
                if let pod = item.pod {
                    Text(pod.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text(timeAgo)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.user.name) in \(item.pod?.name ?? "pod"), \(timeAgo)")
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        GeometryReader { geometry in
            ZStack {
                if let proofUrl = item.checkIn.proofUrl, !proofUrl.isEmpty, let url = URL(string: proofUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholderView
                                .overlay {
                                    ProgressView()
                                        .tint(.white)
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.width)
                                .clipped()
                        case .failure:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
                
                // Double-tap heart animation
                if showDoubleTapHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                handleDoubleTap()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(item.checkIn.proofUrl != nil ? "Photo proof for check-in" : "Check-in completed")
    }
    
    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.seenGreen.opacity(0.6), Color.seenMint.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text(item.goal.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack(spacing: 16) {
            // Reaction buttons
            HStack(spacing: 12) {
                ForEach(InteractionType.allCases.prefix(4), id: \.self) { type in
                    Button {
                        Task { await addReaction(type) }
                    } label: {
                        Text(type.emoji)
                            .font(.title2)
                            .opacity(item.myInteractionType == type ? 1 : 0.6)
                            .scaleEffect(item.myInteractionType == type ? 1.2 : 1)
                            .animation(.spring(response: 0.3), value: item.myInteractionType)
                    }
                    .disabled(isReacting)
                    .accessibilityLabel("React with \(type.rawValue)")
                }
            }
            
            Spacer()
            
            // More reactions
            Button {
                showingReactions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("More reactions")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Reactions Summary
    
    private var reactionsSummary: some View {
        HStack(spacing: 4) {
            let uniqueTypes = Set(item.interactions.map { $0.type })
            ForEach(Array(uniqueTypes.prefix(3)), id: \.self) { type in
                Text(type.emoji)
                    .font(.caption)
            }
            
            Text("\(item.interactionCount) reactions")
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("\(item.interactionCount) reactions")
    }
    
    // MARK: - Caption Section
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Goal completed label
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.seenGreen)
                    .font(.caption)
                
                Text("Completed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.seenGreen)
                
                Text(item.goal.title)
                    .font(.caption.weight(.semibold))
            }
            
            // Comment if any
            if let comment = item.checkIn.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Time Ago
    
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
    
    // MARK: - Double Tap Handler
    
    private func handleDoubleTap() {
        guard !isReacting else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showDoubleTapHeart = true
        }
        
        Task {
            await addReaction(.FIRE)
            
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            withAnimation(.easeOut(duration: 0.3)) {
                showDoubleTapHeart = false
            }
        }
    }
    
    // MARK: - Reaction Handlers
    
    private func addReaction(_ type: InteractionType) async {
        isReacting = true
        defer { isReacting = false }
        
        do {
            _ = try await FeedService.shared.addInteraction(checkInId: item.id, type: type)
            
            let newInteraction = FeedInteraction(
                id: UUID().uuidString,
                type: type,
                userId: "",
                userName: ""
            )
            
            var interactions = item.interactions
            if let existingIndex = interactions.firstIndex(where: { $0.userId == "" }) {
                interactions[existingIndex] = newInteraction
            } else {
                interactions.append(newInteraction)
            }
            
            let updatedItem = FeedItem(
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

// MARK: - Legacy Feed Item Card (for backward compatibility)

struct FeedItemCard: View {
    let item: FeedItem
    let onUpdate: (FeedItem) -> Void
    
    var body: some View {
        PhotoFeedCard(item: item, onUpdate: onUpdate)
    }
}

#Preview {
    NavigationStack {
        FeedView()
    }
}
