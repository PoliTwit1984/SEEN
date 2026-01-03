//
//  FloatingActionButton.swift
//  SEEN
//
//  Floating action button with check-in and encourage actions
//

import SwiftUI

struct FloatingActionButton: View {
    let onCheckIn: () -> Void
    let onEncourage: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Action buttons (shown when expanded)
            if isExpanded {
                // Encourage button
                ActionButton(
                    icon: "heart.fill",
                    label: "Encourage",
                    color: .seenMint
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded = false
                    }
                    onEncourage()
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity).combined(with: .offset(y: 20)),
                    removal: .scale.combined(with: .opacity)
                ))
                
                // Check-in button
                ActionButton(
                    icon: "checkmark.circle.fill",
                    label: "Check In",
                    color: .seenGreen
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded = false
                    }
                    onCheckIn()
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity).combined(with: .offset(y: 20)),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            // Main FAB
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.seenGreen, .seenGreen.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .seenGreen.opacity(0.3), radius: 8, y: 4)
                    
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(width: 56, height: 56)
            }
            .accessibilityLabel(isExpanded ? "Close actions" : "Open actions")
            .accessibilityHint("Double tap to \(isExpanded ? "close" : "open") check-in and encourage actions")
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Image(systemName: icon)
                    .font(.body)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 4, y: 2)
            )
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingActionButton(
                    onCheckIn: { print("Check in tapped") },
                    onEncourage: { print("Encourage tapped") }
                )
                .padding()
            }
        }
    }
}
