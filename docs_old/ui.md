# SEEN UI/UX Guidelines & Implementation Checklist

This document consolidates all UI changes needed for Apple Human Interface Guidelines (HIG) compliance and adoption of Apple's Liquid Glass design system (iOS 26+).

**Last Updated:** January 2026  
**Target Platform:** iOS 26+  
**Design System:** Liquid Glass

---

## Table of Contents

1. [Current State](#current-state)
2. [HIG Compliance (Must-Fix)](#hig-compliance-must-fix)
3. [Liquid Glass Adoption](#liquid-glass-adoption)
4. [Assets & Resources](#assets--resources)
5. [File-by-File Implementation](#file-by-file-implementation)
6. [References](#references)

---

## Current State

### Views Requiring Updates

| View | Priority | Issues |
|------|----------|--------|
| `MainTabView.swift` | Critical | Custom tab bar breaks accessibility |
| `Theme.swift` | Critical | Custom glass implementation, should use native |
| `AuthView.swift` | High | Hardcoded colors, no Dynamic Type |
| `HomeView.swift` | High | Hidden nav bar, custom materials |
| `FeedView.swift` | High | Glass on every row (too many layers) |
| `ProfileView.swift` | Medium | Accessibility labels missing |
| `GoalDetailView.swift` | Medium | Button tap targets may be too small |
| `CreateGoalView.swift` | Medium | Form accessibility |
| `PodDetailView.swift` | Medium | Navigation patterns |

---

## HIG Compliance (Must-Fix)

These issues must be resolved regardless of Liquid Glass adoption. They affect accessibility, usability, and App Store approval.

### 1. Custom Tab Bar Breaks Accessibility

**Problem:** We replaced the native `TabView` with a custom `CustomTabBar` that doesn't support VoiceOver, Dynamic Type, or standard accessibility features.

**Current Code (Wrong):**
```swift
// MainTabView.swift
struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    // ... custom implementation
}
```

**Fix:** Use native `TabView` with `.tabItem`. iOS 26 automatically applies Liquid Glass styling.

```swift
TabView(selection: $selectedTab) {
    HomeView()
        .tabItem {
            Label("Pods", systemImage: "person.3.fill")
        }
        .tag(Tab.pods)
    // ... other tabs
}
```

**Files to Change:** `MainTabView.swift`

---

### 2. No Dynamic Type Support

**Problem:** Fixed font sizes don't scale with user's accessibility settings.

**Current Code (Wrong):**
```swift
// Theme.swift
static let seenTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
```

**Fix:** Use semantic text styles that respect Dynamic Type:

```swift
Text("Title")
    .font(.largeTitle)  // Scales automatically
    
Text("Body text")
    .font(.body)        // Scales automatically
```

**Files to Change:** `Theme.swift`, all Views using custom fonts

---

### 3. Hardcoded Colors (Light/Dark Mode)

**Problem:** We use `.white` and `.white.opacity(0.7)` which only works on dark backgrounds.

**Current Code (Wrong):**
```swift
Text(item.user.name)
    .foregroundStyle(.white)
```

**Fix:** Use semantic colors:

```swift
Text(item.user.name)
    .foregroundStyle(.primary)      // Adapts to light/dark

Text(item.checkIn.comment)
    .foregroundStyle(.secondary)    // Adapts to light/dark
```

**Files to Change:** `AuthView.swift`, `HomeView.swift`, `FeedView.swift`, `MainTabView.swift`

---

### 4. Missing Accessibility Labels

**Problem:** Interactive elements lack VoiceOver descriptions.

**Current Code (Wrong):**
```swift
Button {
    showingReactions = true
} label: {
    Image(systemName: "hand.thumbsup")
}
```

**Fix:** Add accessibility labels and hints:

```swift
Button {
    showingReactions = true
} label: {
    Image(systemName: "hand.thumbsup")
}
.accessibilityLabel("React to check-in")
.accessibilityHint("Double tap to show reaction options")
```

**Files to Change:** All Views with interactive elements

---

### 5. Minimum Tap Targets (44x44pt)

**Problem:** Some buttons may not meet the 44x44 point minimum for accessibility.

**Fix:** Ensure all interactive elements have adequate size:

```swift
Button(action: { }) {
    Image(systemName: "plus")
}
.frame(minWidth: 44, minHeight: 44)
```

**Files to Change:** `GoalDetailView.swift`, `FeedView.swift` (reaction buttons)

---

### 6. Hidden Navigation Bar

**Problem:** We hide the navigation bar, removing standard navigation affordances.

**Current Code (Wrong):**
```swift
.navigationBarHidden(true)
.toolbarBackground(.hidden, for: .navigationBar)
```

**Fix:** Let iOS 26 apply Liquid Glass to the navigation bar automatically. Remove these modifiers.

**Files to Change:** `HomeView.swift`, `FeedView.swift`, `MainTabView.swift`

---

## Liquid Glass Adoption

Apple introduced Liquid Glass in iOS 26. Our custom implementation should be replaced with native APIs.

### Key Principle: Do Less, Not More

> When you build with the iOS 26 SDK, many system components automatically adopt Liquid Glass styling. Don't fight the system.

### 1. Remove Custom Glass Materials

**Current Code (Wrong):**
```swift
// Theme.swift
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(strokeColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 10)
            )
    }
}
```

**Fix:** Use the native `.glassEffect()` modifier:

```swift
content
    .glassEffect()
```

Or for more control, use `GlassEffectContainer`:

```swift
GlassEffectContainer {
    VStack {
        // Content
    }
}
.glassEffect()
```

**Files to Change:** `Theme.swift` (remove `GlassCard`), all views using `.glassCard()`

---

### 2. Simplify Background

**Current Code:** `FloatingOrbBackground` with animated gradients.

**Guidance:** Apple recommends colorful backgrounds behind glass, so animated gradients are acceptable. However:
- Simplify the animation (less CPU usage)
- Ensure it works in both light and dark modes
- Consider using system-provided dynamic backgrounds

**Keep but optimize:** `Theme.swift` - `FloatingOrbBackground`

---

### 3. Reduce Glass Layering

**Problem:** We apply `.glassCard()` to every list row, creating too many glass layers.

**Current Code (Wrong):**
```swift
List {
    ForEach(pods) { pod in
        PodRow(pod: pod)
            .glassCard()  // Glass on EVERY row
    }
}
```

**Fix:** Apply glass once at the container level, not per-item:

```swift
List {
    ForEach(pods) { pod in
        PodRow(pod: pod)
            // No individual glass effect
    }
}
.glassEffect()  // One glass effect for the list
```

Or use grouped sections:

```swift
Section {
    ForEach(pods) { pod in
        PodRow(pod: pod)
    }
}
.glassEffect()
```

**Files to Change:** `HomeView.swift`, `FeedView.swift`

---

### 4. Use SF Symbols 7

**Current:** Basic SF Symbols usage.

**Upgrade:** SF Symbols 7 includes:
- Draw animations (great for check-in confirmation)
- Gradient rendering
- Variable color improvements

```swift
Image(systemName: "checkmark.circle.fill")
    .symbolEffect(.bounce, value: isCheckedIn)
    .symbolRenderingMode(.hierarchical)
```

**Files to Change:** `GoalDetailView.swift` (check-in button), `FeedView.swift` (reactions)

---

### 5. Tab Bar (Native Liquid Glass)

**Fix:** Simply use native `TabView`. iOS 26 handles the rest.

```swift
TabView(selection: $selectedTab) {
    // Views
}
.tint(.seenGreen)  // Optional: custom accent color
```

Remove entirely:
- `CustomTabBar` struct
- Manual glass effect on tab bar
- Custom tab bar overlay

**Files to Change:** `MainTabView.swift`

---

## Assets & Resources

### App Icon (Icon Composer)

Use Apple's [Icon Composer](https://developer.apple.com/icon-composer/) to create a proper Liquid Glass app icon with depth layers.

**Required:**
1. Download Icon Composer from Apple Developer
2. Create layered icon with background, midground, foreground
3. Export and replace current placeholder icon

**Files to Change:** `Assets.xcassets/AppIcon.appiconset/`

---

### Color Assets

Update color assets to support both light and dark modes:

| Color | Light Mode | Dark Mode |
|-------|------------|-----------|
| SeenGreen | #34C759 (vibrant) | #30D158 (same or brighter) |
| SeenMint | #00C7BE | #66D4CF |
| SeenBlue | #007AFF | #0A84FF |
| SeenPurple | #AF52DE | #BF5AF2 |
| SeenBackground | System Background | System Background |

**Files to Change:** `Assets.xcassets/` - Add color set variants

---

### Launch Screen

Create a launch screen that:
- Uses the animated gradient background
- Shows the app icon/logo
- Matches the Liquid Glass aesthetic

**Files to Change:** Create `LaunchScreen.storyboard` or SwiftUI launch screen

---

## File-by-File Implementation

### Priority 1: Critical (Blocks App Store)

| File | Changes | Effort |
|------|---------|--------|
| `MainTabView.swift` | Remove CustomTabBar, use native TabView | 30 min |
| `Theme.swift` | Remove GlassCard, add glassEffect helper, fix Dynamic Type | 1 hr |

### Priority 2: High (Accessibility)

| File | Changes | Effort |
|------|---------|--------|
| `AuthView.swift` | Replace `.white` with `.primary`, add accessibility labels | 30 min |
| `HomeView.swift` | Remove hidden nav bar, fix colors, reduce glass layers | 45 min |
| `FeedView.swift` | Fix colors, add accessibility, reduce glass layers | 45 min |

### Priority 3: Medium (Polish)

| File | Changes | Effort |
|------|---------|--------|
| `ProfileView.swift` | Add accessibility labels | 20 min |
| `GoalDetailView.swift` | SF Symbols 7, tap targets, accessibility | 30 min |
| `CreateGoalView.swift` | Form accessibility | 20 min |
| `PodDetailView.swift` | Navigation patterns | 20 min |
| `CreatePodView.swift` | Form accessibility | 15 min |
| `JoinPodView.swift` | Form accessibility | 15 min |

### Priority 4: Assets

| Asset | Changes | Effort |
|-------|---------|--------|
| App Icon | Create with Icon Composer | 1 hr |
| Color Assets | Add light/dark variants | 30 min |
| Launch Screen | Design and implement | 30 min |

**Total Estimated Effort:** ~7 hours

---

## References

### Apple Documentation
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [What's New in Design](https://developer.apple.com/design/whats-new/)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Tab Bars - Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Buttons - Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [Materials - Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Motion - Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Color - Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/color)

### Tools
- [Icon Composer](https://developer.apple.com/icon-composer/) - Create Liquid Glass app icons
- [SF Symbols 7](https://developer.apple.com/sf-symbols/) - Updated symbol library

### WWDC 2025 Videos
- [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)

---

## Checklist

- [ ] Update Xcode to support iOS 26 SDK
- [x] Remove `CustomTabBar`, use native TabView
- [x] Simplify `GlassCard` modifier to use `.regularMaterial`
- [x] Replace `.white` with `.primary` / `.secondary`
- [x] Add accessibility labels to all interactive elements
- [x] Ensure 44x44pt minimum tap targets
- [x] Remove `.navigationBarHidden(true)` modifiers
- [x] Update color assets with light/dark variants
- [ ] Create Liquid Glass app icon with Icon Composer
- [ ] Update SF Symbols usage to version 7
- [x] Reduce glass layering (one per section, not per row)
- [ ] Test with VoiceOver
- [ ] Test with Dynamic Type (all sizes)
- [ ] Test in Light Mode and Dark Mode
