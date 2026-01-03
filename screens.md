# SEEN — Screens & UI Specification

**Version:** 1.0  
**Target Platform:** iOS 26+  
**Design System:** iOS Liquid Glass + Custom Brand Elements  
**Last Updated:** January 2026

---

## Table of Contents

1. [User Flows](#1-user-flows)
2. [Design System](#2-design-system)
3. [App Structure](#3-app-structure)
4. [Screen Inventory](#4-screen-inventory)
5. [Component Library](#5-component-library)
6. [Navigation Patterns](#6-navigation-patterns)
7. [Accessibility](#7-accessibility)
8. [Animation & Motion](#8-animation--motion)
9. [Assets](#9-assets)

---

## 1. User Flows

### 1.1 First-Time User (Onboarding)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  App Launch  ──►  LaunchScreen  ──►  AuthView  ──►  Sign in with Apple     │
│                   (splash, 2s)       (features)      (tap button)           │
│                                                                             │
│                                           │                                 │
│                                           ▼                                 │
│                                                                             │
│                   ┌─────────────────────────────────────────────────────┐   │
│                   │  MainTabView (Pods tab selected)                    │   │
│                   │                                                     │   │
│                   │  HomeView shows "No Pods Yet"                       │   │
│                   │         │                                           │   │
│                   │         ├──► "Create Pod" ──► CreatePodView         │   │
│                   │         │                           │               │   │
│                   │         │                           ▼               │   │
│                   │         │                    Pod created!           │   │
│                   │         │                    Share invite code      │   │
│                   │         │                                           │   │
│                   │         └──► "Join Pod" ──► JoinPodView             │   │
│                   │                                   │                 │   │
│                   │                                   ▼                 │   │
│                   │                            Enter code, joined!      │   │
│                   └─────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Steps:**
1. User opens app → sees **LaunchScreen** (2 seconds)
2. Not authenticated → sees **AuthView** with feature highlights
3. Taps "Sign in with Apple" → iOS auth sheet appears
4. Authentication succeeds → transitions to **MainTabView**
5. First time = no pods → sees empty state with CTAs
6. User either:
   - **Creates a pod** → fills form → gets invite code to share
   - **Joins a pod** → enters 6-character code → welcomed to pod

---

### 1.2 Creating a Goal

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  HomeView  ──►  Tap Pod  ──►  PodDetailView  ──►  Tap [+]  ──►  CreateGoalView
│  (pods list)                  (shows members)     (toolbar)     (form)      │
│                                                                             │
│                                                                     │       │
│                                                                     ▼       │
│                                                                             │
│                            Configure goal:                                  │
│                            • Title: "Run 5k"                                │
│                            • Frequency: Daily                               │
│                            • Deadline: 11:59 PM                             │
│                            • Reminder: 6:00 PM (optional)                   │
│                            • Photo proof: ON/OFF                            │
│                                                                             │
│                                     │                                       │
│                                     ▼                                       │
│                                                                             │
│                            Tap "Create"  ──►  Goal appears in pod           │
│                                               Ready for check-ins!          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Steps:**
1. From **HomeView**, tap a pod to open **PodDetailView**
2. Tap [+] in toolbar to open **CreateGoalView** sheet
3. Enter goal title (required)
4. Choose frequency: Daily, Weekly, or Specific Days
5. Set deadline time (when MISSED triggers)
6. Optionally enable reminder notifications
7. Toggle photo proof requirement
8. Tap "Create" → goal appears in pod's goal list

---

### 1.3 Daily Check-in (Without Photo)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Push Notification  ──►  Open App  ──►  HomeView  ──►  Tap Pod              │
│  "Time to check in!"                    (or via notif)                      │
│                                                                             │
│                                                   │                         │
│                                                   ▼                         │
│                                                                             │
│  PodDetailView  ──►  Tap Goal  ──►  GoalDetailView  ──►  Tap "Check In"     │
│                                     (shows status)       (floating button)  │
│                                                                             │
│                                                               │             │
│                                                               ▼             │
│                                                                             │
│                                     ┌─────────────────────────────────────┐ │
│                                     │  ✅ Checked In!                     │ │
│                                     │                                     │ │
│                                     │  🔥 Streak: 8                       │ │
│                                     │                                     │ │
│                                     │  [OK]                               │ │
│                                     └─────────────────────────────────────┘ │
│                                                                             │
│                            Check-in appears in Activity feed                │
│                            Pod members can react 🔥 👏 💪                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Steps:**
1. User receives reminder notification (if enabled)
2. Opens app → navigates to goal
3. **GoalDetailView** shows "Not yet checked in" status
4. Taps floating "Check In" button
5. Success alert shows updated streak
6. Check-in posts to Activity feed for pod members to see

---

### 1.4 Daily Check-in (With Photo Proof)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  GoalDetailView  ──►  Tap "Check In"  ──►  CheckInWithProofView (sheet)     │
│  (requires photo)     (floating button)                                     │
│                                                                             │
│                                                   │                         │
│                                                   ▼                         │
│                                                                             │
│                            ┌──────────────────────────────────────────┐     │
│                            │  PHOTO PROOF                             │     │
│                            │  [📷 Add Photo Proof ────────────────►]  │     │
│                            │                                          │     │
│                            │        ┌────────────────────┐            │     │
│                            │        │  Take Photo        │            │     │
│                            │        │  Choose from Lib   │            │     │
│                            │        │  Cancel            │            │     │
│                            │        └────────────────────┘            │     │
│                            └──────────────────────────────────────────┘     │
│                                                                             │
│                                           │                                 │
│                                           ▼                                 │
│                                                                             │
│  Camera opens  ──►  Take photo  ──►  Preview shown  ──►  Add comment (opt) │
│                                                                             │
│                                                               │             │
│                                                               ▼             │
│                                                                             │
│                       Tap "Submit"  ──►  Photo uploads to R2                │
│                                          Check-in recorded                  │
│                                          Success alert shown                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Steps:**
1. Goal has `requiresProof = true`
2. Tap "Check In" → opens **CheckInWithProofView** sheet
3. Tap "Add Photo Proof" → choose source (Camera or Library)
4. Capture/select photo → preview appears
5. Optionally add a comment/note
6. Tap "Submit" → photo uploads to Cloudflare R2
7. Check-in created with proof URL
8. Success alert, check-in visible in feed with photo

---

### 1.5 Viewing Activity & Reacting

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  MainTabView  ──►  Tap "Activity" tab  ──►  FeedView                        │
│                                             (chronological feed)            │
│                                                                             │
│                                                   │                         │
│                                                   ▼                         │
│                                                                             │
│                  ┌────────────────────────────────────────────────┐         │
│                  │  🔵 Joe Wilson                           2h   │         │
│                  │     completed Run 5k                          │         │
│                  │                                               │         │
│                  │     [Photo of Joe running]                    │         │
│                  │                                               │         │
│                  │     "Felt great today!"                       │         │
│                  │                                               │         │
│                  │  👥 Sunbathers                                │         │
│                  │                                               │         │
│                  │  🔥👏 2                            [👍]       │         │
│                  └────────────────────────────────────────────────┘         │
│                                                                             │
│                                           │                                 │
│                                           ▼                                 │
│                                                                             │
│                       Tap [👍]  ──►  Reaction dialog appears                │
│                                                                             │
│                            ┌────────────────────────────────┐               │
│                            │  🔥 Fire                       │               │
│                            │  👏 Clap                       │               │
│                            │  💪 Strong                     │               │
│                            │  Remove Reaction (if reacted)  │               │
│                            │  Cancel                        │               │
│                            └────────────────────────────────┘               │
│                                                                             │
│                       Select reaction  ──►  Reaction posted                 │
│                                             Push sent to user               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Steps:**
1. Tap "Activity" tab in **MainTabView**
2. **FeedView** shows chronological check-ins from all pods
3. Each card shows: user, goal, time, photo (if any), comment, pod name
4. Tap reaction button → confirmation dialog appears
5. Choose 🔥 Fire, 👏 Clap, or 💪 Strong
6. Reaction posts → user receives push notification

---

### 1.6 Inviting Friends to a Pod

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  PodDetailView  ──►  Scroll to "Invite Friends"  ──►  Tap "Invite Code"     │
│                                                                             │
│                                                               │             │
│                                                               ▼             │
│                                                                             │
│                  ┌────────────────────────────────────────────────┐         │
│                  │  INVITE FRIENDS                                │         │
│                  │  ┌──────────────────────────────────────────┐  │         │
│                  │  │ 🎟️ Invite Code         ABC123            │  │         │
│                  │  ├──────────────────────────────────────────┤  │         │
│                  │  │ 📋 Copy Code                   Copied! ✓ │  │         │
│                  │  └──────────────────────────────────────────┘  │         │
│                  └────────────────────────────────────────────────┘         │
│                                                                             │
│                       Tap "Invite Code"  ──►  Code revealed                 │
│                       Tap "Copy Code"    ──►  Copied to clipboard           │
│                                                                             │
│                                           │                                 │
│                                           ▼                                 │
│                                                                             │
│                       Share via iMessage, WhatsApp, etc.                    │
│                       Friend enters code in JoinPodView                     │
│                       Friend appears in member list                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Steps:**
1. Open **PodDetailView** for your pod
2. Scroll to "Invite Friends" section
3. Tap row to reveal 6-character invite code
4. Tap "Copy Code" → copied to clipboard
5. Share code externally (text, email, etc.)
6. Friend opens SEEN → JoinPodView → enters code
7. Friend joins pod, appears in member list

---

### 1.7 Missed Check-in (System Flow)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                        DEADLINE PASSES (e.g., 11:59 PM)                     │
│                                                                             │
│                                     │                                       │
│                                     ▼                                       │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  Backend: Deadline Worker (runs every 15 min)                       │    │
│  │                                                                     │    │
│  │  1. Query active goals where deadline passed in goal.timezone       │    │
│  │  2. Check if COMPLETED or SKIPPED check-in exists for today         │    │
│  │  3. If no check-in found:                                           │    │
│  │     • Create MISSED check-in record                                 │    │
│  │     • Reset currentStreak to 0                                      │    │
│  │     • Send push notification                                        │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│                                     │                                       │
│                                     ▼                                       │
│                                                                             │
│                  ┌────────────────────────────────────────┐                 │
│                  │  📱 Push Notification                  │                 │
│                  │                                        │                 │
│                  │  "Missed check-in 😢"                  │                 │
│                  │  "Run 5k"                              │                 │
│                  └────────────────────────────────────────┘                 │
│                                                                             │
│                                     │                                       │
│                                     ▼                                       │
│                                                                             │
│  User opens app  ──►  GoalDetailView shows:                                 │
│                       • Current Streak: 0 (reset)                           │
│                       • History: ❌ [Date] MISSED                           │
│                       • MISSED record is permanent (no hiding)              │
│                                                                             │
│  Feed shows:  "[User] missed [Goal]" (visible to pod)                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**System Invariant:** Users cannot mark themselves as missed. Only the system can create MISSED records. This is the core accountability mechanism.

---

### 1.8 Enabling Notifications

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  MainTabView  ──►  Tap "Profile" tab  ──►  ProfileView                      │
│                                                                             │
│                                                   │                         │
│                                                   ▼                         │
│                                                                             │
│                  ┌────────────────────────────────────────────────┐         │
│                  │  SETTINGS                                      │         │
│                  │  ┌──────────────────────────────────────────┐  │         │
│                  │  │ 🌐 Timezone          America/Chicago     │  │         │
│                  │  ├──────────────────────────────────────────┤  │         │
│                  │  │ 🔔 Enable Notifications              ►   │  │         │
│                  │  └──────────────────────────────────────────┘  │         │
│                  └────────────────────────────────────────────────┘         │
│                                                                             │
│                       Tap "Enable Notifications"                            │
│                                                                             │
│                                     │                                       │
│                                     ▼                                       │
│                                                                             │
│                  ┌────────────────────────────────────────┐                 │
│                  │  "SEEN" Would Like to Send You         │                 │
│                  │  Notifications                         │                 │
│                  │                                        │                 │
│                  │  [Don't Allow]        [Allow]          │                 │
│                  └────────────────────────────────────────┘                 │
│                                                                             │
│                       Tap "Allow"  ──►  Device token registered             │
│                                         Backend can now send pushes         │
│                                         UI updates to "Enabled ✓"           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Steps:**
1. Navigate to **ProfileView** via Profile tab
2. See "Enable Notifications" row (if not yet enabled)
3. Tap row → iOS permission dialog appears
4. User taps "Allow"
5. App receives device token → sends to backend
6. Backend stores token for push delivery
7. UI updates to show "Notifications: Enabled"

---

### 1.9 Complete User Journey (Day in the Life)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  MORNING (6:00 AM)                                                          │
│  ├── 📱 Wake up, open SEEN                                                  │
│  ├── See Activity tab: Sarah checked in "Morning Meditation" at 5:45 AM    │
│  └── React with 💪 to encourage her                                        │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  AFTERNOON (6:00 PM)                                                        │
│  ├── 🔔 Reminder notification: "Time to check in! Run 5k"                   │
│  ├── Go for run                                                             │
│  ├── Open SEEN → Pods → Sunbathers → Run 5k                                 │
│  ├── Tap "Check In" → Camera opens (requires proof)                         │
│  ├── Take selfie post-run → Add comment "Personal best today!"              │
│  └── Submit → 🔥 Streak: 15 → Confetti!                                     │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  EVENING (9:00 PM)                                                          │
│  ├── 📱 Push notification: "Mike reacted 🔥 to your check-in"               │
│  ├── Open SEEN → Activity tab                                               │
│  ├── See Mike and Joe both reacted to your run                              │
│  ├── Joe also checked in "Read 30 mins" → React with 👏                     │
│  └── Notice Sarah hasn't checked in yet for her evening goal...             │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  NEXT MORNING                                                               │
│  ├── 📱 Open Activity feed                                                  │
│  ├── See: "Sarah missed Evening Yoga" (system-generated)                    │
│  ├── Sarah's streak reset to 0                                              │
│  └── Social pressure motivates everyone to not miss tomorrow                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 1.10 Flow Summary Table

| Flow | Entry Point | Key Screens | End State |
|------|-------------|-------------|-----------|
| **Onboarding** | App launch | LaunchScreen → AuthView | Authenticated, at HomeView |
| **Create Pod** | HomeView [+] menu | CreatePodView | Pod created, invite code ready |
| **Join Pod** | HomeView [+] menu | JoinPodView | Joined pod, see members |
| **Create Goal** | PodDetailView [+] | CreateGoalView | Goal active, ready for check-ins |
| **Quick Check-in** | GoalDetailView | (same screen) | Streak incremented, feed updated |
| **Photo Check-in** | GoalDetailView | CheckInWithProofView | Photo uploaded, check-in posted |
| **Browse Feed** | Activity tab | FeedView | View/react to check-ins |
| **React to Check-in** | FeedView | (confirmation dialog) | Reaction sent, push delivered |
| **Invite Friend** | PodDetailView | (reveal/copy code) | Code shared externally |
| **Enable Notifications** | ProfileView | (iOS permission) | Device token registered |
| **Sign Out** | ProfileView | (alert) | Return to AuthView |

---

## 2. Design System

### 2.1 Color Palette

| Color Name | Light Mode | Dark Mode | Usage |
|------------|------------|-----------|-------|
| **SeenGreen** | `#34C759` | `#30D158` | Primary brand, CTAs, success states, streaks |
| **SeenMint** | `#00C7BE` | `#66D4CF` | Accent, secondary highlights |
| **SeenBlue** | `#007AFF` | `#0A84FF` | Links, info states, Activity tab |
| **SeenPurple** | `#AF52DE` | `#BF5AF2` | Notifications, special features |
| **Orange** | System | System | Stakes, warnings, flame icons |
| **Primary** | Black | White | Main text |
| **Secondary** | Gray | Gray | Subtext, captions |
| **Tertiary** | Light Gray | Dark Gray | Timestamps, hints |

### 2.2 Typography

Uses iOS semantic text styles for Dynamic Type support:

| Style | Usage | SwiftUI |
|-------|-------|---------|
| **Large Title** | Screen titles, Logo text | `.font(.largeTitle)` |
| **Title** | Section headers | `.font(.title)` |
| **Title 2** | Card titles | `.font(.title2)` |
| **Headline** | Row titles, user names | `.font(.headline)` |
| **Subheadline** | Subtitles, metadata | `.font(.subheadline)` |
| **Body** | Main content, descriptions | `.font(.body)` |
| **Caption** | Timestamps, badges, counts | `.font(.caption)` |
| **Monospaced** | Invite codes | `.font(.system(.body, design: .monospaced))` |

### 2.3 Glass Effects

iOS 26 Liquid Glass is used throughout:

| Effect | Implementation | Usage |
|--------|----------------|-------|
| **Glass Background** | `.regularMaterial` | Cards, text field backgrounds |
| **Tab Bar** | Native `TabView` | Auto-applies Liquid Glass |
| **Navigation Bar** | Native | Auto-applies Liquid Glass |
| **Feature Cards** | `.glassBackground()` | Auth screen feature rows |

### 2.4 Spacing & Layout

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4pt | Icon-text spacing |
| `sm` | 8pt | Tight content grouping |
| `md` | 12pt | Standard content spacing |
| `lg` | 16pt | Section spacing |
| `xl` | 20pt | Card padding |
| `xxl` | 24-32pt | Screen margins |

### 2.5 Corner Radii

| Size | Value | Usage |
|------|-------|-------|
| `small` | 8pt | Badges, small chips |
| `medium` | 12pt | Buttons, input fields |
| `large` | 16pt | Cards, list rows |
| `xlarge` | 20pt | Glass cards |

### 2.6 Shadows

| Type | Specification | Usage |
|------|--------------|-------|
| **Glow** | Color blur at 0.2 opacity | Logo icon |
| **Orb** | 60-80px blur | Background depth |

---

## 3. App Structure

### 3.1 Navigation Hierarchy

```
App Launch
├── LaunchScreen (splash)
└── ContentView
    ├── AuthView (if not authenticated)
    └── MainTabView (if authenticated)
        ├── Tab 1: Pods (HomeView)
        │   ├── CreatePodView (sheet)
        │   ├── JoinPodView (sheet)
        │   └── PodDetailView (push)
        │       ├── CreateGoalView (sheet)
        │       └── GoalDetailView (push)
        │           └── CheckInWithProofView (sheet)
        ├── Tab 2: Activity (FeedView)
        └── Tab 3: Profile (ProfileView)
```

### 3.2 Tab Bar

| Tab | Icon | Label | Destination |
|-----|------|-------|-------------|
| 1 | `person.3.fill` | Pods | `HomeView` |
| 2 | `bubble.left.and.bubble.right.fill` | Activity | `FeedView` |
| 3 | `person.circle.fill` | Profile | `ProfileView` |

**Styling:** Native iOS 26 TabView with `.tint(.seenGreen)` accent.

---

## 4. Screen Inventory

### 4.1 LaunchScreen

**Purpose:** Splash screen shown during app initialization.

**Visual Design:**
- Full-screen gradient background (SeenGreen)
- Centered logo with pulsing animation
- "SEEN" text with wide letter-spacing
- "Accountability that works" tagline (fade in)

**Elements:**
| Element | Type | Details |
|---------|------|---------|
| Background | LinearGradient | SeenGreen gradient |
| Logo Container | Circle | White @ 20% opacity, 120pt |
| Logo Icon | SF Symbol | `eye.fill`, 50pt, white |
| App Name | Text | "SEEN", 48pt, bold, tracking: 8 |
| Tagline | Text | 18pt, white @ 90%, animated entrance |

**Animations:**
- Logo circle: Scale 1.0 ↔ 1.1, 1s ease-in-out, repeating
- Tagline: Fade + slide up, 0.5s delay

---

### 4.2 AuthView

**Purpose:** Sign in with Apple authentication.

**Layout:**
```
┌──────────────────────────────────┐
│       AnimatedGradientBackground │
│                                  │
│           [Logo + Glow]          │
│              SEEN                │
│    "Accountability that works"   │
│                                  │
│     ┌─────────────────────┐      │
│     │ 👥 Create pods...   │      │
│     └─────────────────────┘      │
│     ┌─────────────────────┐      │
│     │ 🎯 Set goals...     │      │
│     └─────────────────────┘      │
│     ┌─────────────────────┐      │
│     │ 🔔 Get reminded...  │      │
│     └─────────────────────┘      │
│     ┌─────────────────────┐      │
│     │ 🔥 Build streaks... │      │
│     └─────────────────────┘      │
│                                  │
│   ┌───────────────────────────┐  │
│   │  ⬛ Sign in with Apple    │  │
│   └───────────────────────────┘  │
│                                  │
│         [Loading/Error]          │
└──────────────────────────────────┘
```

**Elements:**

| Element | Component | Details |
|---------|-----------|---------|
| Background | `AnimatedGradientBackground` | Subtle animated gradient with floating orbs |
| Logo | Circle + SF Symbol | `eye.fill` with gradient, green glow behind |
| Title | Text | "SEEN", largeTitle, bold, tracking: 6 |
| Subtitle | Text | headline, secondary color |
| Feature Rows | `FeatureRow` (×4) | Icon + text in glass card |
| Sign In Button | `SignInWithAppleButton` | Native Apple button, 56pt height |
| Loading | `LoadingView` | Shows during auth |
| Error | Text | Red, glass background |

**Feature Rows:**
1. 👥 "Create pods with friends" — SeenGreen
2. 🎯 "Set goals and track progress" — SeenBlue
3. 🔔 "Get reminded and stay on track" — SeenPurple
4. 🔥 "Build streaks together" — Orange

**Animations:**
- Features: Fade + slide up on appear (0.3s delay)
- Background orbs: 8s ease-in-out loop

---

### 4.3 HomeView (Pods Tab)

**Purpose:** List of user's pods with actions to create or join.

**Layout:**
```
┌──────────────────────────────────┐
│ My Pods                    [+]   │ ← Navigation bar + menu
├──────────────────────────────────┤
│  ┌────────────────────────────┐  │
│  │ Sunbathers            1/8 👥│  │
│  │ 🚩 $10                OWNER │  │
│  │                           > │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │ Morning Crew          3/5 👥│  │
│  │ Loser buys lunch     MEMBER │  │
│  │                           > │  │
│  └────────────────────────────┘  │
│                                  │
│         [Pull to refresh]        │
└──────────────────────────────────┘
```

**States:**
| State | Display |
|-------|---------|
| Loading | `LoadingView` centered |
| Empty | `EmptyStateView` with create CTA |
| Populated | `List` with `PodRow` items |

**Navigation Bar:**
- Title: "My Pods"
- Trailing: Menu button (`plus.circle.fill`)
  - "Create Pod" → `CreatePodView` sheet
  - "Join Pod" → `JoinPodView` sheet

**PodRow Elements:**
| Element | Details |
|---------|---------|
| Name | Headline, leading |
| Member Count | Caption + `person.2.fill` icon |
| Description | Subheadline, secondary, 2-line limit |
| Stakes | Caption with 🚩 icon, orange |
| Role Badge | Capsule, green for OWNER, gray for MEMBER |
| Chevron | System disclosure indicator |

---

### 4.4 CreatePodView

**Purpose:** Form to create a new accountability pod.

**Type:** Sheet (modal)

**Layout:**
```
┌──────────────────────────────────┐
│ Cancel      Create Pod    Create │ ← Navigation bar
├──────────────────────────────────┤
│ POD INFO                         │
│ ┌────────────────────────────┐   │
│ │ Pod Name                   │   │
│ ├────────────────────────────┤   │
│ │ Description (optional)     │   │
│ │                            │   │
│ └────────────────────────────┘   │
│ Give your pod a memorable name   │
│                                  │
│ STAKES (OPTIONAL)                │
│ ┌────────────────────────────┐   │
│ │ What's at stake?           │   │
│ └────────────────────────────┘   │
│ e.g., "$10 to group pot..."      │
└──────────────────────────────────┘
```

**Form Fields:**
| Field | Type | Validation |
|-------|------|------------|
| Pod Name | TextField | Required, trimmed |
| Description | TextField (multiline) | Optional, 3-5 lines |
| Stakes | TextField | Optional |

**Toolbar:**
- Cancel: Dismisses sheet
- Create: Submits form (disabled until valid)

---

### 4.5 JoinPodView

**Purpose:** Enter 6-character invite code to join a pod.

**Type:** Sheet (modal)

**Layout:**
```
┌──────────────────────────────────┐
│ Cancel                           │
├──────────────────────────────────┤
│                                  │
│           🎟️ (56pt)              │
│                                  │
│        Join a Pod                │
│  Enter the 6-character code      │
│                                  │
│      ┌──────────────┐            │
│      │   ABCDEF     │ ← Monospace│
│      └──────────────┘            │
│                                  │
│   ┌────────────────────────┐     │
│   │      Join Pod          │     │
│   └────────────────────────┘     │
│                                  │
└──────────────────────────────────┘
```

**Elements:**
| Element | Details |
|---------|---------|
| Icon | `ticket.fill`, 56pt, secondary |
| Title | "Join a Pod", title, bold |
| Subtitle | body, secondary |
| Code Input | Monospaced, 32pt, centered, auto-caps |
| Join Button | Full-width, accent/gray based on validity |

**Validation:** Code must be exactly 6 characters.

---

### 4.6 PodDetailView

**Purpose:** Pod details, members, goals, and invite sharing.

**Type:** Push navigation

**Layout:**
```
┌──────────────────────────────────┐
│ < Back    Pod Name          [+]  │ ← Nav bar + add goal
├──────────────────────────────────┤
│ [Description text if any]        │
│ 🔥 Stakes text if any            │
├──────────────────────────────────┤
│ GOALS (2)                        │
│ ┌────────────────────────────┐   │
│ │ Run 5k             🔥 7    │   │
│ │ 👤 Joe   📅 Daily  📷      │   │
│ └────────────────────────────┘   │
│ ┌────────────────────────────┐   │
│ │ Read 30 mins               │   │
│ │ 👤 Sarah  📅 Weekdays      │   │
│ └────────────────────────────┘   │
├──────────────────────────────────┤
│ MEMBERS (3/5)                    │
│ ┌────────────────────────────┐   │
│ │ 🔵 J  Joe Wilson   Owner   │   │
│ │ 🔵 S  Sarah Smith  Member  │   │
│ │ 🔵 M  Mike Jones   Member  │   │
│ └────────────────────────────┘   │
├──────────────────────────────────┤
│ INVITE FRIENDS                   │
│ ┌────────────────────────────┐   │
│ │ 🎟️ Invite Code  [Tap...] > │   │
│ ├────────────────────────────┤   │
│ │ 📋 Copy Code               │   │ ← Shown after reveal
│ └────────────────────────────┘   │
└──────────────────────────────────┘
```

**Sections:**
1. **Description/Stakes** (if present)
2. **Goals** — List of `GoalRow`, tap to navigate
3. **Members** — Avatar + name + role
4. **Invite Friends** — Reveal/copy invite code

**GoalRow Elements:**
| Element | Details |
|---------|---------|
| Title | Headline |
| Streak | 🔥 + count (if > 0) |
| User Name | Caption with person icon |
| Frequency | Caption with calendar icon |
| Photo Badge | Camera icon if requires proof |

---

### 4.7 CreateGoalView

**Purpose:** Form to create a new goal within a pod.

**Type:** Sheet (modal)

**Layout:**
```
┌──────────────────────────────────┐
│ Cancel       New Goal     Create │
├──────────────────────────────────┤
│ GOAL                             │
│ ┌────────────────────────────┐   │
│ │ What's your goal?          │   │
│ ├────────────────────────────┤   │
│ │ Description (optional)     │   │
│ └────────────────────────────┘   │
│ Creating goal in [Pod Name]      │
├──────────────────────────────────┤
│ SCHEDULE                         │
│ ┌────────────────────────────┐   │
│ │ Frequency     [Daily ▼]    │   │
│ ├────────────────────────────┤   │
│ │ (M)(T)(W)(T)(F)(S)(S)      │   │ ← Day picker (conditional)
│ └────────────────────────────┘   │
│ Goal repeats every day           │
├──────────────────────────────────┤
│ DEADLINE                         │
│ ┌────────────────────────────┐   │
│ │ Daily Deadline  [11:59 PM] │   │
│ └────────────────────────────┘   │
├──────────────────────────────────┤
│ REMINDER                         │
│ ┌────────────────────────────┐   │
│ │ Enable Reminder    [OFF]   │   │
│ ├────────────────────────────┤   │
│ │ Reminder Time  [8:00 PM]   │   │ ← Shown if enabled
│ └────────────────────────────┘   │
├──────────────────────────────────┤
│ ┌────────────────────────────┐   │
│ │ Require Photo Proof [OFF]  │   │
│ └────────────────────────────┘   │
│ When enabled, check-ins require  │
│ a photo                          │
└──────────────────────────────────┘
```

**Form Fields:**
| Field | Type | Details |
|-------|------|---------|
| Title | TextField | Required |
| Description | TextField (multiline) | Optional |
| Frequency | Picker | Daily / Weekly / Specific Days |
| Day Picker | Button group | 7 circle buttons, 44pt each |
| Deadline | DatePicker | Time only, default 11:59 PM |
| Reminder Toggle | Toggle | Off by default |
| Reminder Time | DatePicker | Time only (if enabled) |
| Requires Proof | Toggle | Off by default |

**Day Picker:**
- Circular buttons, 44pt diameter
- Selected: Accent color fill, white text
- Unselected: Gray fill, primary text

---

### 4.8 GoalDetailView

**Purpose:** View goal details, history, and check in.

**Type:** Push navigation

**Layout:**
```
┌──────────────────────────────────┐
│ < Back         Run 5k            │
├──────────────────────────────────┤
│  ┌─────────┐   ┌─────────┐       │
│  │  🔥 7   │   │  🏆 21  │       │
│  │ Current │   │  Best   │       │
│  │ Streak  │   │ Streak  │       │
│  └─────────┘   └─────────┘       │
├──────────────────────────────────┤
│  ✅ Completed today!             │
│  ─ OR ─                          │
│  ⭕ Not yet checked in           │
├──────────────────────────────────┤
│ DETAILS                          │
│  [Description if any]            │
│  📅 Daily                        │
│  📅 Mon, Wed, Fri (if specific)  │
│  🕐 Deadline: 11:59 PM           │
│  🔔 Reminder: 8:00 PM            │
│  📷 Photo proof required         │
├──────────────────────────────────┤
│ RECENT CHECK-INS                 │
│ ┌────────────────────────────┐   │
│ │ ✅ Jan 2, 2026        📷  │   │
│ │ ✅ Jan 1, 2026             │   │
│ │ ❌ Dec 31, 2025            │   │
│ └────────────────────────────┘   │
├──────────────────────────────────┤
│ ┌────────────────────────────┐   │
│ │ 📦 Archive Goal            │   │
│ └────────────────────────────┘   │
│                                  │
│ ┌────────────────────────────┐   │ ← Floating button
│ │  ✅  Check In              │   │    (hidden if checked in)
│ └────────────────────────────┘   │
└──────────────────────────────────┘
```

**StatCard:**
| Element | Details |
|---------|---------|
| Icon | SF Symbol, title2 size |
| Value | Title, bold |
| Label | Caption, secondary |
| Background | Gray6, 12pt radius |

**CheckInRow Status Icons:**
| Status | Icon | Color |
|--------|------|-------|
| COMPLETED | `checkmark.circle.fill` | Green |
| MISSED | `xmark.circle.fill` | Red |
| SKIPPED | `forward.circle.fill` | Orange |

**Floating Check-in Button:**
- Full-width minus margins
- SeenGreen background
- White text
- 16pt corner radius
- Shows ProgressView when loading

---

### 4.9 CheckInWithProofView

**Purpose:** Submit check-in with required photo proof.

**Type:** Sheet (modal)

**Layout:**
```
┌──────────────────────────────────┐
│ Cancel      Check In      Submit │
├──────────────────────────────────┤
│ PHOTO PROOF                      │
│ ┌────────────────────────────┐   │
│ │ 📷 Add Photo Proof       > │   │
│ └────────────────────────────┘   │
│ This goal requires photo proof   │
├──────────────────────────────────┤
│ [Photo Preview - 200pt height]   │ ← Shown after capture
├──────────────────────────────────┤
│ COMMENT                          │
│ ┌────────────────────────────┐   │
│ │ Add a note (optional)      │   │
│ │                            │   │
│ └────────────────────────────┘   │
└──────────────────────────────────┘
```

**Photo Source Dialog:**
- "Take Photo" → Camera (fullScreenCover)
- "Choose from Library" → Photo picker (sheet)
- "Cancel"

---

### 4.10 FeedView (Activity Tab)

**Purpose:** Activity feed showing pod members' check-ins.

**Type:** Tab destination

**Layout:**
```
┌──────────────────────────────────┐
│ Activity                         │
├──────────────────────────────────┤
│ ┌────────────────────────────┐   │
│ │ 🔵 J  Joe Wilson           │   │
│ │     completed Run 5k    2h │   │
│ │                            │   │
│ │     [Photo if any]         │   │
│ │                            │   │
│ │     "Great run today!"     │   │
│ │                            │   │
│ │ 👥 Sunbathers              │   │
│ │                            │   │
│ │ 🔥👏 2          [👍]       │   │
│ └────────────────────────────┘   │
│                                  │
│ ┌────────────────────────────┐   │
│ │ 🔵 S  Sarah Smith          │   │
│ │     completed Read    45m  │   │
│ │                            │   │
│ │ 👥 Morning Crew            │   │
│ │                            │   │
│ │ 💪 1             [💪]      │   │
│ └────────────────────────────┘   │
└──────────────────────────────────┘
```

**FeedItemCard Elements:**
| Element | Details |
|---------|---------|
| Avatar | Circle with initial, SeenGreen background |
| Name | Headline |
| Action | "[completed] [Goal Title]" |
| Timestamp | Caption, tertiary, relative (now/2h/1d) |
| Photo | AsyncImage, 200pt max height, 12pt radius |
| Comment | Body, secondary |
| Pod Badge | Caption with person.3.fill icon |
| Reactions | Emoji summary + count |
| React Button | Thumbs up or current reaction emoji |

**Reaction Types:**
| Type | Emoji |
|------|-------|
| FIRE | 🔥 |
| CLAP | 👏 |
| STRONG | 💪 |

---

### 4.11 ProfileView

**Purpose:** User settings and account management.

**Type:** Tab destination

**Layout:**
```
┌──────────────────────────────────┐
│ Profile                          │
├──────────────────────────────────┤
│ ┌────────────────────────────┐   │
│ │ 🔵 J   Joe Wilson          │   │
│ │        joe@email.com       │   │
│ └────────────────────────────┘   │
├──────────────────────────────────┤
│ SETTINGS                         │
│ ┌────────────────────────────┐   │
│ │ 🌐 Timezone  America/Chi.. │   │
│ ├────────────────────────────┤   │
│ │ 🔔 Notifications   Enabled │   │
│ │  ─ OR ─                    │   │
│ │ 🔔 Enable Notifications  > │   │
│ └────────────────────────────┘   │
├──────────────────────────────────┤
│ ABOUT                            │
│ ┌────────────────────────────┐   │
│ │ ℹ️ Version          1.0.0  │   │
│ └────────────────────────────┘   │
├──────────────────────────────────┤
│ ┌────────────────────────────┐   │
│ │ 🚪 Sign Out                │   │ ← Destructive
│ └────────────────────────────┘   │
└──────────────────────────────────┘
```

---

## 5. Component Library

### 5.1 Reusable Components

| Component | File | Usage |
|-----------|------|-------|
| `AnimatedGradientBackground` | Theme.swift | Auth, backgrounds |
| `GlassCard` | Theme.swift | Wrapped content with glass |
| `GlassBackground` modifier | Theme.swift | Apply glass to any view |
| `GlassPrimaryButtonStyle` | Theme.swift | Primary CTAs |
| `GlassSecondaryButtonStyle` | Theme.swift | Secondary actions |
| `StreakBadge` | Theme.swift | Flame + count display |
| `GlassTextField` | Theme.swift | Styled text input |
| `EmptyStateView` | Theme.swift | No content states |
| `LoadingView` | Theme.swift | Loading indicators |
| `ImagePicker` | ImagePicker.swift | Camera/library picker |

### 5.2 Row Components

| Component | File | Usage |
|-----------|------|-------|
| `PodRow` | HomeView.swift | Pod list items |
| `GoalRow` | PodDetailView.swift | Goal list items |
| `CheckInRow` | GoalDetailView.swift | Check-in history |
| `FeedItemCard` | FeedView.swift | Activity feed items |
| `FeatureRow` | AuthView.swift | Auth feature bullets |
| `StatCard` | GoalDetailView.swift | Streak statistics |

---

## 6. Navigation Patterns

### 6.1 Navigation Types

| Pattern | Implementation | Usage |
|---------|----------------|-------|
| Tab Navigation | Native `TabView` | Main app structure |
| Push Navigation | `NavigationStack` + `NavigationLink` | Drill-down (Pod → Goal) |
| Modal Sheet | `.sheet()` | Create/Join/Edit forms |
| Full Screen Cover | `.fullScreenCover()` | Camera |
| Confirmation Dialog | `.confirmationDialog()` | Photo source, reactions |
| Alert | `.alert()` | Errors, confirmations |

### 6.2 Back Navigation

- Always use system back button
- Never hide navigation bar
- Large title display mode for top-level views

---

## 7. Accessibility

### 7.1 Requirements

| Feature | Implementation |
|---------|----------------|
| **VoiceOver** | All interactive elements have `.accessibilityLabel()` |
| **Dynamic Type** | All text uses semantic font styles |
| **Tap Targets** | Minimum 44×44pt for all buttons |
| **Color Contrast** | Primary/secondary semantic colors |
| **Reduce Motion** | Respect system preference |

### 7.2 Accessibility Labels by Screen

| Screen | Element | Label |
|--------|---------|-------|
| AuthView | Sign In Button | "Sign in with Apple" |
| HomeView | Add Menu | "Add pod" |
| HomeView | Pod Row | "[Name], [count] of [max] members" |
| FeedView | React Button | "Add reaction" / "Change reaction" |
| GoalDetailView | Check-in Button | "Check in" |
| ProfileView | Sign Out | "Sign out" |

---

## 8. Animation & Motion

### 8.1 Standard Animations

| Animation | Duration | Curve | Usage |
|-----------|----------|-------|-------|
| Background gradient | 8s | ease-in-out | Repeating loop |
| Feature reveal | 0.6s | ease-out | Auth screen entrance |
| Button press | 0.3s | spring | Scale 0.97 feedback |
| Logo pulse | 1s | ease-in-out | Launch screen |
| Tagline entrance | 0.5s | ease-out | Fade + slide |

### 8.2 SF Symbol Animations

```swift
.symbolEffect(.bounce, value: trigger)  // Check-in confirmation
.symbolRenderingMode(.hierarchical)     // Icon depth
```

---

## 9. Assets

### 9.1 Color Assets (Assets.xcassets)

| Name | Light | Dark |
|------|-------|------|
| SeenGreen | #34C759 | #30D158 |
| SeenMint | #00C7BE | #66D4CF |
| SeenBlue | #007AFF | #0A84FF |
| SeenPurple | #AF52DE | #BF5AF2 |
| AccentColor | SeenGreen | SeenGreen |

### 9.2 App Icon

- **Style:** Liquid Glass layers
- **Tool:** Apple Icon Composer
- **Layers:** Background gradient, midground glow, foreground eye symbol

### 9.3 SF Symbols Used

| Symbol | Usage |
|--------|-------|
| `eye.fill` | Logo, branding |
| `person.3.fill` | Pods tab, pod badge |
| `bubble.left.and.bubble.right.fill` | Activity tab |
| `person.circle.fill` | Profile tab |
| `plus.circle.fill` | Add actions |
| `ticket.fill` | Join pod |
| `flame.fill` | Streaks, stakes |
| `checkmark.circle.fill` | Completed |
| `xmark.circle.fill` | Missed |
| `target` | Goals |
| `calendar` | Frequency |
| `clock` | Deadline |
| `bell` | Reminders |
| `camera` | Photo proof |
| `hand.thumbsup` | React |
| `archivebox` | Archive |

---

## Appendix: Screen Count Summary

| Category | Count |
|----------|-------|
| Launch/Auth | 2 |
| Tabs | 3 |
| Pod Flows | 3 |
| Goal Flows | 3 |
| **Total Screens** | **11** |

---

*Document generated for SEEN iOS App v1.0*
