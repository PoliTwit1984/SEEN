import { Queue, Worker, Job } from 'bullmq';
import IORedis from 'ioredis';

// Redis connection
const getRedisConnection = () => {
  const redisUrl = process.env.REDIS_URL;
  
  if (!redisUrl) {
    console.warn('REDIS_URL not configured - queues disabled');
    return null;
  }

  return new IORedis(redisUrl, {
    maxRetriesPerRequest: null,
  });
};

let connection: IORedis | null = null;

export const getConnection = () => {
  if (!connection) {
    connection = getRedisConnection();
  }
  return connection;
};

// Queue names
export const QUEUE_NAMES = {
  DEADLINE: 'deadline-check',
  REMINDER: 'reminder',
} as const;

// Create queues
export const createQueue = (name: string) => {
  const conn = getConnection();
  if (!conn) return null;
  
  return new Queue(name, { connection: conn });
};

// Create workers
export const createWorker = <T>(
  name: string,
  processor: (job: Job<T>) => Promise<void>
) => {
  const conn = getConnection();
  if (!conn) return null;

  return new Worker<T>(name, processor, {
    connection: conn,
    concurrency: 5,
  });
};

// Queues singleton
let deadlineQueue: Queue | null = null;
let reminderQueue: Queue | null = null;

export const getDeadlineQueue = () => {
  if (!deadlineQueue) {
    deadlineQueue = createQueue(QUEUE_NAMES.DEADLINE);
  }
  return deadlineQueue;
};

export const getReminderQueue = () => {
  if (!reminderQueue) {
    reminderQueue = createQueue(QUEUE_NAMES.REMINDER);
  }
  return reminderQueue;
};
