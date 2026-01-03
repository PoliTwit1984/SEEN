//
//  HomeView.swift
//  SEEN
//
//  Main home view with pod list
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
                    ProgressView("Loading pods...")
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
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await loadPods()
            }
            .sheet(isPresented: $showingCreatePod) {
                CreatePodView { pod in
                    // Add the new pod to the list
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("No Pods Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create a pod to get started or\njoin one with an invite code")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: { showingCreatePod = true }) {
                    Label("Create Pod", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: { showingJoinPod = true }) {
                    Label("Join Pod", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 48)
            
            Spacer()
            
            // Welcome message
            if let user = authService.currentUser {
                Text("Welcome, \(user.name)!")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
        }
    }
    
    // MARK: - Pod List
    
    private var podListView: some View {
        List(pods) { pod in
            NavigationLink(destination: PodDetailView(podId: pod.id)) {
                PodRowView(pod: pod)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Load Pods
    
    private func loadPods() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            pods = try await PodService.shared.getMyPods()
        } catch {
            errorMessage = "Failed to load pods"
            print("Load pods error: \(error)")
        }
    }
}

// MARK: - Pod Row

struct PodRowView: View {
    let pod: PodListItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pod.name)
                    .font(.headline)
                
                Spacer()
                
                if pod.role == .OWNER {
                    Text("Owner")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor)
                        .cornerRadius(4)
                }
            }
            
            if let description = pod.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("\(pod.memberCount)/\(pod.maxMembers)", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let stakes = pod.stakes, !stakes.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(stakes)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HomeView(authService: AuthService.shared)
}
