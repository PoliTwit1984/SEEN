import express, { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import podRoutes from './routes/pods';
import goalRoutes from './routes/goals';
import checkInRoutes from './routes/checkins';
import feedRoutes from './routes/feed';
import interactionRoutes from './routes/interactions';
import deviceRoutes from './routes/devices';
import uploadRoutes from './routes/uploads';
import waitlistRoutes from './routes/waitlist';
import postRoutes from './routes/posts';
import commentRoutes from './routes/comments';
import { errorHandler } from './middleware/errorHandler';
import { prisma } from './lib/prisma';
import { startDeadlineWorker, scheduleAllDeadlineChecks } from './workers/deadlineWorker';
import { startReminderWorker, scheduleAllReminders } from './workers/reminderWorker';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', async (_req: Request, res: Response) => {
  let dbStatus = 'disconnected';

  try {
    await prisma.$queryRaw`SELECT 1`;
    dbStatus = 'connected';
  } catch (error) {
    console.error('Database health check failed:', error);
  }

  res.json({
    success: true,
    data: {
      status: 'ok',
      timestamp: new Date().toISOString(),
      database: dbStatus,
    },
  });
});

// Admin endpoint to reset all data (for development)
app.delete('/admin/reset-all', async (_req: Request, res: Response) => {
  try {
    // Delete in order due to foreign key constraints
    await prisma.interaction.deleteMany({});
    await prisma.goalComment.deleteMany({});
    await prisma.checkIn.deleteMany({});
    await prisma.goal.deleteMany({});
    await prisma.podPost.deleteMany({});
    await prisma.podMember.deleteMany({});
    await prisma.pod.deleteMany({});

    res.json({
      success: true,
      message: 'All pods and related data deleted',
    });
  } catch (error) {
    console.error('Reset failed:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to reset data',
    });
  }
});

// Temporary: Get first pod and user for seeding
app.get('/seed-info', async (_req: Request, res: Response) => {
  try {
    const user = await prisma.user.findFirst({ orderBy: { createdAt: 'asc' } });
    const pod = await prisma.pod.findFirst({ orderBy: { createdAt: 'asc' } });
    res.json({ 
      success: true, 
      data: { 
        userId: user?.id, 
        userName: user?.name,
        podId: pod?.id,
        podName: pod?.name 
      } 
    });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// Temporary seed endpoint for demo data
app.post('/seed-demo', async (req: Request, res: Response) => {
  try {
    const { podId, userId } = req.body;
    
    if (!podId || !userId) {
      res.status(400).json({ success: false, error: 'podId and userId required' });
      return;
    }

    // Create mock users
    const alice = await prisma.user.upsert({
      where: { id: 'mock-alice' },
      update: {},
      create: {
        id: 'mock-alice',
        appleId: 'mock-apple-alice',
        name: 'Alice Chen',
        email: 'alice@example.com',
        timezone: 'America/New_York',
      },
    });

    const bob = await prisma.user.upsert({
      where: { id: 'mock-bob' },
      update: {},
      create: {
        id: 'mock-bob',
        appleId: 'mock-apple-bob',
        name: 'Bob Martinez',
        email: 'bob@example.com',
        timezone: 'America/Los_Angeles',
      },
    });

    const carol = await prisma.user.upsert({
      where: { id: 'mock-carol' },
      update: {},
      create: {
        id: 'mock-carol',
        appleId: 'mock-apple-carol',
        name: 'Carol Johnson',
        email: 'carol@example.com',
        timezone: 'America/Chicago',
      },
    });

    // Add mock users to the pod
    await prisma.podMember.upsert({
      where: { podId_userId: { podId, userId: alice.id } },
      update: {},
      create: { podId, userId: alice.id, role: 'MEMBER', status: 'ACTIVE' },
    });

    await prisma.podMember.upsert({
      where: { podId_userId: { podId, userId: bob.id } },
      update: {},
      create: { podId, userId: bob.id, role: 'MEMBER', status: 'ACTIVE' },
    });

    await prisma.podMember.upsert({
      where: { podId_userId: { podId, userId: carol.id } },
      update: {},
      create: { podId, userId: carol.id, role: 'MEMBER', status: 'ACTIVE' },
    });

    // Create goals for mock users
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const aliceGoal = await prisma.goal.upsert({
      where: { id: 'mock-goal-alice' },
      update: {},
      create: {
        id: 'mock-goal-alice',
        userId: alice.id,
        podId,
        title: 'Morning meditation 🧘',
        description: '10 minutes of mindfulness',
        frequencyType: 'DAILY',
        deadlineTime: '08:00',
        timezone: 'America/New_York',
        requiresProof: false,
        currentStreak: 12,
        longestStreak: 15,
        startDate: new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000),
      },
    });

    const bobGoal = await prisma.goal.upsert({
      where: { id: 'mock-goal-bob' },
      update: {},
      create: {
        id: 'mock-goal-bob',
        userId: bob.id,
        podId,
        title: 'Gym workout 💪',
        description: 'At least 30 min exercise',
        frequencyType: 'DAILY',
        deadlineTime: '18:00',
        timezone: 'America/Los_Angeles',
        requiresProof: true,
        currentStreak: 5,
        longestStreak: 21,
        startDate: new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000),
      },
    });

    const carolGoal = await prisma.goal.upsert({
      where: { id: 'mock-goal-carol' },
      update: {},
      create: {
        id: 'mock-goal-carol',
        userId: carol.id,
        podId,
        title: 'Read 20 pages 📚',
        description: 'Daily reading habit',
        frequencyType: 'DAILY',
        deadlineTime: '21:00',
        timezone: 'America/Chicago',
        requiresProof: false,
        currentStreak: 0,
        longestStreak: 8,
        startDate: new Date(today.getTime() - 14 * 24 * 60 * 60 * 1000),
      },
    });

    // Create check-ins (Alice checked in today, Bob pending, Carol missed)
    await prisma.checkIn.upsert({
      where: { id: 'mock-checkin-alice-today' },
      update: {},
      create: {
        id: 'mock-checkin-alice-today',
        goalId: aliceGoal.id,
        userId: alice.id,
        status: 'COMPLETED',
        date: today,
        comment: 'Great session! Feeling centered.',
      },
    });

    // Create pod posts
    await prisma.podPost.upsert({
      where: { id: 'mock-post-1' },
      update: {},
      create: {
        id: 'mock-post-1',
        podId,
        userId: alice.id,
        type: 'CELEBRATION',
        content: '🎉 Bob just hit a 5-day streak! Keep it up!',
        createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
      },
    });

    await prisma.podPost.upsert({
      where: { id: 'mock-post-2' },
      update: {},
      create: {
        id: 'mock-post-2',
        podId,
        userId: bob.id,
        type: 'ENCOURAGEMENT',
        content: 'Carol, you got this! 💪 One page at a time.',
        targetUserId: carol.id,
        createdAt: new Date(Date.now() - 30 * 60 * 1000),
      },
    });

    await prisma.podPost.upsert({
      where: { id: 'mock-post-3' },
      update: {},
      create: {
        id: 'mock-post-3',
        podId,
        userId,
        type: 'NUDGE',
        content: 'Hey team, let\'s all check in today! 🎯',
        createdAt: new Date(Date.now() - 10 * 60 * 1000),
      },
    });

    res.json({
      success: true,
      data: {
        message: 'Demo data seeded successfully!',
        users: [alice.name, bob.name, carol.name],
        goals: 3,
        posts: 3,
      },
    });
  } catch (error) {
    console.error('Seed error:', error);
    res.status(500).json({ success: false, error: String(error) });
  }
});

// Routes
app.use('/auth', authRoutes);
app.use('/users', userRoutes);
app.use('/pods', podRoutes);
app.use('/goals', goalRoutes);
app.use('/checkins', checkInRoutes);
app.use('/feed', feedRoutes);
app.use('/interactions', interactionRoutes);
app.use('/devices', deviceRoutes);
app.use('/uploads', uploadRoutes);
app.use('/waitlist', waitlistRoutes);
app.use('/pods', postRoutes);  // Mount post routes under /pods (for /pods/:podId/posts)
app.use('/goals', commentRoutes);  // Mount comment routes under /goals (for /goals/:goalId/comments)

// Error handler
app.use(errorHandler);

// Start server
app.listen(PORT, async () => {
  console.log(`SEEN API running on port ${PORT}`);
  
  // Start workers
  startDeadlineWorker();
  startReminderWorker();
  
  // Schedule deadline checks and reminders for today
  await scheduleAllDeadlineChecks();
  await scheduleAllReminders();
  
  // Re-schedule every hour to catch new goals
  setInterval(async () => {
    await scheduleAllDeadlineChecks();
    await scheduleAllReminders();
  }, 60 * 60 * 1000);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');
  await prisma.$disconnect();
  process.exit(0);
});
