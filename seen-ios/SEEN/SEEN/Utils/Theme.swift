//
//  Theme.swift
//  SEEN
//
//  App-wide styling with liquid glass aesthetic
//

import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let seenGreen = Color(red: 0.263, green: 0.820, blue: 0.424)
    static let seenGreenLight = Color(red: 0.345, green: 0.878, blue: 0.506)
    static let seenMint = Color(red: 0.4, green: 0.95, blue: 0.7)
    static let seenPurple = Color(red: 0.6, green: 0.4, blue: 0.9)
    static let seenBlue = Color(red: 0.3, green: 0.6, blue: 0.95)
}

// MARK: - Glass Background Modifier

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    var opacity: CGFloat = 0.7
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Frosted glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Glass border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 20, opacity: CGFloat = 0.7) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, opacity: opacity))
    }
}

// MARK: - Glass Card

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

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.1, blue: 0.2),
                Color(red: 0.1, green: 0.15, blue: 0.25),
                Color(red: 0.08, green: 0.12, blue: 0.22),
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
        .overlay {
            // Subtle floating orbs for depth
            GeometryReader { geo in
                Circle()
                    .fill(Color.seenGreen.opacity(0.15))
                    .blur(radius: 60)
                    .frame(width: 300, height: 300)
                    .offset(x: -50, y: animateGradient ? 100 : 200)
                
                Circle()
                    .fill(Color.seenPurple.opacity(0.1))
                    .blur(radius: 80)
                    .frame(width: 400, height: 400)
                    .offset(x: geo.size.width - 150, y: animateGradient ? 400 : 300)
                
                Circle()
                    .fill(Color.seenBlue.opacity(0.1))
                    .blur(radius: 70)
                    .frame(width: 250, height: 250)
                    .offset(x: geo.size.width / 2, y: animateGradient ? 600 : 700)
            }
        }
    }
}

// MARK: - Typography

extension Font {
    static let seenLargeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let seenTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let seenHeadline = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let seenSubheadline = Font.system(size: 16, weight: .medium, design: .rounded)
    static let seenBody = Font.system(size: 16, weight: .regular, design: .default)
    static let seenCaption = Font.system(size: 13, weight: .regular, design: .default)
}

// MARK: - Glass Button Styles

struct GlassPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.seenHeadline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: isEnabled ? [.seenGreen, .seenGreenLight] : [.gray, .gray.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Glass shine
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .shadow(color: .seenGreen.opacity(0.4), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.seenSubheadline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
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
                .foregroundStyle(.white)
        }
        .font(.system(size: size * 0.6))
        .padding(.horizontal, size * 0.5)
        .padding(.vertical, size * 0.25)
        .glassBackground(cornerRadius: size)
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
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            TextField(placeholder, text: $text)
                .foregroundStyle(.white)
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
            // Glowing icon
            ZStack {
                Circle()
                    .fill(Color.seenGreen.opacity(0.2))
                    .blur(radius: 30)
                    .frame(width: 120, height: 120)
                
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.seenHeadline)
                    .foregroundStyle(.white)
                
                Text(message)
                    .font(.seenBody)
                    .foregroundStyle(.white.opacity(0.6))
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
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var message: String = "Loading..."
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.seenGreen, .seenMint],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }
            
            Text(message)
                .font(.seenCaption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - Glass Navigation Title

struct GlassNavigationTitle: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.seenLargeTitle)
            .foregroundStyle(.white)
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
                            .font(.seenHeadline)
                            .foregroundStyle(.white)
                        Text("This is a liquid glass card with frosted effect")
                            .font(.seenBody)
                            .foregroundStyle(.white.opacity(0.7))
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
