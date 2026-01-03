//
//  HomeView.swift
//  SEEN
//
//  Main home view with pod list - HIG Compliant
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
            Group {
                if isLoading && pods.isEmpty {
                    LoadingView(message: "Loading pods...")
                } else if pods.isEmpty {
                    emptyStateView
                } else {
                    podListView
                }
            }
            .navigationTitle("My Pods")
            .toolbar {
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
                    }
                    .accessibilityLabel("Add pod")
                    .accessibilityHint("Double tap to create or join a pod")
                }
            }
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
        List {
            ForEach(pods) { pod in
                NavigationLink(destination: PodDetailView(podId: pod.id)) {
                    PodRow(pod: pod)
                }
                .accessibilityLabel("\(pod.name), \(pod.memberCount) of \(pod.maxMembers) members")
                .accessibilityHint("Double tap to view pod details")
            }
        }
        .listStyle(.insetGrouped)
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

// MARK: - Pod Row

struct PodRow: View {
    let pod: PodListItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pod.name)
                    .font(.headline)
                
                Spacer()
                
                // Member count badge
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(pod.memberCount)/\(pod.maxMembers)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            
            if let description = pod.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                // Stakes if any
                if let stakes = pod.stakes, !stakes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.orange)
                        Text(stakes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Role badge
                Text(pod.role.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(pod.role == .OWNER ? Color.seenGreen : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(pod.role == .OWNER ? Color.seenGreen.opacity(0.15) : Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HomeView(authService: AuthService.shared)
}
