import { Job } from 'bullmq';
import { prisma } from '../lib/prisma';
import { createWorker, getDeadlineQueue, QUEUE_NAMES } from '../lib/queue';
import { notifyMissedCheckIn } from '../lib/push';
import { DateTime } from 'luxon';

interface DeadlineJobData {
  goalId: string;
  date: string; // YYYY-MM-DD
}

/**
 * Process deadline check for a goal
 * Called after a goal's deadline passes to mark as missed if no check-in
 */
async function processDeadlineCheck(job: Job<DeadlineJobData>): Promise<void> {
  const { goalId, date } = job.data;

  console.log(`[Deadline Worker] Checking goal ${goalId} for ${date}`);

  // Get the goal
  const goal = await prisma.goal.findUnique({
    where: { id: goalId },
    select: {
      id: true,
      userId: true,
      title: true,
      timezone: true,
      isArchived: true,
      currentStreak: true,
    },
  });

  if (!goal || goal.isArchived) {
    console.log(`[Deadline Worker] Goal ${goalId} not found or archived, skipping`);
    return;
  }

  // Check if there's already a check-in for this date
  const existingCheckIn = await prisma.checkIn.findUnique({
    where: {
      goalId_date: {
        goalId,
        date: new Date(date),
      },
    },
  });

  if (existingCheckIn) {
    console.log(`[Deadline Worker] Check-in already exists for ${goalId} on ${date}`);
    return;
  }

  // No check-in found - mark as MISSED
  console.log(`[Deadline Worker] Marking goal ${goalId} as MISSED for ${date}`);

  await prisma.checkIn.create({
    data: {
      goalId,
      userId: goal.userId,
      date: new Date(date),
      status: 'MISSED',
    },
  });

  // Reset streak to 0
  await prisma.goal.update({
    where: { id: goalId },
    data: {
      currentStreak: 0,
    },
  });

  // Send push notification
  await notifyMissedCheckIn(goal.userId, goal.title, goalId);

  console.log(`[Deadline Worker] Completed processing goal ${goalId}`);
}

/**
 * Schedule deadline check for a goal
 */
export async function scheduleDeadlineCheck(
  goalId: string,
  deadlineTime: string,
  timezone: string,
  date?: string
): Promise<void> {
  const queue = getDeadlineQueue();
  if (!queue) {
    console.warn('[Deadline Worker] Queue not available, skipping schedule');
    return;
  }

  // Calculate when the deadline is
  const now = DateTime.now().setZone(timezone);
  const targetDate = date || now.toISODate();
  
  if (!targetDate) {
    console.error('[Deadline Worker] Could not determine target date');
    return;
  }

  const deadlineDateTime = DateTime.fromISO(`${targetDate}T${deadlineTime}`, {
    zone: timezone,
  });

  // Only schedule if deadline is in the future
  if (deadlineDateTime <= now) {
    console.log(`[Deadline Worker] Deadline already passed for ${goalId} on ${targetDate}`);
    return;
  }

  const delay = deadlineDateTime.diff(now).as('milliseconds');

  // Add job with delay
  await queue.add(
    `deadline-${goalId}-${targetDate}`,
    { goalId, date: targetDate },
    {
      delay,
      jobId: `deadline-${goalId}-${targetDate}`,
      removeOnComplete: true,
      removeOnFail: false,
    }
  );

  console.log(
    `[Deadline Worker] Scheduled check for goal ${goalId} at ${deadlineDateTime.toISO()} (${delay}ms from now)`
  );
}

/**
 * Schedule deadline checks for all active goals
 * Called on server startup and periodically
 */
export async function scheduleAllDeadlineChecks(): Promise<void> {
  const queue = getDeadlineQueue();
  if (!queue) {
    console.warn('[Deadline Worker] Queue not available');
    return;
  }

  console.log('[Deadline Worker] Scheduling deadline checks for all active goals...');

  const goals = await prisma.goal.findMany({
    where: {
      isArchived: false,
    },
    select: {
      id: true,
      deadlineTime: true,
      timezone: true,
      frequencyType: true,
      frequencyDays: true,
    },
  });

  const now = DateTime.now();
  let scheduled = 0;

  for (const goal of goals) {
    const goalNow = now.setZone(goal.timezone);
    const today = goalNow.toISODate();

    if (!today) continue;

    // Check if today is a check-in day for this goal
    const dayOfWeek = goalNow.weekday % 7; // 0 = Sunday

    let isCheckInDay = false;
    if (goal.frequencyType === 'DAILY') {
      isCheckInDay = true;
    } else if (goal.frequencyType === 'WEEKLY') {
      // Weekly goals - check if we're in the right week
      isCheckInDay = true; // Simplified for now
    } else if (goal.frequencyType === 'SPECIFIC_DAYS') {
      isCheckInDay = goal.frequencyDays.includes(dayOfWeek);
    }

    if (isCheckInDay) {
      await scheduleDeadlineCheck(goal.id, goal.deadlineTime, goal.timezone, today);
      scheduled++;
    }
  }

  console.log(`[Deadline Worker] Scheduled ${scheduled} deadline checks`);
}

// Start the worker
export function startDeadlineWorker(): void {
  const worker = createWorker<DeadlineJobData>(QUEUE_NAMES.DEADLINE, processDeadlineCheck);

  if (worker) {
    worker.on('completed', (job) => {
      console.log(`[Deadline Worker] Job ${job.id} completed`);
    });

    worker.on('failed', (job, err) => {
      console.error(`[Deadline Worker] Job ${job?.id} failed:`, err);
    });

    console.log('[Deadline Worker] Started');
  }
}
