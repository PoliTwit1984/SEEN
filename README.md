# SEEN

> Social Accountability App for Small Groups

SEEN is a native iOS app that enables small groups ("Pods") to hold each other accountable to goals through structured check-ins, visible progress, and social accountability.

## Overview

**Core Value:** *"Social friction + Habit tracking"* — users stay motivated because they don't want to let their group down.

### Key Features

- **Pods** - Small groups (max 8 members) with shared goal visibility
- **Goals** - Recurring habits with deadlines, frequencies, and proof requirements
- **Check-ins** - Daily completion tracking with photo/video proof
- **Streaks** - Consecutive completion tracking (resets on missed days)
- **Reactions** - Emoji reactions (HIGH_FIVE, FIRE, CLAP, HEART)
- **Comments** - Text and media comments on check-ins
- **Push Notifications** - Reminders and deadline alerts

## Tech Stack

### Backend
- **Runtime:** Node.js 20 LTS
- **Framework:** Express.js + TypeScript
- **Database:** PostgreSQL 16 (Prisma ORM)
- **Queue:** BullMQ + Redis
- **Storage:** Cloudflare R2
- **Auth:** Sign in with Apple

### iOS
- **Framework:** SwiftUI (iOS 17+)
- **Networking:** URLSession + async/await
- **Architecture:** MVVM + Services
- **Auth:** AuthenticationServices

### Infrastructure
- **Hosting:** Railway
- **Push:** Apple Push Notification Service (APNs)

## Project Structure

```
seen/
├── seen-backend/           # Node.js + Express + TypeScript
│   ├── prisma/             # Database schema & migrations
│   ├── src/
│   │   ├── routes/         # API endpoints
│   │   ├── lib/            # Utilities (jwt, push, storage)
│   │   ├── middleware/     # Auth, error handling
│   │   └── workers/        # Background jobs
│   └── package.json
│
├── seen-ios/               # Native iOS app
│   └── SEEN/
│       └── SEEN/
│           ├── Views/      # SwiftUI views
│           ├── Services/   # API clients
│           ├── Models/     # Data models
│           └── Components/ # Reusable UI
│
├── docs_old/               # Legacy documentation
├── master_doc.md           # Comprehensive documentation
└── README.md               # This file
```

## Getting Started

### Backend

```bash
cd seen-backend
npm install
cp .env.example .env       # Configure environment
npx prisma migrate dev     # Run migrations
npm run dev                # Start with hot reload
```

### iOS

```bash
cd seen-ios/SEEN
open SEEN.xcodeproj
# Build and run in Xcode
```

## API Base URL

- **Production:** `https://seen-production.up.railway.app`
- **Local:** `http://localhost:3000`

## Environment Variables

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
```

## Documentation

For comprehensive documentation, see [master_doc.md](master_doc.md) which covers:

- System architecture
- Database schema (33 models)
- API endpoints (40+)
- iOS app architecture
- Business logic & rules
- Deployment guide

## License

Private - All rights reserved
