//
//  FloatingCameraButton.swift
//  SEEN
//
//  Floating action button for quick check-ins
//

import SwiftUI

struct FloatingCameraButton: View {
    let hasPendingGoals: Bool
    let action: () -> Void
    
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse animation when goals are pending
                if hasPendingGoals {
                    Circle()
                        .fill(Color.seenGreen.opacity(0.3))
                        .frame(width: 70, height: 70)
                        .scaleEffect(isPulsing ? 1.2 : 1)
                        .opacity(isPulsing ? 0 : 0.5)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.seenGreen, Color.seenMint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.seenGreen.opacity(0.4), radius: 8, y: 4)
                
                // Camera icon
                Image(systemName: "camera.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                
                // Pending badge
                if hasPendingGoals {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 20, y: -20)
                }
            }
        }
        .accessibilityLabel("Check in")
        .accessibilityHint(hasPendingGoals ? "You have pending goals to complete" : "Double tap to check in on a goal")
        .onAppear {
            if hasPendingGoals {
                isPulsing = true
            }
        }
        .onChange(of: hasPendingGoals) { _, newValue in
            isPulsing = newValue
        }
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            FloatingCameraButton(hasPendingGoals: false) {
                print("Tapped - no pending")
            }
            
            FloatingCameraButton(hasPendingGoals: true) {
                print("Tapped - has pending")
            }
        }
    }
}
