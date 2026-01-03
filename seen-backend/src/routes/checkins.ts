import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { ValidationError, NotFoundError, ForbiddenError, ConflictError } from '../lib/errors';
import { DateTime } from 'luxon';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// POST /checkins - Create a check-in
router.post('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { goalId, status, comment, proofUrl, clientTimestamp } = req.body;

    // Validation
    if (!goalId || typeof goalId !== 'string') {
      throw new ValidationError('Goal ID is required');
    }

    const validStatuses = ['COMPLETED', 'SKIPPED'];
    const checkInStatus = status || 'COMPLETED';
    if (!validStatuses.includes(checkInStatus)) {
      throw new ValidationError('Invalid status. Use COMPLETED or SKIPPED');
    }

    // Get the goal
    const goal = await prisma.goal.findUnique({
      where: { id: goalId },
    });

    if (!goal) {
      throw new NotFoundError('Goal not found');
    }

    if (goal.userId !== req.user!.id) {
      throw new ForbiddenError('You can only check in to your own goals');
    }

    if (goal.isArchived) {
      throw new ValidationError('Cannot check in to an archived goal');
    }

    // Validate proof if required
    // TODO: Re-enable when photo upload is implemented
    // if (goal.requiresProof && checkInStatus === 'COMPLETED' && !proofUrl) {
    //   throw new ValidationError('This goal requires photo proof');
    // }

    // Determine the check-in date based on goal's timezone
    const now = DateTime.now().setZone(goal.timezone);
    const checkInDate = now.startOf('day').toJSDate();

    // Check for existing check-in on this date
    const existingCheckIn = await prisma.checkIn.findUnique({
      where: {
        goalId_date: { goalId, date: checkInDate },
      },
    });

    if (existingCheckIn) {
      throw new ConflictError('Already checked in for today');
    }

    // Validate client timestamp if provided (reject if too old)
    if (clientTimestamp) {
      const clientTime = new Date(clientTimestamp);
      const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);
      if (clientTime < sixHoursAgo) {
        throw new ValidationError('Client timestamp is too old (max 6 hours)');
      }
    }

    // Create check-in
    const checkIn = await prisma.checkIn.create({
      data: {
        goalId,
        userId: req.user!.id,
        date: checkInDate,
        status: checkInStatus,
        comment: comment?.trim() || null,
        proofUrl: proofUrl || null,
        clientTimestamp: clientTimestamp ? new Date(clientTimestamp) : null,
      },
    });

    // Update streak
    await updateStreak(goalId);

    // Fetch updated goal for response
    const updatedGoal = await prisma.goal.findUnique({
      where: { id: goalId },
      select: { currentStreak: true, longestStreak: true },
    });

    res.status(201).json({
      success: true,
      data: {
        id: checkIn.id,
        goalId: checkIn.goalId,
        date: checkIn.date,
        status: checkIn.status,
        comment: checkIn.comment,
        proofUrl: checkIn.proofUrl,
        createdAt: checkIn.createdAt,
        currentStreak: updatedGoal?.currentStreak ?? 0,
        longestStreak: updatedGoal?.longestStreak ?? 0,
      },
    });
  } catch (error) {
    if (
      error instanceof ValidationError ||
      error instanceof NotFoundError ||
      error instanceof ForbiddenError ||
      error instanceof ConflictError
    ) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Create check-in error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create check-in' },
    });
  }
});

// GET /checkins/:goalId - Get check-ins for a goal
router.get('/:goalId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { goalId } = req.params;
    const { limit = '30', offset = '0' } = req.query;

    const goal = await prisma.goal.findUnique({
      where: { id: goalId },
      include: {
        pod: {
          include: {
            members: {
              where: { userId: req.user!.id, status: 'ACTIVE' },
            },
          },
        },
      },
    });

    if (!goal) {
      throw new NotFoundError('Goal not found');
    }

    // User must be goal owner or pod member
    const isPodMember = goal.pod.members.length > 0;
    const isOwner = goal.userId === req.user!.id;

    if (!isOwner && !isPodMember) {
      throw new ForbiddenError('You do not have access to this goal');
    }

    const checkIns = await prisma.checkIn.findMany({
      where: { goalId },
      orderBy: { date: 'desc' },
      take: Math.min(parseInt(limit as string), 100),
      skip: parseInt(offset as string),
    });

    res.json({
      success: true,
      data: checkIns.map((c) => ({
        id: c.id,
        date: c.date,
        status: c.status,
        comment: c.comment,
        proofUrl: c.proofUrl,
        createdAt: c.createdAt,
      })),
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Get check-ins error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get check-ins' },
    });
  }
});

// GET /checkins/today/:goalId - Check if already checked in today
router.get('/today/:goalId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { goalId } = req.params;

    const goal = await prisma.goal.findUnique({
      where: { id: goalId },
    });

    if (!goal) {
      throw new NotFoundError('Goal not found');
    }

    if (goal.userId !== req.user!.id) {
      throw new ForbiddenError('You can only check your own goals');
    }

    const now = DateTime.now().setZone(goal.timezone);
    const today = now.startOf('day').toJSDate();

    const checkIn = await prisma.checkIn.findUnique({
      where: {
        goalId_date: { goalId, date: today },
      },
    });

    res.json({
      success: true,
      data: {
        checkedIn: !!checkIn,
        checkIn: checkIn
          ? {
              id: checkIn.id,
              status: checkIn.status,
              createdAt: checkIn.createdAt,
            }
          : null,
      },
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Check today error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to check today status' },
    });
  }
});

// Helper: Update streak after check-in
async function updateStreak(goalId: string): Promise<void> {
  const goal = await prisma.goal.findUnique({
    where: { id: goalId },
  });

  if (!goal) return;

  // Get all completed check-ins ordered by date
  const checkIns = await prisma.checkIn.findMany({
    where: {
      goalId,
      status: 'COMPLETED',
    },
    orderBy: { date: 'desc' },
  });

  if (checkIns.length === 0) {
    await prisma.goal.update({
      where: { id: goalId },
      data: { currentStreak: 0 },
    });
    return;
  }

  // Calculate current streak
  let currentStreak = 0;
  const now = DateTime.now().setZone(goal.timezone);
  let expectedDate = now.startOf('day');

  for (const checkIn of checkIns) {
    const checkInDate = DateTime.fromJSDate(checkIn.date).setZone(goal.timezone).startOf('day');

    // For daily goals, each day should have a check-in
    if (goal.frequencyType === 'DAILY') {
      if (checkInDate.equals(expectedDate) || checkInDate.equals(expectedDate.minus({ days: 1 }))) {
        currentStreak++;
        expectedDate = checkInDate.minus({ days: 1 });
      } else {
        break; // Streak broken
      }
    } else if (goal.frequencyType === 'WEEKLY') {
      // For weekly, check if within the same week
      const weekStart = expectedDate.startOf('week');
      const checkInWeekStart = checkInDate.startOf('week');

      if (checkInWeekStart.equals(weekStart) || checkInWeekStart.equals(weekStart.minus({ weeks: 1 }))) {
        currentStreak++;
        expectedDate = checkInWeekStart.minus({ weeks: 1 }).endOf('week');
      } else {
        break;
      }
    } else if (goal.frequencyType === 'SPECIFIC_DAYS') {
      // For specific days, just count consecutive check-ins on valid days
      const dayOfWeek = checkInDate.weekday % 7; // Convert to 0-6 (Sun-Sat)
      if (goal.frequencyDays.includes(dayOfWeek)) {
        currentStreak++;
      }
      // Simplified: just count the streak of completed check-ins
    }
  }

  // Update goal with new streak
  const longestStreak = Math.max(goal.longestStreak, currentStreak);

  await prisma.goal.update({
    where: { id: goalId },
    data: {
      currentStreak,
      longestStreak,
    },
  });
}

export default router;
