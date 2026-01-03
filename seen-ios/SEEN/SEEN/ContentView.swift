//
//  ContentView.swift
//  SEEN
//
//  Root view that switches between auth and home
//

import SwiftUI

struct ContentView: View {
    @State private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                HomeView(authService: authService)
            } else {
                AuthView(authService: authService)
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

#Preview {
    ContentView()
}
