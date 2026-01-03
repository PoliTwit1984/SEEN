//
//  MainTabView.swift
//  SEEN
//
//  Main tab navigation - Pod Stories with Unified Feed
//

import SwiftUI
import UIKit

struct MainTabView: View {
    var authService: AuthService
    
    var body: some View {
        TabView {
            Tab("Feed", systemImage: "house.fill") {
                UnifiedFeedView()
            }
            
            Tab("Profile", systemImage: "person.circle.fill") {
                ProfileView(authService: authService)
            }
        }
        .tint(.seenGreen)
    }
}

// MARK: - Unified Feed View (Home)

struct UnifiedFeedView: View {
    @State private var pods: [PodListItem] = []
    @State private var podRings: [PodRingData] = []
    @State private var selectedPodId: String = "all"
    @State private var feedPosts: [PodPost] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var nextCursor: String?
    @State private var showingCreatePod = false
    @State private var showingJoinPod = false
    @State private var showingCheckIn = false
    @State private var showingCreatePost = false
    @State private var showingPodDashboard = false
    @State private var showingActionSheet = false
    @State private var useMockData = false // For demo purposes
    
    // Selected pod info
    var selectedPod: PodRingData? {
        podRings.first { $0.id == selectedPodId }
    }
    
    var selectedPodItem: PodListItem? {
        pods.first { $0.id == selectedPodId }
    }
    
    // Filtered posts based on selection
    var filteredPosts: [PodPost] {
        if selectedPodId == "all" {
            return feedPosts
        } else {
            return feedPosts.filter { $0.podId == selectedPodId }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    if isLoading && pods.isEmpty {
                        Spacer()
                        ProgressView("Loading...")
                        Spacer()
                    } else if pods.isEmpty {
                        emptyState
                    } else {
                        // Pod rings at top (Instagram stories style)
                        PodRingsScrollView(
                            pods: podRings,
                            selectedPodId: $selectedPodId
                        )
                        
                        // Pod header when specific pod is selected
                        if selectedPodId != "all", let pod = selectedPod, let podItem = selectedPodItem {
                            PodHeaderView(
                                pod: pod,
                                podItem: podItem,
                                onViewDetails: { showingPodDashboard = true }
                            )
                        }
                        
                        Divider()
                        
                        // Unified feed
                        if filteredPosts.isEmpty && !isLoading {
                            emptyFeedState
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(filteredPosts) { post in
                                        UnifiedPostCard(post: post)
                                    }
                                    
                                    // Load more indicator
                                    if isLoadingMore {
                                        ProgressView()
                                            .padding()
                                    } else if nextCursor != nil && selectedPodId == "all" {
                                        Button("Load More") {
                                            Task { await loadMorePosts() }
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.seenGreen)
                                        .padding()
                                    }
                                }
                                .padding(.vertical)
                                .padding(.bottom, 80) // Space for FAB
                            }
                        }
                    }
                }
                
                // Floating Action Button
                if !pods.isEmpty {
                    FloatingActionButton(
                        onCheckIn: { showingCheckIn = true },
                        onEncourage: { showingCreatePost = true }
                    )
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("SEEN")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingCreatePod = true
                        } label: {
                            Label("Create Pod", systemImage: "plus.circle")
                        }
                        
                        Button {
                            showingJoinPod = true
                        } label: {
                            Label("Join Pod", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showingCreatePod) {
                CreatePodView { newPod in
                    Task { await loadData() }
                    selectedPodId = newPod.id
                }
            }
            .sheet(isPresented: $showingJoinPod) {
                JoinPodView { joinedPod in
                    Task { await loadData() }
                    selectedPodId = joinedPod.id
                }
            }
            .sheet(isPresented: $showingCheckIn) {
                CheckInSelectionView(
                    podId: selectedPodId == "all" ? nil : selectedPodId,
                    onComplete: { Task { await loadData() } }
                )
            }
            .sheet(isPresented: $showingCreatePost) {
                CreateEncouragementView(
                    podId: selectedPodId == "all" ? pods.first?.id : selectedPodId,
                    onComplete: { Task { await loadData() } }
                )
            }
            .sheet(isPresented: $showingPodDashboard) {
                if let podId = selectedPodId != "all" ? selectedPodId : nil {
                    PodDashboardSheet(podId: podId)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 60))
                .foregroundStyle(.seenGreen.opacity(0.6))
            
            Text("No Pods Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Create a pod to start tracking goals\nwith friends, or join an existing one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button {
                    showingCreatePod = true
                } label: {
                    Label("Create", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPrimary)
                
                Button {
                    showingJoinPod = true
                } label: {
                    Label("Join", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassSecondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
    }
    
    private var emptyFeedState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("No Activity Yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            if selectedPodId == "all" {
                Text("Check in on your goals to see\nactivity in the feed!")
            } else {
                Text("No posts in this pod yet.\nBe the first to share!")
            }
            
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding()
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Use mock data for demo
        if useMockData {
            loadMockData()
            return
        }
        
        do {
            // Load pods first
            pods = try await PodService.shared.getMyPods()
            
            // Convert to PodRingData
            podRings = pods.map { pod in
                PodRingData(
                    id: pod.id,
                    name: pod.name,
                    status: .allCompleted, // TODO: Calculate actual status
                    hasNewActivity: false, // TODO: Track new activity
                    isAllPods: false
                )
            }
            
            // Load unified feed
            let response = try await FeedService.shared.getUnifiedFeed()
            feedPosts = response.items
            nextCursor = response.nextCursor
            
        } catch let error as APIError {
            // If API fails, fall back to mock data for demo
            print("API error, using mock data: \(error)")
            loadMockData()
        } catch {
            print("Load data error, using mock data: \(error)")
            loadMockData()
        }
    }
    
    private func loadMockData() {
        // Mock pods with photos and member avatars
        podRings = [
            PodRingData(
                id: "pod1",
                name: "Fitness Squad",
                status: .allCompleted,
                hasNewActivity: true,
                isAllPods: false,
                photoUrl: "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=200",
                memberAvatars: []
            ),
            PodRingData(
                id: "pod2",
                name: "Book Club",
                status: .hasPending,
                hasNewActivity: false,
                isAllPods: false,
                photoUrl: nil,
                memberAvatars: ["https://i.pravatar.cc/100?img=12", "https://i.pravatar.cc/100?img=23", "https://i.pravatar.cc/100?img=15"]
            ),
            PodRingData(
                id: "pod3",
                name: "Morning Routines",
                status: .noGoals,
                hasNewActivity: true,
                isAllPods: false,
                photoUrl: "https://images.unsplash.com/photo-1545389336-cf090694435e?w=200",
                memberAvatars: []
            ),
        ]
        
        // Mock pod details with member info
        pods = [
            PodListItem(
                id: "pod1",
                name: "Fitness Squad",
                description: "Daily workouts and fitness challenges. Let's get fit together! 💪",
                stakes: "Loser buys coffee",
                memberCount: 4,
                maxMembers: 6,
                role: .MEMBER,
                joinedAt: ISO8601DateFormatter().string(from: Date()),
                createdAt: ISO8601DateFormatter().string(from: Date()),
                memberAvatars: ["https://i.pravatar.cc/100?img=5", "https://i.pravatar.cc/100?img=8", "https://i.pravatar.cc/100?img=12", "https://i.pravatar.cc/100?img=23"]
            ),
            PodListItem(
                id: "pod2",
                name: "Book Club",
                description: "Reading 20 pages a day. Share your progress and discuss!",
                stakes: nil,
                memberCount: 3,
                maxMembers: 5,
                role: .OWNER,
                joinedAt: ISO8601DateFormatter().string(from: Date()),
                createdAt: ISO8601DateFormatter().string(from: Date()),
                memberAvatars: ["https://i.pravatar.cc/100?img=12", "https://i.pravatar.cc/100?img=23", "https://i.pravatar.cc/100?img=15"]
            ),
            PodListItem(
                id: "pod3",
                name: "Morning Routines",
                description: "Wake up early, meditate, journal. Building better habits.",
                stakes: nil,
                memberCount: 5,
                maxMembers: 8,
                role: .MEMBER,
                joinedAt: ISO8601DateFormatter().string(from: Date()),
                createdAt: ISO8601DateFormatter().string(from: Date()),
                memberAvatars: ["https://i.pravatar.cc/100?img=9", "https://i.pravatar.cc/100?img=17", "https://i.pravatar.cc/100?img=21", "https://i.pravatar.cc/100?img=33", "https://i.pravatar.cc/100?img=44"]
            )
        ]
        
        // Mock feed posts from multiple pods
        feedPosts = [
            PodPost(
                id: "1",
                type: .CHECK_IN,
                content: "Just hit a 10-day streak! Feeling unstoppable!",
                mediaUrl: "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400",
                mediaType: .PHOTO,
                author: PostAuthor(id: "user1", name: "Sarah", avatarUrl: "https://i.pravatar.cc/150?img=5"),
                target: nil,
                podId: "pod1",
                podName: "Fitness Squad",
                goalTitle: "Morning Workout",
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800)),
                goalDescription: "30 minutes of exercise every morning before work",
                goalFrequency: "Daily",
                currentStreak: 10,
                completedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800)),
                reactionCount: 5,
                commentCount: 2,
                myReaction: .FIRE,
                topReactions: [.FIRE, .HIGH_FIVE]
            ),
            PodPost(
                id: "2",
                type: .ENCOURAGEMENT,
                content: "You've got this! Just 30 more pages to go!",
                mediaUrl: nil,
                mediaType: nil,
                author: PostAuthor(id: "user2", name: "Mike", avatarUrl: "https://i.pravatar.cc/150?img=12"),
                target: PostAuthor(id: "user3", name: "Emma", avatarUrl: nil),
                podId: "pod2",
                podName: "Book Club",
                goalTitle: nil,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
                goalDescription: nil,
                goalFrequency: nil,
                currentStreak: nil,
                completedAt: nil,
                reactionCount: 1,
                commentCount: 0,
                myReaction: nil,
                topReactions: [.HEART]
            ),
            PodPost(
                id: "3",
                type: .NUDGE,
                content: "Hey, don't forget your morning workout! We're waiting for your check-in",
                mediaUrl: nil,
                mediaType: nil,
                author: PostAuthor(id: "user4", name: "Alex", avatarUrl: "https://i.pravatar.cc/150?img=8"),
                target: PostAuthor(id: "user5", name: "Jordan", avatarUrl: nil),
                podId: "pod1",
                podName: "Fitness Squad",
                goalTitle: nil,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-5400)),
                goalDescription: nil,
                goalFrequency: nil,
                currentStreak: nil,
                completedAt: nil,
                reactionCount: 0,
                commentCount: 1,
                myReaction: nil,
                topReactions: []
            ),
            PodPost(
                id: "4",
                type: .CHECK_IN,
                content: "Morning meditation done! Starting the day with a clear mind",
                mediaUrl: "https://images.unsplash.com/photo-1545389336-cf090694435e?w=400",
                mediaType: .PHOTO,
                author: PostAuthor(id: "user6", name: "Luna", avatarUrl: "https://i.pravatar.cc/150?img=9"),
                target: nil,
                podId: "pod3",
                podName: "Morning Routines",
                goalTitle: "Morning Meditation",
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200)),
                goalDescription: "10 minutes of mindfulness every morning",
                goalFrequency: "Daily",
                currentStreak: 7,
                completedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200)),
                reactionCount: 3,
                commentCount: 0,
                myReaction: .HEART,
                topReactions: [.HEART, .CLAP]
            ),
            PodPost(
                id: "5",
                type: .ENCOURAGEMENT,
                content: "Great job on finishing that chapter! The ending was so good, right?",
                mediaUrl: nil,
                mediaType: nil,
                author: PostAuthor(id: "user3", name: "Emma", avatarUrl: "https://i.pravatar.cc/150?img=23"),
                target: PostAuthor(id: "user2", name: "Mike", avatarUrl: nil),
                podId: "pod2",
                podName: "Book Club",
                goalTitle: nil,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-10800)),
                goalDescription: nil,
                goalFrequency: nil,
                currentStreak: nil,
                completedAt: nil,
                reactionCount: 2,
                commentCount: 0,
                myReaction: nil,
                topReactions: [.HIGH_FIVE, .CLAP]
            ),
            PodPost(
                id: "6",
                type: .CHECK_IN,
                content: "5K run complete! Personal best time",
                mediaUrl: "https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400",
                mediaType: .PHOTO,
                author: PostAuthor(id: "user1", name: "Sarah", avatarUrl: "https://i.pravatar.cc/150?img=5"),
                target: nil,
                podId: "pod1",
                podName: "Fitness Squad",
                goalTitle: "Run 5K",
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-14400)),
                goalDescription: "Run 5 kilometers three times a week",
                goalFrequency: "Mon, Wed, Fri",
                currentStreak: 4,
                completedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-14400)),
                reactionCount: 8,
                commentCount: 3,
                myReaction: .FIRE,
                topReactions: [.FIRE, .HIGH_FIVE, .CLAP]
            ),
        ]
        
        nextCursor = nil
    }
    
    private func loadMorePosts() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let response = try await FeedService.shared.getUnifiedFeed(cursor: cursor)
            feedPosts.append(contentsOf: response.items)
            nextCursor = response.nextCursor
        } catch {
            print("Load more error: \(error)")
        }
    }
}

// MARK: - Unified Post Card (with Pod Badge, Metadata, and Interactions)

struct UnifiedPostCard: View {
    let post: PodPost
    let onReactionChanged: ((PodPost) -> Void)?

    @State private var showingComments = false
    @State private var currentReaction: InteractionType?
    @State private var reactionCount: Int

    init(post: PodPost, onReactionChanged: ((PodPost) -> Void)? = nil) {
        self.post = post
        self.onReactionChanged = onReactionChanged
        self._currentReaction = State(initialValue: post.myReaction)
        self._reactionCount = State(initialValue: post.reactionCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with pod badge
            HStack(spacing: 10) {
                // Author avatar
                authorAvatar

                VStack(alignment: .leading, spacing: 2) {
                    // Author name + target (or goal title for check-ins)
                    HStack(spacing: 4) {
                        Text(post.author.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if post.type == .CHECK_IN {
                            Text("checked in")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if let target = post.target {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(target.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Pod badge + time
                    HStack(spacing: 6) {
                        if let podName = post.podName {
                            Text(podName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.seenGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.seenGreen.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Text(timeAgo)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Post type emoji
                Text(post.type.emoji)
                    .font(.title2)
            }

            // Goal metadata for CHECK_IN type
            if post.type == .CHECK_IN {
                checkInMetadata
            }

            // Content
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            // Media
            if let mediaUrl = post.mediaUrl, let url = URL(string: mediaUrl) {
                mediaContent(url: url)
            }

            // Interaction bar
            interactionBar
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .sheet(isPresented: $showingComments) {
            CommentsSheet(
                itemType: post.type == .CHECK_IN ? "checkin" : "post",
                itemId: post.id
            )
        }
    }

    // MARK: - Check-in Metadata

    @ViewBuilder
    private var checkInMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Goal title
            if let goalTitle = post.goalTitle {
                Text(goalTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            // Goal description
            if let goalDescription = post.goalDescription, !goalDescription.isEmpty {
                Text(goalDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Badges row
            HStack(spacing: 10) {
                // Streak badge
                if let streak = post.currentStreak, streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streak) day\(streak == 1 ? "" : "s")")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }

                // Frequency badge
                if let frequency = post.goalFrequency {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .foregroundStyle(.seenBlue)
                        Text(frequency)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.seenBlue.opacity(0.15))
                    .clipShape(Capsule())
                }

                // Completion time
                if let completedAt = post.formattedCompletedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundStyle(.seenPurple)
                        Text(completedAt)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.seenPurple.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Interaction Bar

    private var interactionBar: some View {
        HStack(spacing: 0) {
            // Reaction buttons
            HStack(spacing: 2) {
                ForEach(InteractionType.allCases, id: \.self) { type in
                    ReactionButton(
                        type: type,
                        isSelected: currentReaction == type,
                        action: { toggleReaction(type) }
                    )
                }
            }

            Spacer()

            // Reaction count (if any)
            if reactionCount > 0 {
                Text("\(reactionCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
            }

            // Comment button
            Button {
                showingComments = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.subheadline)
                    if post.commentCount > 0 {
                        Text("\(post.commentCount)")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
            }
        }
        .padding(.top, 4)
    }

    private func toggleReaction(_ type: InteractionType) {
        Task {
            let itemType = post.type == .CHECK_IN ? "checkin" : "post"

            if currentReaction == type {
                // Remove reaction
                do {
                    try await FeedService.shared.removeReaction(itemType: itemType, itemId: post.id)
                    await MainActor.run {
                        currentReaction = nil
                        reactionCount = max(0, reactionCount - 1)
                    }
                } catch {
                    print("Failed to remove reaction: \(error)")
                }
            } else {
                // Add/change reaction
                let hadReaction = currentReaction != nil
                do {
                    _ = try await FeedService.shared.addReaction(itemType: itemType, itemId: post.id, type: type)
                    await MainActor.run {
                        currentReaction = type
                        if !hadReaction {
                            reactionCount += 1
                        }
                    }
                } catch {
                    print("Failed to add reaction: \(error)")
                }
            }
        }
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let avatarUrl = post.author.avatarUrl, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    avatarPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                case .failure:
                    avatarPlaceholder
                @unknown default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Text(String(post.author.name.prefix(1)).uppercased())
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.seenGreen, .seenMint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    @ViewBuilder
    private func mediaContent(url: URL) -> some View {
        switch post.mediaType {
        case .PHOTO:
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 200)
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                @unknown default:
                    EmptyView()
                }
            }
        case .VIDEO:
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .frame(height: 180)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Video")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                )
        case .AUDIO:
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.seenPurple.opacity(0.3), .seenBlue.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 80)
                .overlay(
                    HStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.seenPurple)
                        Text("Voice Message")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                )
        case .none:
            EmptyView()
        }
    }

    private var timeAgo: String {
        guard let date = post.createdAtDate else { return "" }

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
}

// MARK: - Reaction Button

struct ReactionButton: View {
    let type: InteractionType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(type.emoji)
                .font(.title3)
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .padding(6)
                .background(
                    isSelected ? Color.seenGreen.opacity(0.2) : Color.clear
                )
                .clipShape(Circle())
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Profile View

struct ProfileView: View {
    var authService: AuthService
    @State private var pods: [PodListItem] = []
    @State private var isLoadingPods = true
    @State private var showingSignOutAlert = false
    @State private var showingLeavePodAlert = false
    @State private var podToLeave: PodListItem?
    @State private var notificationsEnabled = false
    @State private var isRequestingNotifications = false
    @State private var errorMessage: String?
    
    // User stats
    @State private var userStats: UserStats?
    @State private var isLoadingStats = true
    
    // Photo picker
    @State private var showingPhotoOptions = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isUploadingAvatar = false
    
    // Computed stats with fallback to 0
    private var totalCheckIns: Int { userStats?.totalCheckIns ?? 0 }
    private var currentStreak: Int { userStats?.currentStreak ?? 0 }
    private var longestStreak: Int { userStats?.longestStreak ?? 0 }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header Card
                    profileHeader
                    
                    // Stats Cards
                    statsSection
                    
                    // My Pods Section
                    podsSection
                    
                    // Settings Section
                    settingsSection
                    
                    // Sign Out Button
                    signOutButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.logout()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Leave Pod", isPresented: $showingLeavePodAlert) {
                Button("Cancel", role: .cancel) { podToLeave = nil }
                Button("Leave", role: .destructive) {
                    if let pod = podToLeave {
                        Task { await leavePod(pod) }
                    }
                }
            } message: {
                if let pod = podToLeave {
                    Text("Are you sure you want to leave \"\(pod.name)\"? You'll lose access to all goals and activity in this pod.")
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            if authService.currentUser == nil {
                await authService.fetchCurrentUser()
            }
            notificationsEnabled = NotificationService.shared.isAuthorized
            await loadPods()
            await loadStats()
        }
    }
    
    private func loadStats() async {
        isLoadingStats = true
        defer { isLoadingStats = false }
        
        if let stats = await authService.fetchUserStats() {
            userStats = stats
        }
    }
    
    private func uploadNewAvatar(_ image: UIImage) async {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        
        do {
            _ = try await authService.uploadAvatar(image: image)
        } catch {
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar - Tappable to change
            Button {
                showingPhotoOptions = true
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.seenGreen, .seenMint, .seenBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .seenGreen.opacity(0.3), radius: 10, y: 5)
                    
                    if isUploadingAvatar {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    } else if let user = authService.currentUser {
                        if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 92, height: 92)
                                    .clipShape(Circle())
                            } placeholder: {
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        } else {
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    // Camera badge overlay
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.seenGreen)
                        )
                        .offset(x: 35, y: 35)
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
            }
            .disabled(isUploadingAvatar)
            .confirmationDialog("Change Profile Photo", isPresented: $showingPhotoOptions, titleVisibility: .visible) {
                Button("Take Photo") {
                    showingCamera = true
                }
                Button("Choose from Library") {
                    showingImagePicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    Task { await uploadNewAvatar(image) }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera) { image in
                    Task { await uploadNewAvatar(image) }
                }
            }
            
            // Name & Email
            if let user = authService.currentUser {
                VStack(spacing: 4) {
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let email = user.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Member since badge
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("Member since \(memberSinceText)")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var memberSinceText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        // Try to use memberSince from stats, or createdAt from user
        if let memberSince = userStats?.memberSince,
           let date = ISO8601DateFormatter().date(from: memberSince) {
            return formatter.string(from: date)
        } else if let createdAt = authService.currentUser?.createdAt,
                  let date = ISO8601DateFormatter().date(from: createdAt) {
            return formatter.string(from: date)
        }
        
        return formatter.string(from: Date())
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            HStack(spacing: 12) {
                ProfileStatCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(currentStreak)",
                    label: "Current Streak",
                    bgGradient: [.orange.opacity(0.15), .red.opacity(0.1)]
                )
                
                ProfileStatCard(
                    icon: "trophy.fill",
                    iconColor: .yellow,
                    value: "\(longestStreak)",
                    label: "Best Streak",
                    bgGradient: [.yellow.opacity(0.15), .orange.opacity(0.1)]
                )
                
                ProfileStatCard(
                    icon: "checkmark.circle.fill",
                    iconColor: .seenGreen,
                    value: "\(totalCheckIns)",
                    label: "Check-ins",
                    bgGradient: [.seenGreen.opacity(0.15), .seenMint.opacity(0.1)]
                )
            }
        }
    }
    
    // MARK: - Pods Section
    
    private var podsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Pods")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(pods.count) pod\(pods.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
            
            if isLoadingPods {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 32)
            } else if pods.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No pods yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Join or create a pod from the Feed tab")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(pods) { pod in
                        ProfilePodRow(pod: pod) {
                            podToLeave = pod
                            showingLeavePodAlert = true
                        }
                        
                        if pod.id != pods.last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                // Timezone
                if let user = authService.currentUser {
                    SettingsRow(
                        icon: "globe",
                        iconColor: .blue,
                        title: "Timezone",
                        value: user.timezone,
                        action: nil
                    )
                    
                    Divider().padding(.leading, 50)
                }
                
                // Notifications
                SettingsRow(
                    icon: notificationsEnabled ? "bell.badge.fill" : "bell",
                    iconColor: notificationsEnabled ? .seenGreen : .gray,
                    title: "Notifications",
                    value: notificationsEnabled ? "Enabled" : "Off",
                    valueColor: notificationsEnabled ? .seenGreen : .secondary,
                    showChevron: !notificationsEnabled,
                    isLoading: isRequestingNotifications
                ) {
                    if !notificationsEnabled {
                        Task { await requestNotifications() }
                    }
                }
                
                Divider().padding(.leading, 50)
                
                // Version
                SettingsRow(
                    icon: "info.circle",
                    iconColor: .gray,
                    title: "Version",
                    value: "1.0.0",
                    action: nil
                )
                
                Divider().padding(.leading, 50)
                
                // Privacy Policy
                Link(destination: URL(string: "https://seen.app/privacy")!) {
                    SettingsRow(
                        icon: "hand.raised",
                        iconColor: .purple,
                        title: "Privacy Policy",
                        showChevron: true,
                        isExternal: true,
                        action: nil
                    )
                }
                
                Divider().padding(.leading, 50)
                
                // Terms
                Link(destination: URL(string: "https://seen.app/terms")!) {
                    SettingsRow(
                        icon: "doc.text",
                        iconColor: .orange,
                        title: "Terms of Service",
                        showChevron: true,
                        isExternal: true,
                        action: nil
                    )
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Sign Out Button
    
    private var signOutButton: some View {
        Button {
            showingSignOutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(.headline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Actions
    
    private func loadPods() async {
        isLoadingPods = true
        defer { isLoadingPods = false }
        
        do {
            pods = try await PodService.shared.getMyPods()
        } catch {
            // Use mock data on error
            pods = [
                PodListItem(
                    id: "pod1",
                    name: "Fitness Squad",
                    description: "Daily workouts and fitness challenges",
                    stakes: "Loser buys coffee",
                    memberCount: 4,
                    maxMembers: 6,
                    role: .MEMBER,
                    joinedAt: ISO8601DateFormatter().string(from: Date()),
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    memberAvatars: nil
                ),
                PodListItem(
                    id: "pod2",
                    name: "Book Club",
                    description: "Reading 20 pages a day",
                    stakes: nil,
                    memberCount: 3,
                    maxMembers: 5,
                    role: .OWNER,
                    joinedAt: ISO8601DateFormatter().string(from: Date()),
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    memberAvatars: nil
                ),
                PodListItem(
                    id: "pod3",
                    name: "Morning Routines",
                    description: "Wake up early, meditate, journal",
                    stakes: nil,
                    memberCount: 5,
                    maxMembers: 8,
                    role: .MEMBER,
                    joinedAt: ISO8601DateFormatter().string(from: Date()),
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    memberAvatars: nil
                )
            ]
        }
    }
    
    private func leavePod(_ pod: PodListItem) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            try await PodService.shared.leavePod(podId: pod.id, userId: userId)
            pods.removeAll { $0.id == pod.id }
            podToLeave = nil
        } catch {
            errorMessage = "Failed to leave pod: \(error.localizedDescription)"
        }
    }
    
    private func requestNotifications() async {
        isRequestingNotifications = true
        defer { isRequestingNotifications = false }
        
        let granted = await NotificationService.shared.requestPermission()
        notificationsEnabled = granted
    }
}

// MARK: - Profile Stat Card

private struct ProfileStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let bgGradient: [Color]
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: bgGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Profile Pod Row

private struct ProfilePodRow: View {
    let pod: PodListItem
    let onLeave: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Pod icon
            ZStack {
                Circle()
                    .fill(podColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text(String(pod.name.prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(podColor)
            }
            
            // Pod info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(pod.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if pod.role == .OWNER {
                        Text("OWNER")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.seenGreen)
                            .clipShape(Capsule())
                    }
                }
                
                Text("\(pod.memberCount) member\(pod.memberCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Leave button (not for owners)
            if pod.role != .OWNER {
                Button {
                    onLeave()
                } label: {
                    Text("Leave")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private var podColor: Color {
        // Generate consistent color based on pod name
        let colors: [Color] = [.seenGreen, .seenBlue, .seenPurple, .orange, .pink]
        let index = abs(pod.name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var value: String? = nil
    var valueColor: Color = .secondary
    var showChevron: Bool = false
    var isExternal: Bool = false
    var isLoading: Bool = false
    var action: (() -> Void)?
    
    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                } else if let value = value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(valueColor)
                }
                
                if showChevron {
                    Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .disabled(action == nil)
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView(authService: AuthService.shared)
}
