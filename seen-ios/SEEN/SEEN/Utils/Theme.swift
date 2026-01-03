//
//  Theme.swift
//  SEEN
//
//  App-wide styling - iOS 26 Liquid Glass compatible
//

import SwiftUI

// MARK: - Brand Colors
// Colors are now defined in Assets.xcassets with light/dark variants
// Xcode auto-generates Color.seenGreen, Color.seenMint, etc.
// Only define additional colors not in the asset catalog here:

extension Color {
    // Lighter variant of seenGreen (not in asset catalog)
    static let seenGreenLight = Color(red: 0.345, green: 0.878, blue: 0.506)
}

// MARK: - Typography (Dynamic Type Support)

extension Font {
    // These use semantic text styles that automatically scale with Dynamic Type
    static let seenLargeTitle = Font.largeTitle.weight(.bold)
    static let seenTitle = Font.title.weight(.bold)
    static let seenHeadline = Font.headline
    static let seenSubheadline = Font.subheadline.weight(.medium)
    static let seenBody = Font.body
    static let seenCaption = Font.caption
}

// MARK: - Glass Background Modifier
// Simplified for iOS 26 - will work with native .glassEffect() when available

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Card
// Container that applies glass effect with padding

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    
    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .glassBackground()
    }
}

// MARK: - Animated Gradient Background
// Rich, colorful background that works well behind glass elements

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if colorScheme == .dark {
                darkBackground
            } else {
                lightBackground
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
    
    private var darkBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.1, blue: 0.2),
                Color(red: 0.1, green: 0.15, blue: 0.25),
                Color(red: 0.08, green: 0.12, blue: 0.22),
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .overlay {
            // Subtle floating orbs for depth
            GeometryReader { geo in
                Circle()
                    .fill(Color.seenGreen.opacity(0.12))
                    .blur(radius: 60)
                    .frame(width: 300, height: 300)
                    .offset(x: -50, y: animateGradient ? 100 : 200)
                
                Circle()
                    .fill(Color.seenPurple.opacity(0.08))
                    .blur(radius: 80)
                    .frame(width: 400, height: 400)
                    .offset(x: geo.size.width - 150, y: animateGradient ? 400 : 300)
            }
        }
    }
    
    private var lightBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.92, green: 0.95, blue: 0.98),
                Color(red: 0.94, green: 0.96, blue: 0.99),
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .overlay {
            GeometryReader { geo in
                Circle()
                    .fill(Color.seenGreen.opacity(0.1))
                    .blur(radius: 60)
                    .frame(width: 300, height: 300)
                    .offset(x: -50, y: animateGradient ? 100 : 200)
                
                Circle()
                    .fill(Color.seenBlue.opacity(0.08))
                    .blur(radius: 80)
                    .frame(width: 400, height: 400)
                    .offset(x: geo.size.width - 150, y: animateGradient ? 400 : 300)
            }
        }
    }
}

// MARK: - Button Styles

struct GlassPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44) // Accessibility: minimum tap target
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled ? [.seenGreen, .seenGreenLight] : [.gray, .gray.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44) // Accessibility: minimum tap target
            .padding(.vertical, 14)
            .glassBackground(cornerRadius: 14)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassPrimaryButtonStyle {
    static var glassPrimary: GlassPrimaryButtonStyle { GlassPrimaryButtonStyle() }
}

extension ButtonStyle where Self == GlassSecondaryButtonStyle {
    static var glassSecondary: GlassSecondaryButtonStyle { GlassSecondaryButtonStyle() }
}

// MARK: - Streak Badge

struct StreakBadge: View {
    let count: Int
    var size: CGFloat = 24
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text("\(count)")
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .font(.system(size: size * 0.6))
        .padding(.horizontal, size * 0.5)
        .padding(.vertical, size * 0.25)
        .glassBackground(cornerRadius: size)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) day streak")
    }
}

// MARK: - Glass Text Field

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            
            TextField(placeholder, text: $text)
                .foregroundStyle(.primary)
                .tint(.seenGreen)
        }
        .padding()
        .glassBackground(cornerRadius: 14)
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
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.seenGreen.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .buttonStyle(.glassPrimary)
                    .padding(.horizontal, 48)
                    .padding(.top, 8)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
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
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#Preview("Glass Components") {
    ZStack {
        AnimatedGradientBackground()
        
        ScrollView {
            VStack(spacing: 24) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Glass Card")
                            .font(.headline)
                        Text("This is a glass card with frosted effect")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button("Primary Action") {}
                    .buttonStyle(.glassPrimary)
                
                Button("Secondary Action") {}
                    .buttonStyle(.glassSecondary)
                
                HStack {
                    StreakBadge(count: 7)
                    StreakBadge(count: 30, size: 32)
                }
                
                GlassTextField(placeholder: "Enter text...", text: .constant(""), icon: "magnifyingglass")
                
                LoadingView()
            }
            .padding()
        }
    }
}

#Preview("Empty State") {
    ZStack {
        AnimatedGradientBackground()
        
        EmptyStateView(
            icon: "person.3",
            title: "No Pods Yet",
            message: "Create or join a pod to start your accountability journey",
            action: {},
            actionLabel: "Create Pod"
        )
    }
}
