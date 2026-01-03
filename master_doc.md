# SEEN - Master Documentation

> **Social Accountability App for Small Groups**
>
> Last Updated: January 3, 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Project Structure](#2-project-structure)
3. [Tech Stack](#3-tech-stack)
4. [Database Schema](#4-database-schema)
5. [API Endpoints](#5-api-endpoints)
6. [iOS App Architecture](#6-ios-app-architecture)
7. [Backend Architecture](#7-backend-architecture)
8. [Key Features & Implementation](#8-key-features--implementation)
9. [Business Logic & Rules](#9-business-logic--rules)
10. [Deployment & Infrastructure](#10-deployment--infrastructure)
11. [Development Guide](#11-development-guide)
12. [System Architecture Diagram](#12-system-architecture-diagram)
13. [Critical Invariants](#13-critical-invariants)
14. [Future Enhancements](#14-future-enhancements)

---

## 1. Executive Summary

SEEN is a native iOS accountability app that enables small groups ("Pods") to hold each other accountable to goals through structured check-ins, visible progress, and social accountability.

**Core Value Proposition:** *"Social friction + Habit tracking"* — users stay motivated because they don't want to let their group down.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Pod** | Small group (max 8 members) with shared visibility into each other's goals |
| **Goal** | A recurring habit with deadline, frequency, and optional proof requirement |
| **Check-in** | Daily record of goal completion (COMPLETED, MISSED, or SKIPPED) |
| **Streak** | Consecutive days of completed check-ins (resets on MISSED) |
| **Interaction** | Reactions (emoji) and comments on check-ins and posts |

---

## 2. Project Structure

```
seen/
├── seen-backend/           # Node.js + Express + TypeScript backend
│   ├── prisma/
│   │   ├── schema.prisma   # Database schema (33 models)
│   │   └── migrations/     # Database migrations
│   ├── src/
│   │   ├── index.ts        # Server entry point
│   │   ├── routes/         # API route handlers (10 modules)
│   │   ├── lib/            # Shared utilities (jwt, push, storage)
│   │   ├── middleware/     # Auth, error handling
│   │   └── workers/        # Background jobs (deadline, reminder)
│   ├── package.json
│   └── Procfile            # Railway deployment config
│
├── seen-ios/               # Native iOS app (SwiftUI)
│   └── SEEN/
│       └── SEEN/
│           ├── Views/      # SwiftUI views (14 files)
│           ├── Services/   # API clients & business logic (8 files)
│           ├── Models/     # Data models (7 files)
│           ├── Components/ # Reusable UI components (8 files)
│           └── Config.swift
│
├── spec.md                 # System specification
├── mvp.md                  # Implementation guide (11 phases)
├── ui.md                   # Design system & HIG compliance
├── screens.md              # UI/UX screen specifications
└── master_doc.md           # This file
```

---

## 3. Tech Stack

### Backend

| Component | Technology | Purpose |
|-----------|------------|---------|
| Runtime | Node.js 20 LTS | Server runtime |
| Framework | Express.js | HTTP server |
| Language | TypeScript (strict) | Type safety |
| ORM | Prisma 7.2.0 | Database client |
| Database | PostgreSQL 16 | Primary data store |
| Job Queue | BullMQ 5.66.4 | Background jobs |
| Cache | Redis 5.8.2 | Queue persistence |
| Storage | Cloudflare R2 | Photo/video storage |
| Auth | apple-signin-auth | Apple token verification |
| Tokens | jsonwebtoken | JWT management |
| Timezone | Luxon 3.7.2 | Timezone calculations |
| Validation | Zod 4.3.4 | Schema validation |

### iOS

| Component | Technology | Purpose |
|-----------|------------|---------|
| UI Framework | SwiftUI | Native views |
| Target | iOS 17+ | Minimum version |
| Networking | URLSession + async/await | API calls |
| Local Storage | SwiftData | Offline cache |
| Auth | AuthenticationServices | Sign in with Apple |
| Keychain | Security framework | Secure token storage |
| Architecture | MVVM + Services | State management |

---

## 4. Database Schema

### Core Models

#### User & Authentication
```prisma
model User {
  id         String   @id @default(uuid())
  appleId    String?  @unique
  email      String?  @unique
  name       String
  avatarUrl  String?
  timezone   String   @default("America/New_York")
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt

  // Relations
  memberships    PodMember[]
  goals          Goal[]
  checkIns       CheckIn[]
  interactions   Interaction[]
  deviceTokens   DeviceToken[]
  authoredPosts  PodPost[]      @relation("PostAuthor")
  targetedPosts  PodPost[]      @relation("PostTarget")
  postReactions  PostReaction[]
  feedComments   FeedComment[]
}

model RefreshToken {
  id        String    @id @default(uuid())
  userId    String
  tokenHash String
  expiresAt DateTime
  revokedAt DateTime?
  createdAt DateTime  @default(now())
}

model DeviceToken {
  id        String   @id @default(uuid())
  userId    String
  token     String   @unique
  platform  String   @default("ios")
  createdAt DateTime @default(now())
}
```

#### Pods & Membership
```prisma
model Pod {
  id          String   @id @default(uuid())
  ownerId     String
  name        String
  description String?
  stakes      String?
  maxMembers  Int      @default(8)
  inviteCode  String   @unique
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  members PodMember[]
  goals   Goal[]
  posts   PodPost[]
}

model PodMember {
  id       String        @id @default(uuid())
  podId    String
  userId   String
  role     PodRole       @default(MEMBER)  // OWNER, ADMIN, MEMBER
  status   MemberStatus  @default(ACTIVE)  // ACTIVE, LEFT, KICKED
  joinedAt DateTime      @default(now())

  @@unique([podId, userId])
}
```

#### Goals & Check-ins
```prisma
model Goal {
  id            String        @id @default(uuid())
  podId         String
  userId        String
  title         String
  description   String?
  frequencyType FrequencyType // DAILY, WEEKLY, SPECIFIC_DAYS
  frequencyDays Int[]         // [1,3,5] for Mon/Wed/Fri
  reminderTime  String?       // "09:00"
  deadlineTime  String        @default("23:59")
  timezone      String        // Snapshot at creation
  requiresProof Boolean       @default(false)
  currentStreak Int           @default(0)
  longestStreak Int           @default(0)
  isArchived    Boolean       @default(false)
  createdAt     DateTime      @default(now())
  updatedAt     DateTime      @updatedAt

  checkIns     CheckIn[]
  feedComments FeedComment[]
}

model CheckIn {
  id              String       @id @default(uuid())
  goalId          String
  userId          String
  date            DateTime     // Normalized to start of day
  status          CheckInStatus // COMPLETED, MISSED, SKIPPED
  proofUrl        String?
  comment         String?
  clientTimestamp DateTime?
  createdAt       DateTime     @default(now())

  interactions Interaction[]
  feedComments FeedComment[]

  @@unique([goalId, date])
}
```

#### Social Features
```prisma
model Interaction {
  id        String          @id @default(uuid())
  checkInId String
  userId    String
  type      InteractionType // HIGH_FIVE, FIRE, CLAP, HEART
  createdAt DateTime        @default(now())

  @@unique([checkInId, userId])
}

model PodPost {
  id           String     @id @default(uuid())
  podId        String
  userId       String
  type         PostType   // ENCOURAGEMENT, NUDGE, CELEBRATION, CHECK_IN
  content      String?
  mediaUrl     String?
  mediaType    MediaType? // PHOTO, VIDEO, AUDIO
  targetUserId String?
  createdAt    DateTime   @default(now())

  reactions    PostReaction[]
  feedComments FeedComment[]
}

model PostReaction {
  id        String          @id @default(uuid())
  postId    String
  userId    String
  type      InteractionType
  createdAt DateTime        @default(now())

  @@unique([postId, userId])
}

model FeedComment {
  id        String     @id @default(uuid())
  userId    String
  content   String?
  mediaUrl  String?
  mediaType MediaType?
  checkInId String?    // Either checkInId OR postId
  postId    String?
  createdAt DateTime   @default(now())
}
```

### Enums
```prisma
enum PodRole { OWNER, ADMIN, MEMBER }
enum MemberStatus { ACTIVE, LEFT, KICKED }
enum FrequencyType { DAILY, WEEKLY, SPECIFIC_DAYS }
enum CheckInStatus { COMPLETED, MISSED, SKIPPED }
enum InteractionType { HIGH_FIVE, FIRE, CLAP, HEART }
enum PostType { ENCOURAGEMENT, NUDGE, CELEBRATION, CHECK_IN }
enum MediaType { PHOTO, VIDEO, AUDIO }
```

---

## 5. API Endpoints

### Base URL
- **Production:** `https://seen-production.up.railway.app`
- **Local:** `http://localhost:3000`

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/apple` | Sign in with Apple |
| POST | `/auth/refresh` | Refresh access token |
| POST | `/auth/logout` | Revoke refresh token |

### Users

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users/me` | Get current user profile |
| PATCH | `/users/me` | Update profile |
| GET | `/users/me/stats` | Get user statistics |
| POST | `/users/me/device-token` | Register push token |
| POST | `/users/me/avatar` | Upload avatar |

### Pods

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/pods` | List user's pods |
| POST | `/pods` | Create new pod |
| GET | `/pods/:id` | Get pod details |
| PATCH | `/pods/:id` | Update pod settings |
| POST | `/pods/join` | Join pod by invite code |
| DELETE | `/pods/:id/members/:userId` | Remove/leave pod |

### Goals

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/pods/:podId/goals` | List pod's goals |
| POST | `/pods/:podId/goals` | Create goal |
| GET | `/goals/:id` | Get goal details |
| PATCH | `/goals/:id` | Update goal |
| DELETE | `/goals/:id` | Archive goal |

### Check-ins

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/checkins` | Submit check-in |
| GET | `/goals/:goalId/history` | Get check-in history |
| GET | `/goals/:goalId/history/stats` | Get statistics |

### Feed

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/feed` | Global feed |
| GET | `/feed/unified` | Unified feed (check-ins + posts) |
| GET | `/feed/pod/:podId` | Pod-specific feed |

### Reactions & Comments

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/feed/items/:type/:id/react` | Add reaction |
| DELETE | `/feed/items/:type/:id/react` | Remove reaction |
| GET | `/feed/items/:type/:id/comments` | Get comments |
| POST | `/feed/items/:type/:id/comments` | Add comment |
| DELETE | `/feed/comments/:id` | Delete comment |

### Interactions (Legacy)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/interactions` | Add check-in reaction |
| DELETE | `/interactions/:checkInId` | Remove reaction |

### Posts

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/pods/:podId/posts` | Get pod posts |
| POST | `/pods/:podId/posts` | Create post |

### Uploads

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/uploads/presign` | Get presigned upload URL |

### Health & Admin

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| DELETE | `/admin/reset-all` | Reset all data (dev) |
| GET | `/seed-info` | Get seed info (dev) |

---

## 6. iOS App Architecture

### Services Layer

All services are actors (thread-safe singletons):

```swift
// APIClient - HTTP client with automatic token management
actor APIClient {
    static let shared = APIClient()

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T
}

// AuthService - Authentication state
@Observable @MainActor
class AuthService {
    static let shared = AuthService()
    var currentUser: User?
    var isAuthenticated: Bool

    func signInWithApple() async throws
    func logout()
}

// PodService - Pod management
actor PodService {
    static let shared = PodService()

    func getMyPods() async throws -> [PodListItem]
    func createPod(...) async throws -> Pod
    func joinPod(code: String) async throws -> Pod
}

// GoalService - Goal CRUD
actor GoalService {
    static let shared = GoalService()

    func createGoal(...) async throws -> Goal
    func updateGoal(...) async throws -> Goal
    func archiveGoal(id: String) async throws
}

// CheckInService - Check-in submission
actor CheckInService {
    static let shared = CheckInService()

    func submitCheckIn(...) async throws -> CheckIn
    func getHistory(goalId: String) async throws -> [CheckIn]
}

// FeedService - Feed & social
actor FeedService {
    static let shared = FeedService()

    func getUnifiedFeed(cursor: String?) async throws -> UnifiedFeedResponse
    func addReaction(...) async throws -> ReactionResponse
    func addComment(...) async throws -> FeedComment
}

// PhotoUploadService - Media uploads
actor PhotoUploadService {
    static let shared = PhotoUploadService()

    func uploadPhoto(image: UIImage, goalId: String) async throws -> String
}
```

### Views Structure

```
Views/
├── MainTabView.swift       # Tab navigation + UnifiedFeedView + ProfileView
├── AuthView.swift          # Sign in with Apple
├── HomeView.swift          # Pod list with status indicators
├── PodDetailView.swift     # Pod members + goals
├── FeedView.swift          # Activity feed
├── CreateGoalView.swift    # Goal creation form
├── GoalDetailView.swift    # Goal details + history
├── CheckInView.swift       # Check-in submission
├── CommentsSheet.swift     # Comments modal
├── CreatePodView.swift     # Pod creation
├── JoinPodView.swift       # Join by invite code
├── CreateEncouragementView.swift  # Post creation
└── PodDashboardSheet.swift # Pod settings
```

### Models

```swift
// User
struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let name: String
    let avatarUrl: String?
    let timezone: String
    let createdAt: String
}

// Pod
struct PodListItem: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let stakes: String?
    let memberCount: Int
    let maxMembers: Int
    let role: PodRole
    let memberAvatars: [String]?
}

// Goal
struct Goal: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let frequencyType: FrequencyType
    let frequencyDays: [Int]?
    let deadlineTime: String
    let timezone: String
    let requiresProof: Bool
    let currentStreak: Int
    let longestStreak: Int
}

// PodPost (unified feed item)
struct PodPost: Codable, Identifiable {
    let id: String
    let type: PostType
    let content: String?
    let mediaUrl: String?
    let mediaType: MediaType?
    let author: PostAuthor
    let target: PostAuthor?
    let podId: String?
    let podName: String?
    let goalTitle: String?
    let createdAt: String

    // Goal metadata (for CHECK_IN)
    let goalDescription: String?
    let goalFrequency: String?
    let currentStreak: Int?
    let completedAt: String?

    // Interaction data
    let reactionCount: Int
    let commentCount: Int
    let myReaction: InteractionType?
    let topReactions: [InteractionType]
}
```

---

## 7. Backend Architecture

### Entry Point (src/index.ts)

```typescript
import express from 'express';
import cors from 'cors';
import { startDeadlineWorker } from './workers/deadlineWorker';
import { startReminderWorker } from './workers/reminderWorker';

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/auth', authRoutes);
app.use('/users', userRoutes);
app.use('/pods', podRoutes);
app.use('/goals', goalRoutes);
app.use('/checkins', checkinRoutes);
app.use('/feed', feedRoutes);
app.use('/interactions', interactionRoutes);
app.use('/uploads', uploadRoutes);
app.use('/posts', postRoutes);

// Start workers
startDeadlineWorker();
startReminderWorker();

// Health check
app.get('/health', async (req, res) => {
  // Check DB + Redis connectivity
});

app.listen(process.env.PORT || 3000);
```

### Authentication Flow

```typescript
// src/routes/auth.ts
router.post('/apple', async (req, res) => {
  // 1. Verify Apple identity token
  const { sub: appleId, email } = await verifyAppleToken(identityToken);

  // 2. Find or create user
  let user = await prisma.user.findUnique({ where: { appleId } });
  if (!user) {
    user = await prisma.user.create({ data: { appleId, email, name } });
  }

  // 3. Generate tokens
  const accessToken = generateAccessToken(user.id);  // 15m expiry
  const refreshToken = await createRefreshToken(user.id);  // 30d expiry

  return res.json({ user, accessToken, refreshToken });
});

router.post('/refresh', async (req, res) => {
  // Verify and rotate refresh token
  const { accessToken, refreshToken } = await verifyAndRotateRefreshToken(token);
  return res.json({ accessToken, refreshToken });
});
```

### Background Workers

```typescript
// src/workers/deadlineWorker.ts
// Runs every 15 minutes
async function processDeadlineCheck(goal: Goal) {
  const now = DateTime.now().setZone(goal.timezone);
  const deadlineHour = parseInt(goal.deadlineTime.split(':')[0]);

  // Check if deadline passed
  if (now.hour >= deadlineHour) {
    const today = now.startOf('day').toJSDate();

    // Check if already has check-in
    const existing = await prisma.checkIn.findUnique({
      where: { goalId_date: { goalId: goal.id, date: today } }
    });

    if (!existing) {
      // Create MISSED check-in
      await prisma.checkIn.create({
        data: { goalId: goal.id, userId: goal.userId, date: today, status: 'MISSED' }
      });

      // Reset streak
      await prisma.goal.update({
        where: { id: goal.id },
        data: { currentStreak: 0 }
      });

      // Send push notification
      await notifyMissedCheckIn(goal.userId, goal.title);
    }
  }
}

// src/workers/reminderWorker.ts
// Runs every 1 minute
async function processReminders() {
  const goals = await prisma.goal.findMany({
    where: { reminderTime: { not: null }, isArchived: false }
  });

  for (const goal of goals) {
    const now = DateTime.now().setZone(goal.timezone);
    const [hour, minute] = goal.reminderTime.split(':').map(Number);

    if (now.hour === hour && now.minute === minute) {
      // Check if no check-in today
      const today = now.startOf('day').toJSDate();
      const existing = await prisma.checkIn.findUnique({
        where: { goalId_date: { goalId: goal.id, date: today } }
      });

      if (!existing) {
        await sendPush(goal.userId, {
          title: 'Time to check in!',
          body: `Don't forget: ${goal.title}`,
          data: { type: 'REMINDER', goalId: goal.id }
        });
      }
    }
  }
}
```

---

## 8. Key Features & Implementation

### A. Sign in with Apple

**iOS Flow:**
1. User taps "Sign in with Apple" button
2. System presents native Apple auth sheet
3. User authenticates with Face ID/Touch ID
4. App receives identity token
5. Token sent to `POST /auth/apple`
6. Backend verifies with Apple servers
7. User created/found, JWT tokens returned
8. Tokens stored in Keychain

### B. Pod Management

- **Creation:** Owner sets name, description, stakes, max members
- **Invite Code:** 6-character alphanumeric, unique per pod
- **Joining:** Enter code → become MEMBER role
- **Leaving:** Member can leave; owner can kick members
- **Visibility:** All members see all goals and check-ins

### C. Goal & Streak System

**Frequency Types:**
- `DAILY` - Every day
- `WEEKLY` - Once per week
- `SPECIFIC_DAYS` - e.g., Mon/Wed/Fri ([1, 3, 5])

**Streak Rules:**
- Increments on COMPLETED check-in
- Resets to 0 on MISSED
- SKIPPED doesn't break streak
- `longestStreak` tracks all-time best

**Timezone Handling:**
- Goal.timezone set at creation from user's timezone
- Never changes (prevents travel confusion)
- All deadline calculations use goal's timezone

### D. Check-in Flow

```
User opens goal → Taps "Check In" → Optionally adds photo/note
    ↓
POST /checkins { goalId, status: "COMPLETED", proofUrl?, comment? }
    ↓
Backend validates:
  - Goal exists and belongs to user
  - No duplicate for today
  - If requiresProof, proofUrl must be present
    ↓
Creates CheckIn record → Updates streak → Returns success
    ↓
Feed updated → Pod members see activity
```

### E. Photo Upload Flow

```
User selects photo → App compresses to JPEG
    ↓
POST /uploads/presign { goalId, fileType: "jpg" }
    ↓
Backend generates presigned URL (5 min expiry)
Returns: { uploadUrl, publicUrl, key }
    ↓
App uploads directly to Cloudflare R2 via PUT
    ↓
App submits check-in with publicUrl as proofUrl
```

### F. Unified Feed

Combines check-ins and pod posts chronologically:

```typescript
// For CHECK_IN items
{
  id: "...",
  type: "CHECK_IN",
  author: { id, name, avatarUrl },
  goalTitle: "Morning Workout",
  goalDescription: "30 min exercise",
  goalFrequency: "Daily",
  currentStreak: 10,
  completedAt: "2026-01-03T09:30:00Z",
  mediaUrl: "https://...",
  reactionCount: 5,
  commentCount: 2,
  myReaction: "FIRE",
  topReactions: ["FIRE", "HIGH_FIVE"]
}

// For posts (ENCOURAGEMENT, NUDGE, CELEBRATION)
{
  id: "...",
  type: "ENCOURAGEMENT",
  author: { id, name, avatarUrl },
  target: { id, name, avatarUrl },
  content: "You've got this! Keep going!",
  reactionCount: 3,
  commentCount: 1,
  ...
}
```

### G. Reactions & Comments

**Reaction Types:** HIGH_FIVE, FIRE, CLAP, HEART

**Implementation:**
- One reaction per user per item
- Tapping same reaction removes it
- Tapping different reaction updates it
- Real-time count updates in feed

**Comments:**
- Text + optional media (photo/video)
- Displayed chronologically
- Author can delete own comments

### H. Push Notifications

**Types:**
| Type | Trigger | Message |
|------|---------|---------|
| REMINDER | reminderTime reached | "Time to check in: {goal}" |
| MISSED | Deadline passed, no check-in | "You missed: {goal}" |
| REACTION | Someone reacted to your check-in | "{name} reacted to your check-in" |
| COMMENT | Someone commented | "{name} commented on your check-in" |

---

## 9. Business Logic & Rules

### Timezone-Aware Deadlines

```
Goal created in "America/Chicago" with deadline 23:59
User travels to "America/Los_Angeles" (2 hours behind)

At 11:00 PM LA time (1:00 AM Chicago time):
  → Deadline already passed in Chicago
  → MISSED check-in created
  → Streak reset

This is intentional - goal's timezone is fixed at creation.
```

### Offline Check-in Handling

```
clientTimestamp acceptance window: 6 hours in the past

User checks in at 10:00 PM (offline)
Lands and syncs at 2:00 AM (after midnight)
clientTimestamp: 10:00 PM yesterday

Server sees timestamp within 6 hours:
  → Creates check-in for yesterday
  → If MISSED exists, converts to COMPLETED
  → Streak preserved
```

### Streak Edge Cases

```
Goal: SPECIFIC_DAYS [Mon, Wed, Fri]

Mon: COMPLETED (streak = 1)
Tue: (not a goal day, streak stays 1)
Wed: COMPLETED (streak = 2)
Thu: (not a goal day, streak stays 2)
Fri: SKIPPED (streak = 2, skip preserves)
Mon: MISSED (streak = 0, reset!)
```

### Idempotent Operations

- Deadline worker checks for existing MISSED before creating
- Multiple worker runs won't create duplicates
- Refresh token rotation revokes old token atomically

---

## 10. Deployment & Infrastructure

### Railway Configuration

```
Service: seen-production
├── PostgreSQL 16 (DATABASE_URL)
├── Redis (REDIS_URL)
└── Node.js 20 LTS
```

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://...

# Redis
REDIS_URL=redis://...

# Authentication
JWT_SECRET=<base64-encoded-32-bytes>
APPLE_CLIENT_ID=com.obey.SEEN

# Cloudflare R2
R2_ACCOUNT_ID=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET_NAME=seen-uploads
R2_PUBLIC_URL=https://cdn.seen.app

# Push Notifications (APNs)
APNS_KEY_ID=...
APNS_TEAM_ID=...
APNS_KEY_PATH=./AuthKey.p8
```

### Deployment Commands

```bash
# Backend
cd seen-backend
npm install
npm run build          # tsc + prisma generate
npm start              # prisma migrate deploy + node dist/index.js

# iOS
cd seen-ios/SEEN
xcodebuild -scheme SEEN -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Procfile
```
web: npm start
```

---

## 11. Development Guide

### Local Setup

```bash
# Backend
cd seen-backend
npm install
cp .env.example .env   # Configure environment
npx prisma migrate dev # Run migrations
npm run dev            # Start with hot reload

# iOS
cd seen-ios/SEEN
open SEEN.xcodeproj
# Update Config.swift with local API URL
# Build and run in simulator
```

### Database Migrations

```bash
# Create new migration
npx prisma migrate dev --name add_feature_x

# Apply migrations (production)
npx prisma migrate deploy

# Reset database (dev only)
npx prisma migrate reset
```

### Testing Endpoints

```bash
# Health check
curl https://seen-production.up.railway.app/health

# With authentication
curl -H "Authorization: Bearer <token>" \
  https://seen-production.up.railway.app/users/me
```

### Admin Endpoints (Dev Only)

```bash
# Reset all data
curl -X DELETE https://seen-production.up.railway.app/admin/reset-all

# Get seed info
curl https://seen-production.up.railway.app/seed-info
```

---

## 12. System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     iOS App (SwiftUI)                           │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐   │
│  │ Auth View  │ │ Home View  │ │ Feed View  │ │ Profile    │   │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘   │
│         │                │               │              │        │
│         └────────────────┴───────────────┴──────────────┘        │
│                         │ HTTPS                                   │
│                    APIClient (Bearer JWT)                         │
└────────────────────────┬──────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
   ┌────▼─────────────────────────────────┴───┐
   │  Railway (seen-production.up.railway.app)  │
   │                                            │
   │  ┌────────────────────────────────────┐    │
   │  │   Express.js API Server            │    │
   │  │ • Auth (Sign in with Apple)        │    │
   │  │ • JWT token management             │    │
   │  │ • Pod/Goal/CheckIn CRUD            │    │
   │  │ • Feed + Social endpoints          │    │
   │  │ • Presigned URL generation         │    │
   │  │ • Push notification trigger        │    │
   │  └────────────────────────────────────┘    │
   │         │        │        │                 │
   │  ┌──────▼──┐  ┌──▼────┐   │                 │
   │  │Postgres │  │ Redis │   │                 │
   │  │   16    │  │       │   │                 │
   │  └─────────┘  └───────┘   │                 │
   │                           │                 │
   │  ┌────────────────────────▼─────────────┐   │
   │  │   BullMQ Workers (same process)      │   │
   │  │ • Deadline Worker (every 15 min)     │   │
   │  │   - Detects missed goals             │   │
   │  │   - Sends push notifications         │   │
   │  │ • Reminder Worker (every 1 min)      │   │
   │  │   - Timezone-aware reminders         │   │
   │  │   - Sends push notifications         │   │
   │  └──────────────────────────────────────┘   │
   │                                             │
   └─────────────────────────────────────────────┘
             │              │
   ┌─────────▼──┐  ┌───────▼──────────────┐
   │ Cloudflare │  │  Apple Push          │
   │ R2 (CDN)   │  │  Notification (APNs) │
   │            │  │                      │
   │ Photos &   │  │  Device tokens +     │
   │ Videos     │  │  notification payloads│
   └────────────┘  └──────────────────────┘
```

---

## 13. Critical Invariants

These are non-negotiable principles that define SEEN's identity:

1. **Missed check-ins are system-generated**, not user-declared
2. **Deadlines evaluated in goal's timezone**, not current location
3. **Pods intentionally small** (max 8 members for intimacy)
4. **Visibility is primary enforcement mechanism**, not punishment
5. **Recovery from failure must be possible but never invisible**
6. **No goal state change without feed-visible event**
7. **Push notifications are core dependency**, not optional
8. **Time is first-class domain concern** (timezone-aware, testable)
9. **Optimizes for long-term trust over short-term engagement**
10. **System notices when someone disappears** (silence is signal)

---

## 14. Future Enhancements

### Planned Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Vacation Mode | Pause goals without losing streaks | High |
| In-app Chat | Group messaging per pod | Medium |
| Monetary Stakes | Stripe integration for real consequences | Medium |
| Analytics | User engagement tracking | Low |
| Web Dashboard | Companion web app | Low |
| Android App | Native Android version | Future |
| Webhook Support | Third-party integrations | Future |
| AI Coach | Generative feedback based on patterns | Future |

### Technical Debt

- [ ] Complete Apple HIG compliance (ui.md)
- [ ] Dynamic Type support in all views
- [ ] Full offline support with sync
- [ ] Video playback in feed
- [ ] Voice note recording for comments

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| Backend TypeScript files | 24 |
| iOS Swift files | 48 |
| Database models | 33 |
| API endpoints | 40+ |
| Background workers | 2 |
| Lines of code (estimated) | ~15,000 |

---

*This documentation consolidates information from spec.md, mvp.md, ui.md, screens.md, and the codebase itself. For detailed implementation guides, refer to mvp.md. For UI specifications, see screens.md.*
