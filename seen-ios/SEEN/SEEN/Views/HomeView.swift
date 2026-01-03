//
//  HomeView.swift
//  SEEN
//
//  Main home view with pod list - Liquid Glass Design
//

import SwiftUI

struct HomeView: View {
    var authService: AuthService
    
    @State private var pods: [PodListItem] = []
    @State private var isLoading = false
    @State private var showingCreatePod = false
    @State private var showingJoinPod = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                Group {
                    if isLoading && pods.isEmpty {
                        LoadingView(message: "Loading pods...")
                    } else if pods.isEmpty {
                        emptyStateView
                    } else {
                        podListView
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Pods")
                        .font(.seenHeadline)
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingCreatePod = true }) {
                            Label("Create Pod", systemImage: "plus.circle")
                        }
                        Button(action: { showingJoinPod = true }) {
                            Label("Join Pod", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .refreshable {
                await loadPods()
            }
            .sheet(isPresented: $showingCreatePod) {
                CreatePodView { pod in
                    let item = PodListItem(
                        id: pod.id,
                        name: pod.name,
                        description: pod.description,
                        stakes: pod.stakes,
                        memberCount: 1,
                        maxMembers: pod.maxMembers,
                        role: .OWNER,
                        joinedAt: pod.createdAt,
                        createdAt: pod.createdAt
                    )
                    pods.insert(item, at: 0)
                }
            }
            .sheet(isPresented: $showingJoinPod) {
                JoinPodView { pod in
                    await loadPods()
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
            await loadPods()
        }
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "person.3.fill",
            title: "No Pods Yet",
            message: "Create a pod to get started or join one with an invite code",
            action: { showingCreatePod = true },
            actionLabel: "Create Pod"
        )
    }
    
    private var podListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(pods) { pod in
                    NavigationLink(destination: PodDetailView(podId: pod.id)) {
                        PodCard(pod: pod)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    private func loadPods() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            pods = try await PodService.shared.getMyPods()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to load pods"
        }
    }
}

// MARK: - Pod Card (Glass Style)

struct PodCard: View {
    let pod: PodListItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pod.name)
                        .font(.seenHeadline)
                        .foregroundStyle(.white)
                    
                    if let description = pod.description {
                        Text(description)
                            .font(.seenCaption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Member count badge
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(pod.memberCount)/\(pod.maxMembers)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.1))
                )
            }
            
            // Stakes if any
            if let stakes = pod.stakes, !stakes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.orange)
                    Text(stakes)
                        .font(.seenCaption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            // Role badge
            HStack {
                Text(pod.role.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(pod.role == .OWNER ? Color.seenGreen : .white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(pod.role == .OWNER ? Color.seenGreen.opacity(0.2) : .white.opacity(0.1))
                    )
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(20)
        .glassBackground()
    }
}

#Preview {
    HomeView(authService: AuthService.shared)
}
