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
import { errorHandler } from './middleware/errorHandler';
import { prisma } from './lib/prisma';
import { startDeadlineWorker, scheduleAllDeadlineChecks } from './workers/deadlineWorker';

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

// Error handler
app.use(errorHandler);

// Start server
app.listen(PORT, async () => {
  console.log(`SEEN API running on port ${PORT}`);
  
  // Start workers
  startDeadlineWorker();
  
  // Schedule deadline checks for today
  await scheduleAllDeadlineChecks();
  
  // Re-schedule every hour to catch new goals
  setInterval(async () => {
    await scheduleAllDeadlineChecks();
  }, 60 * 60 * 1000);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');
  await prisma.$disconnect();
  process.exit(0);
});
