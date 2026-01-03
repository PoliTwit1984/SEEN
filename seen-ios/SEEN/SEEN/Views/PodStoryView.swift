//
//  PodStoryView.swift
//  SEEN
//
//  Full-screen Instagram Stories-style view for pod check-ins
//

import SwiftUI

struct PodStoryView: View {
    let pod: PodWithStatus
    let onDismiss: () -> Void
    let onNavigateToPod: () -> Void
    
    @State private var feedItems: [FeedItem] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading = true
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    
    private let autoAdvanceInterval: TimeInterval = 5.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else if feedItems.isEmpty {
                    emptyState
                } else {
                    storyContent(geometry: geometry)
                }
                
                // Top bar with progress and close
                VStack {
                    topBar
                    Spacer()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.height > 100 {
                            // Swipe down to dismiss
                            onDismiss()
                        }
                    }
            )
            .onTapGesture { location in
                let width = geometry.size.width
                if location.x < width / 3 {
                    // Left third - go back
                    goToPrevious()
                } else if location.x > width * 2 / 3 {
                    // Right third - go forward
                    goToNext()
                }
                // Middle third - pause/resume handled separately
            }
        }
        .task {
            await loadStoryItems()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Story Content
    
    @ViewBuilder
    private func storyContent(geometry: GeometryProxy) -> some View {
        let item = feedItems[currentIndex]
        
        ZStack {
            // Photo background
            if let proofUrl = item.checkIn.proofUrl, let url = URL(string: proofUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    case .failure, .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
            
            // Gradient overlay for text readability
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
            .ignoresSafeArea()
            
            // Content overlay
            VStack {
                Spacer()
                
                // User info and goal
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        // User avatar and name
                        HStack(spacing: 12) {
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
                                
                                Text(timeAgo(from: item.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        
                        // Goal completed
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.seenGreen)
                            
                            Text(item.goal.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        
                        // Comment if any
                        if let comment = item.checkIn.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(3)
                        }
                    }
                    
                    Spacer()
                    
                    // Reactions
                    reactionButtons(for: item)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        VStack(spacing: 12) {
            // Progress bars
            HStack(spacing: 4) {
                ForEach(0..<feedItems.count, id: \.self) { index in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.3))
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: progressWidth(for: index, totalWidth: geo.size.width))
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Header row
            HStack {
                // Pod name - tap to navigate
                Button {
                    onNavigateToPod()
                } label: {
                    HStack(spacing: 8) {
                        // Pod initial
                        ZStack {
                            Circle()
                                .fill(Color.seenGreen.opacity(0.3))
                                .frame(width: 36, height: 36)
                            
                            Text(String(pod.name.prefix(1)).uppercased())
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        
                        Text(pod.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .accessibilityLabel("View \(pod.name) details")
                
                Spacer()
                
                // Close button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close stories")
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Reaction Buttons
    
    private func reactionButtons(for item: FeedItem) -> some View {
        VStack(spacing: 16) {
            ForEach(InteractionType.allCases, id: \.self) { type in
                Button {
                    Task {
                        await addReaction(type, to: item)
                    }
                } label: {
                    Text(type.emoji)
                        .font(.title)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(item.myInteractionType == type ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                        )
                }
                .accessibilityLabel("React with \(type.rawValue)")
            }
        }
    }
    
    // MARK: - Placeholder
    
    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.seenGreen.opacity(0.8), Color.seenMint.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.5))
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.5))
            
            Text("No check-ins yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Check-ins from pod members will appear here")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button("Close") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.seenGreen)
        }
        .padding()
    }
    
    // MARK: - Progress Calculation
    
    private func progressWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentIndex {
            return totalWidth // Completed
        } else if index == currentIndex {
            return totalWidth * progress // Current
        } else {
            return 0 // Not started
        }
    }
    
    // MARK: - Navigation
    
    private func goToNext() {
        if currentIndex < feedItems.count - 1 {
            currentIndex += 1
            progress = 0
            startTimer()
        } else {
            onDismiss()
        }
    }
    
    private func goToPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
            progress = 0
            startTimer()
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer?.invalidate()
        progress = 0
        
        let interval: TimeInterval = 0.05
        let increment = CGFloat(interval / autoAdvanceInterval)
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if progress >= 1 {
                goToNext()
            } else {
                progress += increment
            }
        }
    }
    
    // MARK: - Load Data
    
    private func loadStoryItems() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            feedItems = try await FeedService.shared.getPodFeed(podId: pod.id)
            
            // Mark pod as viewed
            try? await PodService.shared.markPodViewed(podId: pod.id)
            
            if !feedItems.isEmpty {
                startTimer()
            }
        } catch {
            print("Failed to load story items: \(error)")
        }
    }
    
    // MARK: - Reactions
    
    private func addReaction(_ type: InteractionType, to item: FeedItem) async {
        do {
            _ = try await FeedService.shared.addInteraction(checkInId: item.id, type: type)
            
            // Update local state
            if let index = feedItems.firstIndex(where: { $0.id == item.id }) {
                let updatedItem = FeedItem(
                    id: item.id,
                    type: item.type,
                    user: item.user,
                    goal: item.goal,
                    pod: item.pod,
                    checkIn: item.checkIn,
                    interactions: item.interactions,
                    interactionCount: item.hasInteracted ? item.interactionCount : item.interactionCount + 1,
                    hasInteracted: true,
                    myInteractionType: type,
                    createdAt: item.createdAt
                )
                feedItems[index] = updatedItem
            }
        } catch {
            print("Failed to add reaction: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func timeAgo(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }
        
        let elapsed = Date().timeIntervalSince(date)
        
        if elapsed < 60 {
            return "now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m ago"
        } else if elapsed < 86400 {
            return "\(Int(elapsed / 3600))h ago"
        } else {
            return "\(Int(elapsed / 86400))d ago"
        }
    }
}

#Preview {
    PodStoryView(
        pod: PodWithStatus(
            id: "1",
            name: "Run Club",
            memberCount: 4,
            maxMembers: 8,
            hasNewActivity: true,
            latestCheckInPhoto: nil,
            unreadCount: 3,
            myPendingGoals: 1
        ),
        onDismiss: {},
        onNavigateToPod: {}
    )
}
