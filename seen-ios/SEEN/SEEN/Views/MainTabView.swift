//
//  MainTabView.swift
//  SEEN
//
//  Main tab navigation - Liquid Glass Design
//

import SwiftUI

struct MainTabView: View {
    var authService: AuthService
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: $selectedTab) {
                HomeView(authService: authService)
                    .tag(0)
                
                NavigationStack {
                    ZStack {
                        AnimatedGradientBackground()
                        FeedView()
                    }
                    .navigationTitle("")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Activity")
                                .font(.seenHeadline)
                                .foregroundStyle(.white)
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
                }
                .tag(1)
                
                ProfileView(authService: authService)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom glass tab bar
            GlassTabBar(selectedTab: $selectedTab)
        }
    }
}

// MARK: - Glass Tab Bar

struct GlassTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabs: [(icon: String, label: String)] = [
        ("person.3.fill", "Pods"),
        ("bubble.left.and.bubble.right.fill", "Activity"),
        ("person.circle.fill", "Profile")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == index {
                                Circle()
                                    .fill(Color.seenGreen.opacity(0.3))
                                    .blur(radius: 10)
                                    .frame(width: 40, height: 40)
                            }
                            
                            Image(systemName: tabs[index].icon)
                                .font(.system(size: 22, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundStyle(selectedTab == index ? Color.seenGreen : .white.opacity(0.5))
                        }
                        
                        Text(tabs[index].label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
        .glassBackground(cornerRadius: 0)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Profile View (Glass Style)

struct ProfileView: View {
    var authService: AuthService
    @State private var showingSignOutAlert = false
    @State private var notificationsEnabled = false
    @State private var isRequestingNotifications = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // User Avatar Card
                        if let user = authService.currentUser {
                            GlassCard {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.seenGreen.opacity(0.3))
                                            .frame(width: 70, height: 70)
                                        
                                        Text(String(user.name.prefix(1)))
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.name)
                                            .font(.seenHeadline)
                                            .foregroundStyle(.white)
                                        
                                        if let email = user.email {
                                            Text(email)
                                                .font(.seenCaption)
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            // Timezone
                            GlassCard {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundStyle(Color.seenBlue)
                                    Text("Timezone")
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    Text(user.timezone)
                                        .foregroundStyle(.white)
                                }
                                .font(.seenBody)
                            }
                        }
                        
                        // Notifications
                        GlassCard {
                            VStack(spacing: 16) {
                                if notificationsEnabled {
                                    HStack {
                                        Image(systemName: "bell.badge.fill")
                                            .foregroundStyle(Color.seenGreen)
                                        Text("Notifications")
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text("Enabled")
                                            .foregroundStyle(Color.seenGreen)
                                    }
                                } else {
                                    Button {
                                        Task { await requestNotifications() }
                                    } label: {
                                        HStack {
                                            Image(systemName: "bell")
                                                .foregroundStyle(.white.opacity(0.7))
                                            Text("Enable Notifications")
                                                .foregroundStyle(.white)
                                            Spacer()
                                            if isRequestingNotifications {
                                                ProgressView()
                                                    .tint(.white)
                                            } else {
                                                Image(systemName: "chevron.right")
                                                    .foregroundStyle(.white.opacity(0.4))
                                            }
                                        }
                                    }
                                    .disabled(isRequestingNotifications)
                                }
                            }
                            .font(.seenBody)
                        }
                        
                        // App Info
                        GlassCard {
                            HStack {
                                Text("Version")
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("1.0.0")
                                    .foregroundStyle(.white)
                            }
                            .font(.seenBody)
                        }
                        
                        // Sign Out
                        Button {
                            showingSignOutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .foregroundStyle(.red)
                            .font(.seenBody.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassBackground()
                        }
                    }
                    .padding()
                    .padding(.bottom, 100) // Extra padding for tab bar
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(.seenHeadline)
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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

#Preview {
    MainTabView(authService: AuthService.shared)
}
