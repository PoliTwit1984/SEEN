//
//  LaunchScreen.swift
//  SEEN
//
//  Splash screen shown on app launch
//

import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false
    @State private var showTagline = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.seenGreen, Color.seenGreen.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Logo/Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                    
                    Image(systemName: "eye.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(.white)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                }
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                
                // App name
                Text("SEEN")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(8)
                
                // Tagline
                if showTagline {
                    Text("Accountability that works")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showTagline = true
            }
        }
    }
}

#Preview {
    LaunchScreen()
}
