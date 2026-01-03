# mvp.md — SEEN Build Phases

Break the spec into testable slices. Each phase delivers working iOS + backend code you can verify before moving on.

---

## Phase 1: Hello World (Connection Test)

**Goal:** Prove iOS can talk to Railway backend.

### Backend
- [ ] Express + TypeScript project scaffold
- [ ] Single endpoint: `GET /health` → `{ "status": "ok", "timestamp": "..." }`
- [ ] Deploy to Railway (no Postgres yet)

### iOS
- [ ] New SwiftUI project
- [ ] Single screen with a button: "Ping Server"
- [ ] On tap, call `/health` and display the response
- [ ] Hardcode the Railway URL for now

### Claude Code Prompts

**Prompt 1 (Backend):**
```
Create a new Node.js backend project for an app called SEEN in a folder called "seen-backend".

Requirements:
- Use Express.js with TypeScript in strict mode
- Set up the project with: npm init, tsconfig.json, and these dependencies: express, typescript, ts-node-dev, @types/express, @types/node
- Create src/index.ts with a single endpoint: GET /health that returns JSON: { "success": true, "data": { "status": "ok", "timestamp": "<ISO timestamp>" } }
- Add npm scripts: "dev" for local development with hot reload, "build" for compiling TS, "start" for production
- Include a .gitignore for node_modules, dist, .env
- The server should listen on process.env.PORT or 3000
- Add a Procfile with: web: npm start

Do not add any database or authentication yet. Keep it minimal.
```

**Prompt 2 (iOS):**
```
Create a new SwiftUI iOS app called "SEEN" in a folder called "seen-ios".

Requirements:
- Target iOS 17+
- Create a simple launch screen with the app name "SEEN" centered
- Create a HomeView with:
  - A title "SEEN" at the top
  - A button labeled "Ping Server"
  - A text area below that shows the server response
- When the button is tapped, make a GET request to a configurable base URL + "/health"
- Store the base URL in a Config.swift file as a static constant (hardcode "http://localhost:3000" for now)
- Display the response JSON or an error message
- Use async/await with URLSession
- Keep it minimal, no pods/goals/auth yet
```

### Test
1. Run backend locally: `npm run dev`
2. Run iOS app in simulator
3. Tap "Ping Server"
4. See "ok" + timestamp displayed

### Railway Setup

**Prompt 3 (Infrastructure):**
```
Help me set up the SEEN backend on Railway using the CLI.

I have the Railway CLI installed. Run these commands in the seen-backend directory:

1. Login (if needed): railway login
2. Create new project: railway init (name it "seen")
3. Deploy the Express app: railway up
4. Get the public URL: railway domain

After deployment, give me the Railway URL so I can update the iOS app Config.swift.

Don't add Postgres or Redis yet—that comes in Phase 2 and Phase 8.
```

**Manual steps if CLI doesn't work:**
1. Go to railway.app dashboard
2. New Project → Deploy from GitHub repo
3. Or: New Project → Empty project, then `railway link` locally

### Deploy Checklist
1. Run `railway up` from seen-backend/
2. Run `railway domain` to get public URL
3. Update iOS Config.swift with Railway URL
4. Test from simulator → should hit Railway

### Success
✅ Round-trip request works. You have a deployed backend and an iOS app that talks to it.

---

## Phase 2: Auth (Sign in with Apple)

**Goal:** User can sign in and stay signed in.

### Backend
- [ ] Add Postgres to Railway
- [ ] Prisma schema: `User` table only
- [ ] `POST /auth/apple` — verify identity token, create/find user, return JWT
- [ ] `POST /auth/refresh` — rotate refresh token
- [ ] `GET /users/me` — return current user (requires auth)
- [ ] Auth middleware that validates JWT on protected routes

### iOS
- [ ] Sign in with Apple button on launch screen
- [ ] On success, send token to `/auth/apple`
- [ ] Store access + refresh tokens in Keychain
- [ ] Navigate to a "Home" screen that calls `/users/me` and displays user name
- [ ] Handle token refresh on 401

### Claude Code Prompts

**Prompt 1 (Backend - Database Setup):**
```
Add Prisma and PostgreSQL to the seen-backend project.

Requirements:
- Install dependencies: prisma, @prisma/client
- Initialize Prisma with PostgreSQL
- Create schema.prisma with a User model:
  - id: UUID, primary key, auto-generated
  - appleId: String, unique, optional (for Sign in with Apple)
  - email: String, unique, optional
  - name: String
  - avatarUrl: String, optional
  - timezone: String, default "America/New_York"
  - createdAt: DateTime, auto
  - updatedAt: DateTime, auto
- Use snake_case for database column names with @map
- Add a RefreshToken model:
  - id: UUID
  - userId: FK to User
  - tokenHash: String (we'll store SHA256 of token, not the token itself)
  - expiresAt: DateTime
  - createdAt: DateTime
  - revokedAt: DateTime, optional
- Create the initial migration
- Update .gitignore to exclude .env but include .env.example
- Create .env.example with DATABASE_URL placeholder
```

**Prompt 2 (Backend - Auth Endpoints):**
```
Add authentication endpoints to seen-backend.

Requirements:
- Install: jsonwebtoken, @types/jsonwebtoken, apple-signin-auth, crypto
- Create src/lib/jwt.ts:
  - generateAccessToken(userId): 15 min expiry, RS256 or HS256 with JWT_SECRET env var
  - generateRefreshToken(userId): 30 day expiry, store hash in RefreshToken table
  - verifyAccessToken(token): returns payload or throws
- Create src/middleware/auth.ts:
  - authMiddleware that extracts Bearer token, verifies, attaches user to req
  - Returns 401 with { success: false, error: { code: "UNAUTHORIZED", message: "..." } } on failure
- Create src/routes/auth.ts with:
  - POST /auth/apple: accepts { identityToken, firstName?, lastName? }, verifies with Apple, finds or creates User, returns { accessToken, refreshToken, user, isNewUser }
  - POST /auth/refresh: accepts { refreshToken }, validates against RefreshToken table, rotates token, returns new pair
  - POST /auth/logout: revokes refresh token
- Create src/routes/users.ts with:
  - GET /users/me (protected): returns current user data
- Use the standard response envelope: { success: true, data: {...} } or { success: false, error: {...} }
- Add routes to the Express app
```

**Prompt 3 (iOS - Auth Flow):**
```
Add Sign in with Apple authentication to the seen-ios app.

Requirements:
- Create Services/AuthService.swift:
  - Store accessToken and refreshToken in Keychain (use a simple KeychainHelper class)
  - Function signInWithApple(identityToken:, firstName:, lastName:) that calls POST /auth/apple
  - Function refreshTokens() that calls POST /auth/refresh
  - Function logout() that calls POST /auth/logout and clears Keychain
  - Function getCurrentUser() that calls GET /users/me
  - isAuthenticated computed property
- Create Services/APIClient.swift:
  - Base URL from Config
  - Automatically attach Authorization: Bearer <token> header
  - On 401 response, attempt token refresh, retry original request once
  - Return decoded responses using Codable
- Create Models/User.swift with Codable struct matching backend response
- Update the app flow:
  - If not authenticated, show AuthView with "Sign in with Apple" button (ASAuthorizationAppleIDButton)
  - On sign in, call AuthService, navigate to HomeView
  - HomeView calls getCurrentUser() on appear and displays "Hello, <name>!"
  - Add a "Sign Out" button that calls logout and returns to AuthView
- Handle the Sign in with Apple flow using AuthenticationServices framework
```

### Test
1. Add Postgres to Railway (see Railway Setup below)
2. Set DATABASE_URL in Railway env vars
3. Deploy backend
4. In iOS, tap "Sign in with Apple"
5. Complete Apple auth flow
6. See "Hello, <your name>!" on Home screen
7. Kill app, reopen → still signed in (token persisted)
8. Tap Sign Out → returns to auth screen

### Railway Setup

**Prompt 4 (Add Postgres):**
```
Help me add Postgres to my Railway project using the CLI.

Run these commands from seen-backend/:

1. Add Postgres: railway add --database postgres
2. This auto-injects DATABASE_URL into the environment
3. Run Prisma migration on Railway: railway run npx prisma migrate deploy
4. Redeploy: railway up

Verify DATABASE_URL is available with: railway variables
```

**Generate JWT Secret:**
```bash
# Run locally, then add to Railway
openssl rand -base64 32

# Add to Railway
railway variables set JWT_SECRET=<paste-the-output>
```

### Success
✅ Full auth flow works. User persists in database.

---

## Phase 3: Pods (Create & Join)

**Goal:** User can create a pod and invite others.

### Backend
- [ ] Prisma schema: `Pod`, `PodMember` tables
- [ ] `POST /pods` — create pod, generate invite code, creator becomes OWNER
- [ ] `GET /pods` — list user's pods
- [ ] `GET /pods/:id` — pod details + member list
- [ ] `POST /pods/join` — join via invite code

### iOS
- [ ] Home screen shows list of pods (empty state if none)
- [ ] "Create Pod" button → form (name, description, stakes)
- [ ] Pod detail screen showing members + invite code
- [ ] "Join Pod" button → enter invite code
- [ ] Pull-to-refresh on pod list

### Claude Code Prompts

**Prompt 1 (Backend - Pod Schema):**
```
Add Pod and PodMember models to the seen-backend Prisma schema.

Requirements:
- Pod model:
  - id: UUID, primary key
  - ownerId: FK to User
  - name: String, max 50 chars
  - description: String, optional, max 200 chars
  - stakes: String, optional, max 100 chars (e.g., "Loser buys dinner")
  - maxMembers: Int, default 8
  - isPrivate: Boolean, default true
  - inviteCode: String, unique, 6 chars alphanumeric uppercase
  - createdAt, updatedAt
- PodMember model:
  - id: UUID
  - podId: FK to Pod (cascade delete)
  - userId: FK to User (cascade delete)
  - role: Enum OWNER | MEMBER
  - status: Enum ACTIVE | LEFT | KICKED
  - joinedAt: DateTime
  - Unique constraint on [podId, userId]
- Add relations: User has many ownedPods, User has many memberships (PodMember), Pod has many members (PodMember)
- Create and run the migration
```

**Prompt 2 (Backend - Pod Endpoints):**
```
Add pod CRUD endpoints to seen-backend.

Requirements:
- Create src/lib/inviteCode.ts:
  - generateInviteCode(): returns random 6-char alphanumeric uppercase string
  - Retry if collision (check DB)
- Create src/routes/pods.ts (all routes protected with authMiddleware):
  - GET /pods: list all pods where user is an ACTIVE member, include memberCount
  - POST /pods: create pod with { name, description?, stakes?, maxMembers? }
    - Generate invite code
    - Create Pod
    - Create PodMember with role OWNER
    - Return pod with invite code
  - GET /pods/:id: get pod details + all ACTIVE members (id, name, avatarUrl, role, joinedAt)
    - 403 if user is not a member
  - POST /pods/join: accept { inviteCode }
    - Find pod by invite code (404 if not found)
    - Check if already a member (409 CONFLICT)
    - Check if pod is full (409 POD_FULL)
    - Create PodMember with role MEMBER
    - Return pod details
  - DELETE /pods/:id/members/:userId:
    - Owner can remove anyone
    - User can remove themselves (leave)
    - Update status to LEFT or KICKED
- Use standard response envelope
- Add routes to Express app
```

**Prompt 3 (iOS - Pod UI):**
```
Add pod management UI to the seen-ios app.

Requirements:
- Create Models/Pod.swift with Codable structs for Pod and PodMember
- Create Services/PodService.swift:
  - getMyPods() -> [Pod]
  - createPod(name:, description:, stakes:) -> Pod
  - getPod(id:) -> Pod (with members)
  - joinPod(inviteCode:) -> Pod
  - leavePod(id:)
- Update HomeView:
  - Show list of user's pods
  - Empty state: "No pods yet. Create one or join with an invite code."
  - Pull-to-refresh
  - "Create Pod" button (+ icon in nav bar)
  - "Join Pod" button
- Create CreatePodView:
  - Form with: name (required), description, stakes
  - "Create" button
  - On success, dismiss and refresh pod list
- Create JoinPodView:
  - Text field for invite code (auto-uppercase, 6 char limit)
  - "Join" button
  - Show errors (invalid code, already member, pod full)
- Create PodDetailView:
  - Pod name as title
  - Description and stakes if present
  - "Invite Code: XXXXXX" with copy button
  - List of members with role badges (crown for owner)
  - "Leave Pod" button (not shown for owner)
- Navigation: HomeView -> PodDetailView on pod tap
```

### Test
1. Create a pod called "Test Squad"
2. See it appear in your pod list
3. Open it, see yourself as owner with crown
4. Copy invite code
5. Sign in as a different Apple ID (or test account)
6. Tap "Join Pod", enter invite code
7. Both users see each other in member list
8. Second user taps "Leave Pod" → removed from pod

### Success
✅ Multi-user pods work. Invite flow works.

---

## Phase 4: Goals (CRUD)

**Goal:** User can create goals within a pod.

### Backend
- [ ] Prisma schema: `Goal` table
- [ ] `POST /pods/:id/goals` — create goal for current user
- [ ] `GET /pods/:id/goals` — list all goals in pod (all members)
- [ ] `PATCH /goals/:id` — edit goal (owner only)
- [ ] `DELETE /goals/:id` — archive goal (soft delete)

### iOS
- [ ] Pod detail screen shows goals grouped by member
- [ ] "Add Goal" button → form (title, frequency, reminder time, deadline time, requires proof toggle)
- [ ] Goal row shows title + frequency badge
- [ ] Swipe to archive

### Claude Code Prompts

**Prompt 1 (Backend - Goal Schema):**
```
Add Goal model to the seen-backend Prisma schema.

Requirements:
- Goal model:
  - id: UUID, primary key
  - podId: FK to Pod (cascade delete)
  - userId: FK to User (cascade delete)
  - title: String, max 100 chars
  - description: String, optional, max 500 chars
  - frequencyType: Enum DAILY | WEEKLY | SPECIFIC_DAYS
  - frequencyDays: Int[] (0-6 where 0=Sunday, used for SPECIFIC_DAYS)
  - reminderTime: String, optional ("HH:MM" format)
  - deadlineTime: String, default "23:59" ("HH:MM" format)
  - timezone: String (IANA format, snapshot from user at creation)
  - requiresProof: Boolean, default false
  - startDate: Date
  - endDate: Date, optional
  - currentStreak: Int, default 0
  - longestStreak: Int, default 0
  - isArchived: Boolean, default false
  - createdAt, updatedAt
- Add relations to Pod and User
- Add index on [podId] and [userId]
- Create and run the migration
```

**Prompt 2 (Backend - Goal Endpoints):**
```
Add goal CRUD endpoints to seen-backend.

Requirements:
- Create src/routes/goals.ts (all protected):
  - POST /pods/:podId/goals: create goal for current user
    - Validate user is ACTIVE member of pod (403 if not)
    - Validate: title required, frequencyType required, frequencyDays required if SPECIFIC_DAYS
    - Set timezone from user's current timezone
    - Set startDate to today if not provided
    - Return created goal
  - GET /pods/:podId/goals: list all goals in pod
    - Optional query param: userId (filter by user)
    - Optional query param: includeArchived (default false)
    - Validate user is ACTIVE member of pod
    - Return goals with user info (id, name, avatarUrl)
  - PATCH /goals/:goalId: update goal
    - Only goal owner can edit (403 if not)
    - Updatable: title, description, frequencyType, frequencyDays, reminderTime, deadlineTime, requiresProof, endDate
    - Return updated goal
  - DELETE /goals/:goalId: archive goal (set isArchived = true)
    - Only goal owner can archive
    - Return success
- Add validation for time format "HH:MM" using regex
- Add routes to Express app
```

**Prompt 3 (iOS - Goal UI):**
```
Add goal management UI to the seen-ios app.

Requirements:
- Create Models/Goal.swift with Codable struct matching backend
- Create Services/GoalService.swift:
  - getGoals(podId:) -> [Goal]
  - createGoal(podId:, title:, frequencyType:, frequencyDays:, reminderTime:, deadlineTime:, requiresProof:) -> Goal
  - updateGoal(goalId:, ...) -> Goal
  - archiveGoal(goalId:)
- Create Enums/FrequencyType.swift: DAILY, WEEKLY, SPECIFIC_DAYS (raw String values)
- Update PodDetailView:
  - Add a "Goals" section below members
  - Group goals by member (show member name as section header)
  - Each goal row shows: title, frequency badge (e.g., "Daily", "Mon/Wed/Fri")
  - "Add Goal" button in nav bar (only adds goals for current user)
  - Swipe to delete (archive) on user's own goals only
- Create CreateGoalView:
  - Form with:
    - Title (required)
    - Frequency picker (Daily / Weekly / Specific Days)
    - Day selector (shown only for Specific Days) - multi-select buttons for S M T W T F S
    - Reminder time picker (optional)
    - Deadline time picker (default 11:59 PM)
    - "Requires Photo Proof" toggle
  - "Create" button
  - On success, dismiss and refresh pod
- Create EditGoalView (reuse form from Create, pre-populated)
- Tapping a goal row opens EditGoalView for own goals, does nothing for others' goals
```

### Test
1. Open a pod
2. Tap "Add Goal"
3. Create: "Run 5k" / Specific Days / Mon, Wed, Fri / Deadline 9:00 PM
4. See it appear under your name in the pod
5. Tap to edit, change title to "Run 3k"
6. Swipe to archive, confirm it disappears

### Success
✅ Goals persist and display correctly.

---

## Phase 5: Check-ins (Simple)

**Goal:** User can tap to complete a goal. No photos yet.

### Backend
- [ ] Prisma schema: `CheckIn` table
- [ ] `POST /goals/:id/checkin` — create check-in (COMPLETED or SKIPPED)
- [ ] `GET /goals/:id/history` — list check-ins for calendar view
- [ ] Prevent duplicate check-ins for same date (return 409)
- [ ] Update `goal.current_streak` on successful check-in

### iOS
- [ ] Today's goals shown prominently on pod screen
- [ ] Tap goal → confirmation sheet → "Mark Complete" or "Skip"
- [ ] Goal row updates to show ✓ after check-in
- [ ] Simple history view (list of dates + status)

### Claude Code Prompts

**Prompt 1 (Backend - CheckIn Schema):**
```
Add CheckIn model to the seen-backend Prisma schema.

Requirements:
- CheckIn model:
  - id: UUID, primary key
  - goalId: FK to Goal (cascade delete)
  - userId: FK to User (cascade delete)
  - date: Date (the logical date in user's timezone, not DateTime)
  - status: Enum COMPLETED | MISSED | SKIPPED
  - proofUrl: String, optional (for Phase 7)
  - comment: String, optional, max 500 chars
  - clientTimestamp: DateTime, optional (for offline support)
  - createdAt: DateTime
- Unique constraint on [goalId, date] - one check-in per goal per day
- Add indexes on [userId] and [goalId, date]
- Add relations to Goal and User
- Create and run migration
```

**Prompt 2 (Backend - CheckIn Endpoints):**
```
Add check-in endpoints to seen-backend.

Requirements:
- Create src/routes/checkins.ts (all protected):
  - POST /goals/:goalId/checkin:
    - Accept { status, comment?, clientTimestamp? }
    - status must be COMPLETED or SKIPPED (not MISSED - that's system-generated)
    - Validate user owns this goal (403 if not)
    - Validate goal is not archived
    - Calculate "today" in goal's timezone
    - Check if check-in already exists for today (409 CONFLICT if so)
    - Create CheckIn record
    - If status is COMPLETED, update goal.currentStreak and goal.longestStreak
    - Return created check-in
  - GET /goals/:goalId/history:
    - Query params: startDate, endDate (default last 30 days)
    - Validate user is member of the goal's pod
    - Return goal info + array of check-ins + stats:
      - totalDays, completedDays, missedDays, skippedDays, completionRate
- Create src/lib/streak.ts:
  - calculateStreak(goalId): queries check-ins, calculates current consecutive COMPLETED days (accounting for frequency)
  - Call this after each check-in
- Add routes to Express app
```

**Prompt 3 (iOS - CheckIn UI):**
```
Add simple check-in UI to the seen-ios app.

Requirements:
- Create Models/CheckIn.swift with Codable struct
- Create Enums/CheckInStatus.swift: COMPLETED, MISSED, SKIPPED
- Create Services/CheckInService.swift:
  - checkIn(goalId:, status:, comment:) -> CheckIn
  - getHistory(goalId:, startDate:, endDate:) -> GoalHistory (includes goal, checkIns, stats)
- Update PodDetailView:
  - Add "Today" section at the top
  - Show only goals that are active today (based on frequencyType/frequencyDays)
  - Each row shows: goal title, status indicator (checkmark if done, empty circle if pending)
  - Tapping a pending goal shows a confirmation sheet:
    - "Mark Complete" button (primary)
    - "Skip Today" button (secondary)
    - "Cancel" button
  - After check-in, animate the checkmark appearing
- Create GoalHistoryView:
  - Accessible by long-pressing a goal or via a "History" button
  - Show stats at top: current streak, longest streak, completion rate
  - List of dates with status indicators (green check, red X, gray skip)
  - Scrollable, most recent at top
- Handle 409 error gracefully: show "Already checked in today" toast
```

### Test
1. Open pod with a daily goal
2. See goal in "Today" section with empty circle
3. Tap goal, tap "Mark Complete"
4. See checkmark appear, streak updates
5. Try to check in again → shows "Already checked in" message
6. Open history → see today as COMPLETED
7. Check streak count increased by 1

### Success
✅ Core check-in loop works. Streaks increment.

---

## Phase 6: Pod Feed

**Goal:** See what everyone in the pod is doing today.

### Backend
- [ ] `GET /pods/:id/feed` — returns:
  - `today`: each member's goals + status (COMPLETED/PENDING/MISSED)
  - `recentActivity`: last 20 check-ins across all members
- [ ] Cursor-based pagination for `recentActivity`

### iOS
- [ ] Pod screen redesign:
  - **Top section:** Today's status grid (member avatars with green ring / empty ring)
  - **Bottom section:** Scrollable feed of recent check-ins
- [ ] Tapping a member shows their goals for today
- [ ] Pull-to-refresh

### Claude Code Prompts

**Prompt 1 (Backend - Feed Endpoint):**
```
Add the pod feed endpoint to seen-backend.

Requirements:
- Add to src/routes/pods.ts:
  - GET /pods/:podId/feed:
    - Query params: limit (default 20, max 50), cursor (checkIn ID for pagination)
    - Validate user is ACTIVE member of pod
    - Return two sections:
    
    1. "today" object:
      - date: today's date string
      - members: array of { userId, name, avatarUrl, goals: [] }
      - Each goal includes: goalId, title, status (COMPLETED | PENDING | MISSED), checkInId (if exists), proofUrl, completedAt
      - Status is PENDING if no check-in exists yet today and deadline hasn't passed
      - Only include goals active today (based on frequency)
    
    2. "recentActivity" array:
      - Recent check-ins across all pod members (COMPLETED and MISSED, not SKIPPED)
      - Include: checkInId, goalId, goalTitle, userId, userName, userAvatarUrl, status, proofUrl, comment, createdAt
      - Order by createdAt desc
      - If cursor provided, return check-ins older than that ID
    
    3. "nextCursor": ID of last check-in (null if no more)

- Create src/lib/todayStatus.ts:
  - Helper to calculate today's date in each user's goal timezone
  - Helper to determine if a goal is active on a given date
```

**Prompt 2 (iOS - Feed UI):**
```
Redesign PodDetailView to show the social feed in seen-ios.

Requirements:
- Create Models/FeedResponse.swift:
  - TodayStatus: date, members (array of MemberStatus)
  - MemberStatus: userId, name, avatarUrl, goals (array of GoalStatus)
  - GoalStatus: goalId, title, status, checkInId?, proofUrl?, completedAt?
  - ActivityItem: checkInId, goalId, goalTitle, userId, userName, userAvatarUrl, status, proofUrl?, comment?, createdAt
- Update Services/PodService.swift:
  - getFeed(podId:, cursor:) -> FeedResponse
- Completely redesign PodDetailView:
  - **Header:** Pod name, member count, settings button
  - **Today Section:**
    - Horizontal scroll of member avatars
    - Green ring around avatar if all goals completed
    - Partial green ring if some completed
    - Empty ring if none completed
    - Red dot indicator if any missed (from yesterday)
    - Tapping avatar shows sheet with that member's goals for today
  - **Feed Section:**
    - Vertical list of recent check-ins (ActivityItem)
    - Each cell shows: avatar, name, goal title, time ago, status badge
    - If proofUrl exists, show thumbnail (placeholder for now, will add images in Phase 7)
    - If comment exists, show it below
    - Infinite scroll: load more when reaching bottom
  - Pull-to-refresh reloads everything
- Create MemberGoalsSheet:
  - Shows selected member's name and goals for today
  - Each goal with status indicator
- Move goal management (Add Goal, Edit, etc.) to a separate "Manage Goals" screen accessible from settings
```

### Test
1. Have 2 users in a pod with goals
2. User A checks in for one goal
3. User B opens app:
   - Sees User A's avatar with partial green ring
   - Sees User A's check-in in the feed
4. User B has empty ring (pending)
5. Pull to refresh updates the view
6. Tap User A's avatar → see their goals and status

### Success
✅ Social visibility works. You can see if others completed their goals.

---

## Phase 7: Photo Check-ins

**Goal:** Users can attach proof photos to check-ins.

### Backend
- [ ] Set up Cloudflare R2 bucket
- [ ] `POST /goals/:id/checkin/upload-url` — return presigned S3 URL
- [ ] Accept `proofUrl` in check-in submission
- [ ] Validate that proof is required if `goal.requires_proof` is true

### iOS
- [ ] If goal requires proof, open camera on check-in tap
- [ ] Upload photo directly to R2 using presigned URL
- [ ] Submit check-in with `proofUrl`
- [ ] Feed shows photo thumbnails
- [ ] Tap thumbnail → full-screen image viewer

### Claude Code Prompts

**Prompt 1 (Backend - R2 Setup):**
```
Add Cloudflare R2 photo upload support to seen-backend.

Requirements:
- Install: @aws-sdk/client-s3, @aws-sdk/s3-request-presigner
- Create src/lib/storage.ts:
  - Configure S3 client for R2 using env vars: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME
  - R2 endpoint format: https://<ACCOUNT_ID>.r2.cloudflarestorage.com
  - generateUploadUrl(key, contentType, contentLength): returns presigned PUT URL, expires in 5 minutes
  - generatePublicUrl(key): returns the public URL (use R2_PUBLIC_URL env var or construct from bucket)
- Add to src/routes/checkins.ts:
  - POST /goals/:goalId/checkin/upload-url:
    - Accept { contentType, contentLength }
    - Validate contentType: image/jpeg, image/png, image/heic, video/mp4, video/quicktime
    - Validate contentLength: max 10MB (10485760 bytes)
    - Generate key: `proofs/${goalId}/${Date.now()}-${random}.${extension}`
    - Return { uploadUrl, publicUrl, expiresAt }
  - Update POST /goals/:goalId/checkin:
    - Accept optional proofUrl in body
    - If goal.requiresProof is true and proofUrl is missing, return 400 VALIDATION_ERROR
    - Store proofUrl in CheckIn record
- Add env vars to .env.example
```

**Prompt 2 (iOS - Photo Upload):**
```
Add photo check-in support to seen-ios.

Requirements:
- Create Services/UploadService.swift:
  - getUploadUrl(goalId:, contentType:, contentLength:) -> UploadUrlResponse
  - uploadFile(uploadUrl:, data:, contentType:) -> Bool (direct PUT to R2)
- Update Services/CheckInService.swift:
  - checkInWithProof(goalId:, status:, comment:, imageData:) -> CheckIn
    - Gets upload URL
    - Uploads image to R2
    - Submits check-in with proofUrl
- Update check-in flow in PodDetailView:
  - When tapping a goal that has requiresProof = true:
    - Open camera (UIImagePickerController or PhotosUI)
    - After capturing, show preview with "Submit" and "Retake" buttons
    - On submit: upload photo, then create check-in
    - Show loading indicator during upload
  - When tapping a goal without requiresProof:
    - Show existing confirmation sheet (no camera)
- Update feed ActivityItem cells:
  - If proofUrl exists, show AsyncImage thumbnail (square, ~80pt)
  - Tapping thumbnail opens FullScreenImageView
- Create FullScreenImageView:
  - Full-screen image with zoom/pan support
  - Close button in corner
  - Use AsyncImage with loading placeholder
- Handle errors: upload failure, camera permission denied
```

### Test
1. Set up Cloudflare R2 (see R2 Setup below)
2. Add R2 env vars to Railway
3. Deploy backend
4. Create goal with "Requires Proof" enabled
5. Tap goal to check in → camera opens
6. Take photo, tap Submit
7. See loading indicator while uploading
8. Check-in completes, photo appears in feed
9. Tap photo → opens full-screen
10. Other users can see the photo

### R2 Setup

**Cloudflare R2 (manual, then add to Railway):**
1. Go to Cloudflare Dashboard → R2
2. Create bucket: `seen-uploads`
3. Settings → CORS: Allow all origins (for presigned uploads)
4. Create API token with read/write permissions
5. Note: Account ID, Access Key ID, Secret Access Key

**Add env vars to Railway:**
```bash
railway variables set R2_ACCOUNT_ID=<your-account-id>
railway variables set R2_ACCESS_KEY_ID=<your-access-key>
railway variables set R2_SECRET_ACCESS_KEY=<your-secret-key>
railway variables set R2_BUCKET_NAME=seen-uploads
railway variables set R2_PUBLIC_URL=https://pub-<hash>.r2.dev
```

**Redeploy:**
```bash
railway up
```

### Success
✅ Photo proof flow works end-to-end.

---

## Phase 8: Workers (Missed Check-ins)

**Goal:** System automatically marks missed goals.

### Backend
- [ ] Add Redis to Railway
- [ ] Set up BullMQ with two repeatable jobs:
  - `check-deadlines` (every 15 min)
  - `send-reminders` (every 1 min) — just log for now, no push yet
- [ ] Deadline worker creates MISSED records when deadline passes
- [ ] Reset streak to 0 on miss

### iOS
- [ ] Feed shows MISSED status with red indicator
- [ ] History view shows MISSED days

### Claude Code Prompts

**Prompt 1 (Backend - Redis & BullMQ Setup):**
```
Add Redis and BullMQ job queue to seen-backend.

Requirements:
- Install: bullmq, ioredis
- Create src/lib/redis.ts:
  - Export Redis connection using REDIS_URL env var
  - Handle connection errors gracefully
- Create src/lib/queue.ts:
  - Create two queues: "deadlines" and "reminders"
  - Export queue instances
- Create src/workers/index.ts:
  - Set up BullMQ Worker for each queue
  - For now, just log when jobs run: console.log(`[DeadlineWorker] Running at ${new Date()}`)
- Update src/index.ts:
  - Import and start workers after Express app starts
  - Register repeatable jobs on startup:
    - deadlines queue: repeat every 15 minutes
    - reminders queue: repeat every 1 minute
  - Only register if not already registered (check for existing repeatable jobs)
- Add REDIS_URL to .env.example
- Add graceful shutdown: close Redis connections on SIGTERM
```

**Prompt 2 (Backend - Deadline Worker Logic):**
```
Implement the deadline worker logic in seen-backend.

Requirements:
- Update src/workers/deadlineWorker.ts:
  - Query all active (non-archived) goals with their users
  - For each goal:
    - Calculate current time in goal.timezone using a library (install luxon or date-fns-tz)
    - Parse goal.deadlineTime (HH:MM)
    - Determine if the deadline for "yesterday" (in goal's timezone) has passed
    - Check if a CheckIn exists for that date
    - If no CheckIn exists and deadline passed:
      - Create CheckIn with status MISSED
      - Set goal.currentStreak = 0
      - Log: `[DeadlineWorker] Marked goal ${goalId} as MISSED for ${date}`
  - Be idempotent: if MISSED record already exists, skip
- Create src/lib/timezone.ts:
  - Helper: getTodayInTimezone(timezone) -> date string
  - Helper: getYesterdayInTimezone(timezone) -> date string
  - Helper: hasDeadlinePassed(timezone, deadlineTime) -> boolean
  - Helper: isGoalActiveOnDate(goal, date) -> boolean (check frequencyType/frequencyDays)
- Write a simple test: create a goal with deadline in the past, run worker, verify MISSED created
```

**Prompt 3 (iOS - MISSED Status Display):**
```
Update seen-ios to display MISSED check-ins properly.

Requirements:
- Update feed ActivityItem display:
  - COMPLETED: green checkmark icon, normal styling
  - MISSED: red X icon, slightly dimmed text, "Missed" label
  - SKIPPED: gray skip icon, "Skipped" label
- Update member avatar rings in Today section:
  - If any goal was MISSED yesterday, show small red dot on avatar
- Update GoalHistoryView:
  - MISSED days show red X
  - Show streak reset visually (e.g., streak counter drops, maybe a small "Streak lost" label)
- Update GoalStatus in feed:
  - If status is MISSED, show sympathetic message like "Missed yesterday"
- No changes needed to check-in flow (users can't manually create MISSED)
```

### Test
1. Add Redis to Railway (see Railway Setup below)
2. Deploy backend with workers
3. Create a goal with deadline 2 minutes from now
4. Don't check in
5. Wait for deadline to pass
6. Wait for worker to run (~15 min max, or trigger manually)
7. Refresh feed → goal shows as MISSED with red X
8. Check goal history → MISSED day appears
9. Streak reset to 0

### Railway Setup

**Prompt 4 (Add Redis):**
```
Help me add Redis to my Railway project for BullMQ job queues.

Run these commands from seen-backend/:

1. Add Redis: railway add --database redis
2. This auto-injects REDIS_URL into the environment
3. Verify: railway variables (should show REDIS_URL)
4. Redeploy with workers: railway up

The workers will start automatically since they run in the same process as the API.
```

**Verify Workers Running:**
```bash
# Check Railway logs
railway logs

# Should see:
# [DeadlineWorker] Running at ...
# [ReminderWorker] Running at ...
```

### Success
✅ Automatic accountability works. No honor system.

---

## Phase 9: Push Notifications

**Goal:** Users get reminded and notified.

### Backend
- [ ] `POST /users/me/device-token` — store APNs token
- [ ] Integrate @parse/node-apn
- [ ] Reminder worker sends push 1 hour before deadline (or at `reminder_time`)
- [ ] Missed worker sends push when goal is marked MISSED
- [ ] Activity push when pod member checks in (optional, can defer)

### iOS
- [ ] Request notification permission on first launch
- [ ] Register device token with backend after auth
- [ ] Handle push tap → navigate to relevant goal/pod

### Claude Code Prompts

**Prompt 1 (Backend - Device Token Storage):**
```
Add device token management to seen-backend.

Requirements:
- Add DeviceToken model to Prisma schema:
  - id: UUID
  - userId: FK to User (cascade delete)
  - token: String, unique (APNs device token)
  - createdAt, updatedAt
  - Index on userId
- Create migration and apply
- Add to src/routes/users.ts:
  - POST /users/me/device-token:
    - Accept { token }
    - Upsert: if token exists for any user, update userId; otherwise create
    - This handles device handoff between accounts
    - Return success
  - DELETE /users/me/device-token:
    - Accept { token }
    - Delete the token record
    - Return success (used on logout)
- Update auth logout to optionally accept device token and delete it
```

**Prompt 2 (Backend - APNs Integration):**
```
Add Apple Push Notification support to seen-backend.

Requirements:
- Install: @parse/node-apn
- Create src/lib/push.ts:
  - Configure APNs provider using env vars:
    - APNS_KEY_ID: Key ID from Apple
    - APNS_TEAM_ID: Team ID from Apple
    - APNS_KEY: Base64-encoded .p8 private key contents
    - APNS_BUNDLE_ID: Your app's bundle ID
    - APNS_PRODUCTION: "true" for production, "false" for sandbox
  - sendPush(userId, notification): 
    - Looks up all device tokens for user
    - Sends push to each token
    - Handles token invalidation (remove invalid tokens from DB)
  - Notification structure:
    - title: string
    - body: string
    - data: object (type, goalId?, podId?, checkInId?)
    - sound: "default"
- Update src/workers/deadlineWorker.ts:
  - After creating MISSED record, call sendPush:
    - title: "Missed check-in 😢"
    - body: goal.title
    - data: { type: "MISSED", goalId }
- Update src/workers/reminderWorker.ts:
  - Query goals where reminderTime matches current time (in goal's timezone)
  - For each, check if check-in exists for today
  - If not, send push:
    - title: "Time to check in! ⏰"
    - body: goal.title
    - data: { type: "REMINDER", goalId }
- Add env vars to .env.example
```

**Prompt 3 (iOS - Push Notifications):**
```
Add push notification support to seen-ios.

Requirements:
- Update AppDelegate or use SwiftUI App lifecycle:
  - Request notification permission on first launch (after sign in)
  - Register for remote notifications
  - Get device token in didRegisterForRemoteNotificationsWithDeviceToken
  - Send token to backend via POST /users/me/device-token
- Create Services/NotificationService.swift:
  - registerDeviceToken(token:)
  - unregisterDeviceToken(token:) - call on logout
  - Handle permission status
- Handle push notification taps:
  - Parse the "data" payload (type, goalId, podId, checkInId)
  - REMINDER: navigate to pod containing that goal
  - MISSED: navigate to pod containing that goal
  - CHECKIN: navigate to pod feed
- Create a simple NavigationCoordinator or use @Environment to handle deep linking
- Update AuthService.logout():
  - Call unregisterDeviceToken before clearing Keychain
- Show in-app notification banner if app is in foreground (optional, can use system default)
- Handle permission denied gracefully: show explanation and link to Settings
```

### Test
1. Set up APNs (see APNs Setup below)
2. Add APNs env vars to Railway
3. Deploy backend
4. Enable notifications when prompted in app
5. Set a goal with reminder time 1 minute from now
6. Background the app
7. Receive reminder push: "Time to check in! ⏰"
8. Tap push → app opens to that pod
9. Let a goal deadline pass without checking in
10. Receive missed push: "Missed check-in 😢"
11. Verify token is removed after logout

### APNs Setup

**Apple Developer Portal (manual):**
1. Go to developer.apple.com → Certificates, IDs & Profiles
2. Keys → Create new key
3. Enable "Apple Push Notifications service (APNs)"
4. Download .p8 file (save it securely, you can only download once)
5. Note: Key ID (10 characters), Team ID (from account page)

**Encode .p8 for Railway:**
```bash
# Base64 encode the .p8 file
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```

**Add env vars to Railway:**
```bash
railway variables set APNS_KEY_ID=<your-key-id>
railway variables set APNS_TEAM_ID=<your-team-id>
railway variables set APNS_KEY=<base64-encoded-p8-contents>
railway variables set APNS_BUNDLE_ID=com.yourname.SEEN
railway variables set APNS_PRODUCTION=false
```

**Note:** Set `APNS_PRODUCTION=true` when submitting to App Store.

**Redeploy:**
```bash
railway up
```

### Success
✅ Push notifications work. Users get nudged.

---

## Phase 10: Polish & Interactions

**Goal:** Make it feel good.

### Backend
- [ ] `POST /checkins/:id/interact` — add reaction (FIRE/CLAP/STRONG)
- [ ] `DELETE /checkins/:id/interact` — remove reaction
- [ ] Include reaction counts in feed response

### iOS
- [ ] Confetti animation on successful check-in
- [ ] Reaction buttons under feed items
- [ ] Show reaction counts + "You reacted" state
- [ ] Streak badges on goal rows
- [ ] Empty states with illustrations
- [ ] Loading skeletons

### Claude Code Prompts

**Prompt 1 (Backend - Interactions):**
```
Add reaction/interaction support to seen-backend.

Requirements:
- Add Interaction model to Prisma schema:
  - id: UUID
  - checkInId: FK to CheckIn (cascade delete)
  - userId: FK to User (cascade delete)
  - type: Enum FIRE | CLAP | STRONG
  - createdAt
  - Unique constraint on [checkInId, userId] - one reaction per user per check-in
- Create migration and apply
- Add to src/routes/checkins.ts:
  - POST /checkins/:checkInId/interact:
    - Accept { type } (FIRE, CLAP, or STRONG)
    - Validate user is member of the check-in's pod
    - Upsert: if interaction exists, update type; otherwise create
    - Return interaction
  - DELETE /checkins/:checkInId/interact:
    - Delete user's interaction on this check-in
    - Return success
- Update GET /pods/:podId/feed response:
  - For each check-in in recentActivity, include:
    - interactionCounts: { FIRE: number, CLAP: number, STRONG: number }
    - myInteraction: "FIRE" | "CLAP" | "STRONG" | null (current user's reaction)
```

**Prompt 2 (iOS - Reactions UI):**
```
Add reaction UI to the feed in seen-ios.

Requirements:
- Create Models/Interaction.swift with Codable struct
- Update Services/CheckInService.swift:
  - addReaction(checkInId:, type:) -> Interaction
  - removeReaction(checkInId:)
- Update ActivityItem in feed:
  - Below each check-in, show reaction bar:
    - Three buttons: 🔥 FIRE, 👏 CLAP, 💪 STRONG
    - Show count next to each if > 0
    - Highlight the button if user has reacted with that type
  - Tapping a reaction:
    - If not reacted: add that reaction, animate button
    - If already reacted with same type: remove reaction
    - If already reacted with different type: change to new type
  - Use optimistic UI: update immediately, rollback on error
- Add subtle animation when reaction is added (button scale + haptic)
```

**Prompt 3 (iOS - Polish):**
```
Add visual polish to seen-ios.

Requirements:
- Create Components/ConfettiView.swift:
  - Simple confetti animation (use CAEmitterLayer or a SwiftUI package)
  - Trigger after successful check-in
  - Auto-dismiss after 2 seconds
- Create Components/SkeletonView.swift:
  - Shimmer loading placeholder
  - Use for feed items while loading
- Update PodDetailView:
  - Show skeleton while feed is loading
  - Empty state for feed: "No activity yet. Be the first to check in!"
  - Empty state for pods list: illustration + "Create your first pod"
- Update goal rows:
  - Show streak badge (flame icon + number) if currentStreak > 0
  - Animate streak increment after check-in
- Add haptic feedback:
  - Light tap on button presses
  - Success haptic on check-in complete
  - Error haptic on failures
- Ensure all images use AsyncImage with placeholder
- Add pull-to-refresh animation
- Review all error states: show friendly messages, not technical errors
```

### Test
1. Check in → see confetti animation
2. Feel haptic feedback
3. Look at feed → see reaction buttons
4. Tap 🔥 on someone's check-in
5. See count increment, button highlighted
6. Other user sees the reaction count
7. Tap again → reaction removed
8. Verify streak badge shows and updates

### Success
✅ App feels polished and rewarding.

---

## Phase 11: Hardening

**Goal:** Production-ready.

### Backend
- [ ] Rate limiting (Redis-based)
- [ ] Input validation on all endpoints (zod)
- [ ] Error logging (Sentry or similar)
- [ ] API versioning (`/v1/` prefix)
- [ ] Health check includes DB + Redis connectivity

### iOS
- [ ] Offline queue for check-ins (submit when back online)
- [ ] Retry logic with exponential backoff
- [ ] Error toasts for failed requests
- [ ] Analytics events (optional)

### Claude Code Prompts

**Prompt 1 (Backend - Rate Limiting & Validation):**
```
Add rate limiting and input validation to seen-backend.

Requirements:
- Install: zod, express-rate-limit, rate-limit-redis
- Create src/lib/validation.ts:
  - Define Zod schemas for all request bodies:
    - CreatePodSchema: { name: string max 50, description?: string max 200, stakes?: string max 100, maxMembers?: number 2-10 }
    - JoinPodSchema: { inviteCode: string length 6, uppercase }
    - CreateGoalSchema: { title: string max 100, frequencyType: enum, frequencyDays?: array of 0-6, etc. }
    - CheckInSchema: { status: enum, comment?: string max 500, proofUrl?: url, clientTimestamp?: datetime }
    - etc. for all endpoints
  - Export a validateBody(schema) middleware that validates req.body
- Create src/middleware/rateLimiter.ts:
  - Use Redis store for distributed rate limiting
  - Create limiters:
    - authLimiter: 10 requests per minute (for /auth/*)
    - joinLimiter: 20 requests per hour (for /pods/join)
    - defaultLimiter: 100 requests per minute (for all authenticated routes)
  - Return standard error envelope on limit: { success: false, error: { code: "RATE_LIMITED", message: "..." } }
- Apply validation middleware to all routes
- Apply rate limiters to appropriate routes
- Update all routes to use /v1 prefix: app.use('/v1', router)
```

**Prompt 2 (Backend - Error Handling & Monitoring):**
```
Add comprehensive error handling and monitoring to seen-backend.

Requirements:
- Install: @sentry/node (or use console logging for MVP)
- Create src/lib/errors.ts:
  - Define custom error classes: ValidationError, UnauthorizedError, ForbiddenError, NotFoundError, ConflictError
  - Each has a code, message, and optional details
- Create src/middleware/errorHandler.ts:
  - Global error handler middleware
  - Catches all errors, logs them, returns standard envelope
  - In production: don't leak stack traces
  - Log to Sentry or console
- Update all routes to throw custom errors instead of inline res.status().json()
- Update GET /health:
  - Check database connectivity (simple query)
  - Check Redis connectivity (PING)
  - Return { status: "ok", database: "connected", redis: "connected" } or appropriate error
- Add request logging middleware: log method, path, status, duration
- Add CORS configuration for production (restrict to your domain)
```

**Prompt 3 (iOS - Offline Support & Error Handling):**
```
Add offline support and robust error handling to seen-ios.

Requirements:
- Create Services/OfflineQueue.swift:
  - Store pending check-ins in UserDefaults or SwiftData when offline
  - Structure: { goalId, status, comment, proofData?, clientTimestamp, retryCount }
  - On app launch and when network becomes available, process queue
  - Exponential backoff: wait 1s, 2s, 4s, 8s between retries, max 5 retries
  - Remove from queue on success or permanent failure (4xx errors)
- Create Utils/NetworkMonitor.swift:
  - Use NWPathMonitor to track connectivity
  - Publish isConnected as @Published property
- Update check-in flow:
  - If offline, save to queue and show "Saved offline, will sync when connected"
  - If online, submit normally
- Create Components/ToastView.swift:
  - Simple toast notification that slides in from top
  - Types: success (green), error (red), info (blue)
  - Auto-dismiss after 3 seconds
- Update APIClient:
  - On network error, check if request can be queued (only check-ins)
  - Show appropriate toast for errors
  - Never show raw error messages to user
- Add connectivity indicator:
  - Small banner at top when offline: "You're offline. Changes will sync when connected."
- Test: enable airplane mode, check in, disable airplane mode, verify sync
```

### Test
1. Turn on airplane mode
2. Try to check in → saved offline, toast confirms
3. Turn off airplane mode
4. Check-in syncs automatically
5. Spam the join endpoint → get rate limited after 20 attempts
6. Send malformed request → get clean validation error
7. Check /health endpoint → shows database and Redis status

### Success
✅ App handles edge cases gracefully. Ready for real users.

---

## Suggested Order

| Phase | Effort | Dependency |
|-------|--------|------------|
| 1. Hello World | 1 hour | None |
| 2. Auth | 4 hours | Phase 1 |
| 3. Pods | 3 hours | Phase 2 |
| 4. Goals | 2 hours | Phase 3 |
| 5. Check-ins | 2 hours | Phase 4 |
| 6. Feed | 3 hours | Phase 5 |
| 7. Photos | 3 hours | Phase 5 |
| 8. Workers | 3 hours | Phase 5 |
| 9. Push | 3 hours | Phase 8 |
| 10. Polish | 4 hours | Phase 6 |
| 11. Hardening | 4 hours | All |

**Total estimated: ~32 hours to full MVP**

---

## How to Use These Prompts

### Setup
1. Create two folders: `seen-backend` and `seen-ios`
2. Open each in separate Claude Code sessions (or switch between them)
3. Have `spec.md` available for Claude Code to reference

### For Each Phase
1. Run the prompts in order (Prompt 1, then 2, then 3)
2. Wait for Claude Code to finish each prompt before starting the next
3. Run the tests manually after all prompts in a phase complete
4. Fix any issues before moving to the next phase
5. Commit your code after each successful phase

### Tips
- If Claude Code gets stuck, paste the relevant section from `spec.md` for context
- For iOS, you may need to run in Xcode to test—Claude Code will create the files
- For backend, test locally with `npm run dev` before deploying
- Keep Railway dashboard open to monitor deploys and logs

### If Something Breaks
Ask Claude Code:
```
The [endpoint/feature] from Phase [N] isn't working. 
Error: [paste error]
Check the implementation against spec.md and fix it.
```

### Reference
Always keep `spec.md` in the project root. You can tell Claude Code:
```
Read spec.md for the full API specification and data models.
```

---

## Railway CLI Quick Reference

```bash
# Auth
railway login              # Login to Railway
railway logout             # Logout

# Project
railway init               # Create new project (interactive)
railway link               # Link existing project to current dir
railway status             # Show current project/environment

# Deploy
railway up                 # Deploy current directory
railway up --detach        # Deploy without watching logs
railway logs               # Stream logs
railway logs --build       # Show build logs

# Databases
railway add                # Add service (interactive)
railway add --database postgres   # Add Postgres
railway add --database redis      # Add Redis

# Environment
railway variables          # List all env vars
railway variables set KEY=value   # Set env var
railway variables get KEY         # Get specific var

# Run commands
railway run <cmd>          # Run command with Railway env vars
railway run npx prisma migrate deploy   # Run migrations
railway run npx prisma studio           # Open Prisma Studio

# Domains
railway domain             # Generate a public domain
railway domain <custom>    # Set custom domain

# Shell
railway shell              # Open shell with env vars loaded
```