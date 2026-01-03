//
//  MainTabView.swift
//  SEEN
//
//  Main tab navigation - Pod-centric design with dashboard
//

import SwiftUI

struct MainTabView: View {
    var authService: AuthService
    
    var body: some View {
        TabView {
            Tab("Pods", systemImage: "person.3.fill") {
                PodSelectorView()
            }
            
            Tab("Profile", systemImage: "person.circle.fill") {
                ProfileView(authService: authService)
            }
        }
        .tint(.seenGreen)
    }
}

// MARK: - Pod Selector View (Home)

struct PodSelectorView: View {
    @State private var pods: [PodListItem] = []
    @State private var selectedPodId: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCreatePod = false
    @State private var showingJoinPod = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading && pods.isEmpty {
                    Spacer()
                    ProgressView("Loading pods...")
                    Spacer()
                } else if pods.isEmpty {
                    emptyState
                } else {
                    // Pod selector tabs
                    podSelectorTabs
                    
                    // Selected pod dashboard
                    if let podId = selectedPodId {
                        PodDashboardView(podId: podId)
                    }
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
                await loadPods()
            }
            .refreshable {
                await loadPods()
            }
            .sheet(isPresented: $showingCreatePod) {
                CreatePodView { newPod in
                    Task { await loadPods() }
                    selectedPodId = newPod.id
                }
            }
            .sheet(isPresented: $showingJoinPod) {
                JoinPodView { joinedPod in
                    Task { await loadPods() }
                    selectedPodId = joinedPod.id
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
    
    private var podSelectorTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pods) { pod in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPodId = pod.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(String(pod.name.prefix(1)))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(selectedPodId == pod.id ? Color.seenGreen : Color.gray)
                                )
                            
                            Text(pod.name)
                                .font(.subheadline)
                                .fontWeight(selectedPodId == pod.id ? .semibold : .regular)
                                .foregroundStyle(selectedPodId == pod.id ? .primary : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedPodId == pod.id ? Color.seenGreen.opacity(0.15) : Color(.systemGray6))
                        )
                    }
                    .accessibilityLabel("Pod: \(pod.name)")
                    .accessibilityAddTraits(selectedPodId == pod.id ? .isSelected : [])
                }
                
                // Add pod button
                Button {
                    showingCreatePod = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.seenGreen)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .strokeBorder(Color.seenGreen, lineWidth: 1.5)
                        )
                }
                .accessibilityLabel("Create new pod")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private func loadPods() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            pods = try await PodService.shared.getMyPods()
            
            // Select first pod if none selected
            if selectedPodId == nil, let firstPod = pods.first {
                selectedPodId = firstPod.id
            }
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to load pods"
            print("Load pods error: \(error)")
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    var authService: AuthService
    @State private var showingSignOutAlert = false
    @State private var notificationsEnabled = false
    @State private var isRequestingNotifications = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                if let user = authService.currentUser {
                    Section {
                        HStack(spacing: 16) {
                            // Profile avatar
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.seenGreen, Color.seenMint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                
                                Text(String(user.name.prefix(1)))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                            .accessibilityHidden(true)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.title3.weight(.semibold))
                                
                                if let email = user.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Profile: \(user.name)")
                    }
                    
                    // Stats Section
                    Section("Stats") {
                        StatRow(icon: "flame.fill", color: .orange, label: "Current Streak", value: "–")
                        StatRow(icon: "trophy.fill", color: .yellow, label: "Longest Streak", value: "–")
                        StatRow(icon: "checkmark.circle.fill", color: .seenGreen, label: "Total Check-ins", value: "–")
                    }
                    
                    // Settings Section
                    Section("Settings") {
                        // Timezone
                        HStack {
                            Label("Timezone", systemImage: "globe")
                            Spacer()
                            Text(user.timezone)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Timezone: \(user.timezone)")
                        
                        // Notifications
                        if notificationsEnabled {
                            HStack {
                                Label {
                                    Text("Notifications")
                                } icon: {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundStyle(.seenGreen)
                                }
                                Spacer()
                                Text("Enabled")
                                    .foregroundStyle(.seenGreen)
                            }
                            .accessibilityLabel("Notifications enabled")
                        } else {
                            Button {
                                Task { await requestNotifications() }
                            } label: {
                                HStack {
                                    Label("Enable Notifications", systemImage: "bell")
                                    Spacer()
                                    if isRequestingNotifications {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .disabled(isRequestingNotifications)
                            .accessibilityLabel("Enable notifications")
                            .accessibilityHint("Double tap to request notification permissions")
                        }
                    }
                }
                
                // App Info Section
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://seen.app/privacy")!) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://seen.app/terms")!) {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityHint("Double tap to sign out of your account")
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.logout()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
        .task {
            if authService.currentUser == nil {
                await authService.fetchCurrentUser()
            }
            notificationsEnabled = NotificationService.shared.isAuthorized
        }
    }
    
    private func requestNotifications() async {
        isRequestingNotifications = true
        defer { isRequestingNotifications = false }
        
        let granted = await NotificationService.shared.requestPermission()
        notificationsEnabled = granted
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MainTabView(authService: AuthService.shared)
}
