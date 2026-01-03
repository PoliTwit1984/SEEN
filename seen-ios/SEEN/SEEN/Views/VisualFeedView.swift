//
//  VisualFeedView.swift
//  SEEN
//
//  Main visual feed screen with Pod Rings and photo feed
//

import SwiftUI

struct VisualFeedView: View {
    var authService: AuthService
    
    @State private var pods: [PodWithStatus] = []
    @State private var feedItems: [FeedItem] = []
    @State private var isLoadingPods = false
    @State private var isLoadingFeed = false
    @State private var errorMessage: String?
    
    // Navigation state
    @State private var showingCreatePod = false
    @State private var showingJoinPod = false
    @State private var showingAddMenu = false
    @State private var selectedPodForStory: PodWithStatus?
    @State private var showingCheckIn = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Main content
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Pod Rings section
                        podRingsSection
                        
                        // Divider
                        Divider()
                            .padding(.horizontal, 16)
                        
                        // Feed section
                        feedSection
                    }
                }
                .refreshable {
                    await refreshAll()
                }
                
                // Floating camera button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingCameraButton(hasPendingGoals: hasPendingGoals) {
                            showingCheckIn = true
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("SEEN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SEEN")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.seenGreen)
                }
            }
            .navigationDestination(for: String.self) { podId in
                PodDetailView(podId: podId)
            }
            .sheet(isPresented: $showingCreatePod) {
                CreatePodView { pod in
                    Task { await loadPods() }
                }
            }
            .sheet(isPresented: $showingJoinPod) {
                JoinPodView { pod in
                    Task { await loadPods() }
                }
            }
            .sheet(isPresented: $showingCheckIn) {
                CheckInSelectionView(pods: pods, onComplete: {
                    Task { await refreshAll() }
                })
            }
            .fullScreenCover(item: $selectedPodForStory) { pod in
                PodStoryView(
                    pod: pod,
                    onDismiss: {
                        selectedPodForStory = nil
                        Task { await loadPods() } // Refresh to update activity indicators
                    },
                    onNavigateToPod: {
                        selectedPodForStory = nil
                        navigationPath.append(pod.id)
                    }
                )
            }
            .confirmationDialog("Add Pod", isPresented: $showingAddMenu) {
                Button("Create New Pod") { showingCreatePod = true }
                Button("Join with Code") { showingJoinPod = true }
                Button("Cancel", role: .cancel) { }
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
            await refreshAll()
        }
    }
    
    // MARK: - Pod Rings Section
    
    private var podRingsSection: some View {
        Group {
            if isLoadingPods && pods.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 30)
            } else {
                PodRingsView(
                    pods: pods,
                    onAddTap: { showingAddMenu = true },
                    onPodTap: { pod in
                        selectedPodForStory = pod
                    }
                )
            }
        }
    }
    
    // MARK: - Feed Section
    
    private var feedSection: some View {
        Group {
            if isLoadingFeed && feedItems.isEmpty {
                LoadingView(message: "Loading feed...")
                    .padding(.top, 60)
            } else if feedItems.isEmpty {
                emptyFeedState
                    .padding(.top, 60)
            } else {
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
    }
    
    private var emptyFeedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("No Check-ins Yet")
                .font(.title2.weight(.semibold))
            
            Text("Complete a goal to see your check-in here, or join a pod to see activity from others")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if pods.isEmpty {
                Button("Create Your First Pod") {
                    showingCreatePod = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.seenGreen)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var hasPendingGoals: Bool {
        pods.contains { $0.myPendingGoals > 0 }
    }
    
    // MARK: - Data Loading
    
    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadPods() }
            group.addTask { await loadFeed() }
        }
    }
    
    private func loadPods() async {
        isLoadingPods = true
        defer { isLoadingPods = false }
        
        do {
            pods = try await PodService.shared.getPodsWithStatus()
        } catch {
            print("Load pods error: \(error)")
            // Fallback to regular pods if status endpoint not available
            do {
                let regularPods = try await PodService.shared.getMyPods()
                pods = regularPods.map { pod in
                    PodWithStatus(
                        id: pod.id,
                        name: pod.name,
                        memberCount: pod.memberCount,
                        maxMembers: pod.maxMembers,
                        hasNewActivity: false,
                        latestCheckInPhoto: nil,
                        unreadCount: 0,
                        myPendingGoals: 0
                    )
                }
            } catch {
                errorMessage = "Failed to load pods"
            }
        }
    }
    
    private func loadFeed() async {
        isLoadingFeed = true
        defer { isLoadingFeed = false }
        
        do {
            feedItems = try await FeedService.shared.getFeed()
        } catch {
            print("Load feed error: \(error)")
        }
    }
}

// MARK: - Check-In Selection View

struct CheckInSelectionView: View {
    let pods: [PodWithStatus]
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var selectedGoal: Goal?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading goals...")
                } else if goals.isEmpty {
                    emptyState
                } else {
                    goalsList
                }
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedGoal) { goal in
                NavigationStack {
                    GoalDetailView(goalId: goal.id)
                }
            }
        }
        .task {
            await loadGoals()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 50))
                .foregroundStyle(.seenGreen)
            
            Text("All Caught Up!")
                .font(.title2.weight(.semibold))
            
            Text("You have no pending goals to check in")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var goalsList: some View {
        List {
            ForEach(goals) { goal in
                Button {
                    selectedGoal = goal
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            if let desc = goal.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        if goal.needsProof {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(.seenGreen)
                        }
                        
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
    
    private func loadGoals() async {
        isLoading = true
        defer { isLoading = false }
        
        var allGoals: [Goal] = []
        
        for pod in pods {
            do {
                let podGoals = try await GoalService.shared.getPodGoals(podId: pod.id)
                allGoals.append(contentsOf: podGoals)
            } catch {
                print("Failed to load goals for pod \(pod.id): \(error)")
            }
        }
        
        goals = allGoals
    }
}

// MARK: - PodWithStatus Identifiable extension

extension PodWithStatus: Hashable {
    static func == (lhs: PodWithStatus, rhs: PodWithStatus) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    VisualFeedView(authService: AuthService.shared)
}
