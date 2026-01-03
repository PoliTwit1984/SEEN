//
//  Theme.swift
//  SEEN
//
//  App-wide styling and theming
//

import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let seenGreen = Color(red: 0.263, green: 0.820, blue: 0.424)
    static let seenGreenLight = Color(red: 0.345, green: 0.878, blue: 0.506)
    static let seenBackground = Color(.systemBackground)
    static let seenSecondaryBackground = Color(.secondarySystemBackground)
}

// MARK: - Typography

extension Font {
    static let seenTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let seenHeadline = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let seenSubheadline = Font.system(size: 16, weight: .medium, design: .rounded)
    static let seenBody = Font.system(size: 16, weight: .regular, design: .default)
    static let seenCaption = Font.system(size: 13, weight: .regular, design: .default)
}

// MARK: - Button Styles

struct SeenPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.seenHeadline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isEnabled ? Color.seenGreen : Color.gray)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SeenSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.seenSubheadline)
            .foregroundColor(.seenGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.seenGreen, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SeenPrimaryButtonStyle {
    static var seenPrimary: SeenPrimaryButtonStyle { SeenPrimaryButtonStyle() }
}

extension ButtonStyle where Self == SeenSecondaryButtonStyle {
    static var seenSecondary: SeenSecondaryButtonStyle { SeenSecondaryButtonStyle() }
}

// MARK: - Card Style

struct SeenCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.seenSecondaryBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

extension View {
    func seenCard() -> some View {
        modifier(SeenCardModifier())
    }
}

// MARK: - Streak Badge

struct StreakBadge: View {
    let count: Int
    var size: CGFloat = 24
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(count)")
                .fontWeight(.bold)
        }
        .font(.system(size: size * 0.6))
        .padding(.horizontal, size * 0.5)
        .padding(.vertical, size * 0.25)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.15))
        )
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            
            Text(title)
                .font(.seenHeadline)
            
            Text(message)
                .font(.seenBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .buttonStyle(.seenPrimary)
                    .padding(.horizontal, 48)
                    .padding(.top, 8)
            }
        }
        .padding()
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var message: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.seenCaption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Buttons") {
    VStack(spacing: 20) {
        Button("Check In") {}
            .buttonStyle(.seenPrimary)
        
        Button("Join Pod") {}
            .buttonStyle(.seenSecondary)
        
        StreakBadge(count: 7)
    }
    .padding()
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "person.3",
        title: "No Pods Yet",
        message: "Create or join a pod to start your accountability journey",
        action: {},
        actionLabel: "Create Pod"
    )
}
