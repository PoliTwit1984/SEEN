//
//  MainTabView.swift
//  SEEN
//
//  Main tab navigation after authentication
//

import SwiftUI

struct MainTabView: View {
    var authService: AuthService
    
    var body: some View {
        TabView {
            HomeView(authService: authService)
                .tabItem {
                    Label("Pods", systemImage: "person.3.fill")
                }
            
            NavigationStack {
                FeedView()
            }
            .tabItem {
                Label("Activity", systemImage: "bubble.left.and.bubble.right.fill")
            }
            
            ProfileView(authService: authService)
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    var authService: AuthService
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                if let user = authService.currentUser {
                    Section {
                        HStack {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Text(String(user.name.prefix(1)))
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                }
                            
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                if let email = user.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section {
                        Label(user.timezone, systemImage: "globe")
                    } header: {
                        Text("Timezone")
                    }
                }
                
                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("App")
                }
                
                // Sign Out
                Section {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
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
        }
    }
}

#Preview {
    MainTabView(authService: AuthService.shared)
}
