import { Job } from 'bullmq';
import { prisma } from '../lib/prisma';
import { createWorker, getReminderQueue, QUEUE_NAMES } from '../lib/queue';
import { notifyReminder } from '../lib/push';
import { DateTime } from 'luxon';

interface ReminderJobData {
  goalId: string;
  date: string; // YYYY-MM-DD
}

/**
 * Process reminder for a goal
 * Sends push notification if user hasn't checked in yet
 */
async function processReminder(job: Job<ReminderJobData>): Promise<void> {
  const { goalId, date } = job.data;

  console.log(`[Reminder Worker] Processing reminder for goal ${goalId} on ${date}`);

  // Get the goal
  const goal = await prisma.goal.findUnique({
    where: { id: goalId },
    select: {
      id: true,
      userId: true,
      title: true,
      isArchived: true,
    },
  });

  if (!goal || goal.isArchived) {
    console.log(`[Reminder Worker] Goal ${goalId} not found or archived, skipping`);
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
    console.log(`[Reminder Worker] Already checked in for ${goalId} on ${date}, skipping reminder`);
    return;
  }

  // Send reminder push notification
  console.log(`[Reminder Worker] Sending reminder for goal ${goalId}`);
  await notifyReminder(goal.userId, goal.title, goalId);

  console.log(`[Reminder Worker] Completed processing goal ${goalId}`);
}

/**
 * Schedule reminder for a goal
 */
export async function scheduleReminder(
  goalId: string,
  reminderTime: string,
  timezone: string,
  date?: string
): Promise<void> {
  const queue = getReminderQueue();
  if (!queue) {
    console.warn('[Reminder Worker] Queue not available, skipping schedule');
    return;
  }

  // Calculate when the reminder should fire
  const now = DateTime.now().setZone(timezone);
  const targetDate = date || now.toISODate();

  if (!targetDate) {
    console.error('[Reminder Worker] Could not determine target date');
    return;
  }

  const reminderDateTime = DateTime.fromISO(`${targetDate}T${reminderTime}`, {
    zone: timezone,
  });

  // Only schedule if reminder time is in the future
  if (reminderDateTime <= now) {
    console.log(`[Reminder Worker] Reminder time already passed for ${goalId} on ${targetDate}`);
    return;
  }

  const delay = reminderDateTime.diff(now).as('milliseconds');

  // Add job with delay
  await queue.add(
    `reminder-${goalId}-${targetDate}`,
    { goalId, date: targetDate },
    {
      delay,
      jobId: `reminder-${goalId}-${targetDate}`,
      removeOnComplete: true,
      removeOnFail: false,
    }
  );

  console.log(
    `[Reminder Worker] Scheduled reminder for goal ${goalId} at ${reminderDateTime.toISO()} (${delay}ms from now)`
  );
}

/**
 * Schedule reminders for all active goals with reminder times
 * Called on server startup and periodically
 */
export async function scheduleAllReminders(): Promise<void> {
  const queue = getReminderQueue();
  if (!queue) {
    console.warn('[Reminder Worker] Queue not available');
    return;
  }

  console.log('[Reminder Worker] Scheduling reminders for all active goals...');

  const goals = await prisma.goal.findMany({
    where: {
      isArchived: false,
      reminderTime: { not: null },
    },
    select: {
      id: true,
      reminderTime: true,
      timezone: true,
      frequencyType: true,
      frequencyDays: true,
    },
  });

  const now = DateTime.now();
  let scheduled = 0;

  for (const goal of goals) {
    if (!goal.reminderTime) continue;

    const goalNow = now.setZone(goal.timezone);
    const today = goalNow.toISODate();

    if (!today) continue;

    // Check if today is a check-in day for this goal
    const dayOfWeek = goalNow.weekday % 7; // 0 = Sunday

    let isCheckInDay = false;
    if (goal.frequencyType === 'DAILY') {
      isCheckInDay = true;
    } else if (goal.frequencyType === 'WEEKLY') {
      isCheckInDay = true; // Simplified
    } else if (goal.frequencyType === 'SPECIFIC_DAYS') {
      isCheckInDay = goal.frequencyDays.includes(dayOfWeek);
    }

    if (isCheckInDay) {
      await scheduleReminder(goal.id, goal.reminderTime, goal.timezone, today);
      scheduled++;
    }
  }

  console.log(`[Reminder Worker] Scheduled ${scheduled} reminders`);
}

// Start the worker
export function startReminderWorker(): void {
  const worker = createWorker<ReminderJobData>(QUEUE_NAMES.REMINDER, processReminder);

  if (worker) {
    worker.on('completed', (job) => {
      console.log(`[Reminder Worker] Job ${job.id} completed`);
    });

    worker.on('failed', (job, err) => {
      console.error(`[Reminder Worker] Job ${job?.id} failed:`, err);
    });

    console.log('[Reminder Worker] Started');
  }
}
