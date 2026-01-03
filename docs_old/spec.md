# spec.md — SEEN (iOS + Backend)

## 0. Summary
**SEEN** is a native iOS app that enables small groups ("Pods") to hold each other accountable to goals via structured check-ins, visible progress, and optional stakes. The iOS app communicates with a REST API backend responsible for auth, data, scheduling, and notifications.

**Core Value:** Social friction + Habit tracking. "I don't want to let the group down." You're not just tracking—you're being *seen*.

---

## 1. System Architecture

### High-Level Diagram
```
┌─────────────────┐         ┌─────────────────────────────────────┐
│   iOS App       │◄───────►│         Railway Project             │
│   (SwiftUI)     │  HTTPS  │                                     │
└─────────────────┘         │  ┌─────────────────────────────┐    │
                            │  │ API Service                 │    │
                            │  │ (Express + BullMQ workers)  │    │
                            │  └──────────┬──────────────────┘    │
                            │             │                       │
                            │  ┌──────────┴──────────┐            │
                            │  │                     │            │
                            │  ▼                     ▼            │
                            │ ┌──────────┐    ┌──────────┐        │
                            │ │ Postgres │    │  Redis   │        │
                            │ └──────────┘    └──────────┘        │
                            └─────────────────────────────────────┘
                                              │
                                              ▼
                                    ┌─────────────────┐
                                    │  Cloudflare R2  │
                                    │  (Photos)       │
                                    └─────────────────┘
```

### Clients
* **iOS App (SwiftUI):**
    * User authentication (Sign in with Apple).
    * Pod + Goal management.
    * Check-in submission (Photo/Text/Simple Tap).
    * "Feed" view for Pod activity.
    * Push notifications (APNs).

### Backend (Single Railway Service)
* **API Server:**
    * REST JSON API (Node.js + Express + TypeScript).
    * Auth & authorization middleware.
    * Business rules (e.g., "Did they check in on time?").
* **Workers (same process via BullMQ):**
    * **Deadline Worker:** Runs every 15 minutes. Checks goal timezones, creates `MISSED` records, resets streaks, sends push.
    * **Reminder Worker:** Runs every 1 minute. Sends reminder push notifications.
* **Database (Railway Postgres):**
    * PostgreSQL 16, provisioned from Railway dashboard.
* **Cache/Queue (Railway Redis):**
    * Redis for BullMQ job queue + rate limiting.
* **Storage (External):**
    * Cloudflare R2 (S3-compatible) for check-in photos.

---

## 2. Authentication

### Methods (MVP)
* **Sign in with Apple (Required):** Low friction, high security.
* **Email/Magic Link (Optional):** Backup for non-iOS or testing.

### Auth Flow
1.  iOS app requests identity token from Apple.
2.  iOS app sends token to Backend `POST /auth/apple`.
3.  Backend verifies token against Apple's keys.
4.  Backend finds or creates `User`.
5.  Backend issues a long-lived session JWT (Access Token).
6.  iOS app stores JWT in Keychain and attaches `Authorization: Bearer <jwt>` to all requests.

### Token Strategy
* **Access Token:** 15 minute lifetime, stored in memory + Keychain
* **Refresh Token:** 30 day lifetime, stored in Keychain only, rotated on each use
* **On 401 response:** iOS app attempts refresh; if that fails, force re-auth

---

## 3. Core Concepts (Domain Model)

### User
* `id` (UUID, PK)
* `email` (String, unique, nullable)
* `name` (String, display name)
* `avatar_url` (String, optional)
* `timezone` (String, IANA format e.g., 'America/Chicago') — **Critical for accurate deadlines.**
* `created_at` (Timestamp)

### Pod
A group of users holding each other accountable.
* `id` (UUID, PK)
* `owner_id` (FK -> User)
* `name` (String)
* `description` (String, includes the "Stakes" e.g., "Loser buys dinner")
* `max_members` (Int, default 5-10 to keep it intimate)
* `is_private` (Bool, default true)
* `invite_code` (String, unique 6-char alphanumeric)
* `created_at` (Timestamp)

### PodMember
Join table linking Users to Pods.
* `id` (UUID, PK)
* `pod_id` (FK -> Pod)
* `user_id` (FK -> User)
* `role` (Enum: OWNER | MEMBER)
* `joined_at` (Timestamp)
* `status` (Enum: ACTIVE | LEFT | KICKED)

### Goal
A specific habit a user wants to track within a Pod.
* `id` (UUID, PK)
* `pod_id` (FK -> Pod)
* `user_id` (FK -> User)
* `title` (String, e.g., "Run 5k" or "Read 30 mins")
* `frequency_type` (Enum: DAILY | WEEKLY | SPECIFIC_DAYS)
* `frequency_days` (Array[Int], e.g., `[1,3,5]` for Mon/Wed/Fri. Null if Daily.)
* `reminder_time` (Time, local to user, e.g., "20:00")
* `deadline_time` (Time, local to user, default "23:59") — **When MISSED triggers**
* `timezone` (String, IANA — snapshot from user at goal creation, avoids travel bugs)
* `requires_proof` (Bool, default False. If True, user must upload photo.)
* `start_date` (Date)
* `end_date` (Date, nullable)
* `current_streak` (Int, calculated cache)
* `is_archived` (Bool)

### CheckIn
The record of an event.
* `id` (UUID, PK)
* `goal_id` (FK -> Goal)
* `user_id` (FK -> User)
* `date` (Date, the logical date this check-in belongs to)
* `status` (Enum: COMPLETED | MISSED | SKIPPED)
    * *COMPLETED*: User did it.
    * *MISSED*: System auto-generated this because deadline passed.
    * *SKIPPED*: User explicitly used a "Skip Day" (if allowed).
* `proof_url` (String, URL to image/video)
* `comment` (String, user reflection)
* `client_timestamp` (Timestamp, when user actually completed — for offline support)
* `created_at` (Timestamp, actual server time of submission)

### Interaction (Optional MVP Phase 2)
Social validation on check-ins.
* `id` (UUID, PK)
* `check_in_id` (FK)
* `user_id` (FK)
* `type` (Enum: FIRE | CLAP | STRONG)

---

## 4. API Specification (Key Endpoints)

### Auth
* `POST /auth/apple` -> Returns `{ accessToken, refreshToken, user }`
* `POST /auth/refresh` -> Returns `{ accessToken, refreshToken }`
* `POST /auth/logout` -> Revokes refresh token
* `POST /users/device-token` -> Register APNs token

### Pods
* `GET /pods` -> List user's pods
* `POST /pods` -> Create new pod
* `POST /pods/join` -> Join via invite code
* `GET /pods/{id}` -> Pod details + member list
* `GET /pods/{id}/feed` -> **The Main View.** Today's status for all members + recent activity (cursor-paginated)

### Goals
* `POST /pods/{id}/goals` -> Create a goal
* `PATCH /goals/{id}` -> Edit frequency/reminders
* `DELETE /goals/{id}` -> Archive (soft delete)

### Check-ins
* `POST /goals/{id}/checkin` -> Submit a check-in (multipart if image)
* `GET /goals/{id}/history` -> Calendar view data with stats

### Interactions
* `POST /checkins/{id}/interact` -> Add reaction
* `DELETE /checkins/{id}/interact` -> Remove reaction

---

## 5. API Response Envelope & Error Codes

### Standard Response Shape
```json
// Success
{ "success": true, "data": { ... } }

// Error
{ "success": false, "error": { "code": "ERROR_CODE", "message": "Human readable" } }
```

### Error Codes
| Code | HTTP | When |
|------|------|------|
| `VALIDATION_ERROR` | 400 | Bad request body |
| `UNAUTHORIZED` | 401 | Missing/invalid token |
| `FORBIDDEN` | 403 | Valid token, wrong permissions |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `CONFLICT` | 409 | Already exists (duplicate check-in, already in pod) |
| `POD_FULL` | 409 | Pod at max_members |
| `RATE_LIMITED` | 429 | Too many requests |

---

## 6. Rate Limits

| Endpoint | Limit | Window |
|----------|-------|--------|
| `POST /auth/*` | 10 | 1 minute |
| `POST /pods/join` | 20 | 1 hour |
| All authenticated | 100 | 1 minute |

---

## 7. Photo Upload Flow

1. Client calls `POST /goals/{id}/checkin/upload-url` with `{ contentType, contentLength }`
2. Server returns `{ uploadUrl, publicUrl, expiresAt }` (presigned S3 URL, 5 min expiry)
3. Client uploads directly to S3 via PUT to `uploadUrl`
4. Client submits check-in with `proofUrl: publicUrl`

**Constraints:**
* Max file size: 10MB
* Allowed types: image/jpeg, image/png, image/heic, video/mp4, video/quicktime
* Video max duration: 30 seconds

---

## 8. Offline Check-in Handling

**Problem:** User completes goal at 6 AM, airplane mode, lands at 2 PM after deadline.

**Solution:**
* Client always sends `clientTimestamp` (ISO8601 with timezone) when submitting
* Server accepts check-ins with client timestamps up to **6 hours** in the past
* Beyond 6 hours, server uses server time (prevents gaming)
* If a `MISSED` record already exists for that date, convert it to `COMPLETED`

---

## 9. Push Notification Payloads

```json
// Reminder (1 hour before deadline)
{
  "aps": { "alert": { "title": "Time to check in! ⏰", "body": "Run 5k" }, "sound": "default" },
  "data": { "type": "REMINDER", "goalId": "uuid" }
}

// Missed
{
  "aps": { "alert": { "title": "Missed check-in 😢", "body": "Run 5k" }, "sound": "default" },
  "data": { "type": "MISSED", "goalId": "uuid" }
}

// Pod Activity (someone checked in)
{
  "aps": { "alert": { "title": "Joe just checked in", "body": "Run 5k 🔥" }, "sound": "default" },
  "data": { "type": "CHECKIN", "podId": "uuid", "checkInId": "uuid" }
}
```

---

## 10. Business Logic: Deadlines & Timezones

### Deadline Definition
* Each goal has a `deadline_time` (default "23:59") and `timezone` (snapshot from user at creation)
* A check-in is MISSED if `deadline_time` passes in the goal's timezone with no COMPLETED/SKIPPED record

### Workers (BullMQ Repeatable Jobs)

**Deadline Worker** — Repeats every 15 minutes
```typescript
// Register on app startup
deadlineQueue.add('check-deadlines', {}, { 
  repeat: { every: 15 * 60 * 1000 } 
});
```
1. Query all active goals
2. For each, check if deadline passed in `goal.timezone`
3. If passed AND no check-in for that date → create MISSED, reset streak, send push

**Reminder Worker** — Repeats every 1 minute
```typescript
reminderQueue.add('send-reminders', {}, { 
  repeat: { every: 60 * 1000 } 
});
```
1. Query goals where `reminder_time` matches current time in `goal.timezone`
2. If no check-in for today → send reminder push

### Timezone & Travel
* `goal.timezone` is set from `user.timezone` at goal creation
* If user updates their timezone, it only affects **new goals**
* Existing goals keep original timezone (prevents mid-day deadline shifts)

---

## 11. Seed Data & Test Accounts

| Email | Notes |
|-------|-------|
| `test1@pods.dev` | Owner of "Morning Crew" pod |
| `test2@pods.dev` | Member of "Morning Crew" |
| `test3@pods.dev` | No pods, fresh account |

**Test Pod:** "Morning Crew" with invite code `TEST01`, pre-populated with mixed history.

**Magic Codes (Dev only):** `TEST01` (join test pod), `FULL01` (POD_FULL error), `BAD001` (NOT_FOUND error)

---

## 12. Tech Stack (Locked)

### Backend
| Component | Choice |
|-----------|--------|
| Runtime | Node.js 20 LTS |
| Framework | Express.js |
| Language | TypeScript (strict mode) |
| ORM | Prisma |
| Database | PostgreSQL 16 (Railway) |
| Job Queue | BullMQ |
| Cache | Redis (Railway) |
| Storage | Cloudflare R2 |
| Push | @parse/node-apn |

### iOS
| Component | Choice |
|-----------|--------|
| UI | SwiftUI (iOS 17+) |
| Networking | URLSession + async/await |
| Local Storage | SwiftData |
| Auth | AuthenticationServices |

### Infrastructure (Railway)

**Railway Project Structure:**
```
seen/
├── api          # Express + BullMQ (single service)
├── postgres     # Railway Postgres addon
└── redis        # Railway Redis addon
```

**Environment Variables (set in Railway dashboard):**
```bash
DATABASE_URL=         # Auto-injected by Railway Postgres
REDIS_URL=            # Auto-injected by Railway Redis
JWT_SECRET=           # Generate: openssl rand -base64 32
APPLE_TEAM_ID=        # From Apple Developer Portal
APPLE_KEY_ID=         # From Apple Developer Portal
APPLE_PRIVATE_KEY=    # .p8 file contents (base64 encoded)
R2_ACCOUNT_ID=        # Cloudflare account ID
R2_ACCESS_KEY_ID=     # R2 API token
R2_SECRET_ACCESS_KEY= # R2 API secret
R2_BUCKET_NAME=       # e.g., "seen-uploads"
R2_PUBLIC_URL=        # e.g., "https://cdn.seen.app"
```

**Estimated Cost (MVP):**
| Service | Cost |
|---------|------|
| Railway (API + Postgres + Redis) | ~$10-20/mo |
| Cloudflare R2 | ~$0-5/mo (10GB free) |
| Apple Developer Account | $99/year |
| **Total** | **~$15-25/mo** |

---

## 13. UX / UI Guidelines

### A. Onboarding
* Clean, high-contrast typography.
* **Permission Request:** "Allow Notifications? (Essential for accountability)"

### B. Pod Dashboard (Main Tab)
* **Header:** Pod Name + Aggregate "Health" or "Streak".
* **Today's Status:** A list of members.
    * *Green Ring:* Checked in.
    * *Empty Ring:* Pending.
    * *Red X:* Missed yesterday.
* **Feed:** Vertical scroll of recent photo check-ins (Instagram style but smaller).

### C. Check-in Flow
* User taps their Goal.
* Camera opens (if `requires_proof` is on).
* User snaps photo -> Adds optional caption -> Taps "Submit".
* Confetti animation.

---

## 14. Future Considerations (Post-MVP)
* **Vacation Mode:** Pause goals without losing streaks.
* **Chat:** Integrated group chat channel per Pod.
* **Monetary Stakes:** Integration with Stripe to charge real money for missed check-ins (donated to charity or paid to other members).

---

## 15. System Invariants (Non-Negotiables)

These invariants define the identity of SEEN. They are architectural and philosophical constraints that must hold true regardless of feature additions, UI changes, or scale.

1. **Missed check-ins are system-generated, not user-declared.** Users may complete or skip; the system alone decides when something is missed.

2. **Deadlines are evaluated in the goal's timezone, not the user's current location.** Travel, device settings, or clock drift must not change accountability semantics.

3. **Pods are intentionally small.** Social accountability degrades rapidly as group size increases. SEEN prioritizes intimacy over reach.

4. **Visibility is the primary enforcement mechanism.** Accountability is driven by being witnessed, not by punishment or gamification.

5. **Recovery from failure must be possible, but never invisible.** A recovered or late completion may restore streaks, but the event history must remain truthful.

6. **No goal state changes without emitting a feed-visible event.** The feed is the shared source of truth for what happened and when.

7. **Push notifications are a core system dependency, not an optional enhancement.** If notifications fail, accountability fails.

8. **Time is a first-class domain concern.** All deadline logic must be explicit, timezone-aware, and testable.

9. **SEEN optimizes for long-term trust over short-term engagement.** Metrics, nudges, and features must not incentivize dishonesty or performative check-ins.

10. **The system must notice when someone disappears.** Silence is itself a signal, and the product must surface it.