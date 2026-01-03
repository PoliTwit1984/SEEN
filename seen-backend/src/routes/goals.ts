import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { ValidationError, NotFoundError, ForbiddenError } from '../lib/errors';
import { DateTime } from 'luxon';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// GET /goals - List user's goals (optionally filter by pod)
router.get('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId } = req.query;

    const goals = await prisma.goal.findMany({
      where: {
        userId: req.user!.id,
        isArchived: false,
        ...(podId ? { podId: podId as string } : {}),
      },
      include: {
        pod: {
          select: { id: true, name: true },
        },
        _count: {
          select: { checkIns: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({
      success: true,
      data: goals.map((g) => ({
        id: g.id,
        podId: g.podId,
        podName: g.pod.name,
        title: g.title,
        description: g.description,
        frequencyType: g.frequencyType,
        frequencyDays: g.frequencyDays,
        reminderTime: g.reminderTime,
        deadlineTime: g.deadlineTime,
        timezone: g.timezone,
        requiresProof: g.requiresProof,
        startDate: g.startDate,
        endDate: g.endDate,
        currentStreak: g.currentStreak,
        longestStreak: g.longestStreak,
        totalCheckIns: g._count.checkIns,
        createdAt: g.createdAt,
      })),
    });
  } catch (error) {
    console.error('List goals error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list goals' },
    });
  }
});

// POST /goals - Create a new goal
router.post('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const {
      podId,
      title,
      description,
      frequencyType,
      frequencyDays,
      reminderTime,
      deadlineTime,
      timezone,
      requiresProof,
      startDate,
      endDate,
    } = req.body;

    // Validation
    if (!podId || typeof podId !== 'string') {
      throw new ValidationError('Pod ID is required');
    }

    if (!title || typeof title !== 'string' || title.trim().length === 0) {
      throw new ValidationError('Goal title is required');
    }

    if (title.length > 100) {
      throw new ValidationError('Title must be 100 characters or less');
    }

    // Verify user is a member of the pod
    const membership = await prisma.podMember.findUnique({
      where: {
        podId_userId: { podId, userId: req.user!.id },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    // Validate frequency
    const validFrequencies = ['DAILY', 'WEEKLY', 'SPECIFIC_DAYS'];
    const freq = frequencyType || 'DAILY';
    if (!validFrequencies.includes(freq)) {
      throw new ValidationError('Invalid frequency type');
    }

    // Validate frequency days for SPECIFIC_DAYS
    let days: number[] = [];
    if (freq === 'SPECIFIC_DAYS') {
      if (!Array.isArray(frequencyDays) || frequencyDays.length === 0) {
        throw new ValidationError('Frequency days required for SPECIFIC_DAYS');
      }
      days = frequencyDays.filter((d: number) => d >= 0 && d <= 6);
      if (days.length === 0) {
        throw new ValidationError('At least one valid day (0-6) required');
      }
    } else if (freq === 'WEEKLY') {
      // Default to Sunday (0) for weekly
      days = frequencyDays?.length ? frequencyDays.filter((d: number) => d >= 0 && d <= 6) : [0];
    }

    // Validate timezone
    const tz = timezone || req.user!.timezone;
    if (!DateTime.now().setZone(tz).isValid) {
      throw new ValidationError('Invalid timezone');
    }

    // Validate deadline time format (HH:mm)
    const deadline = deadlineTime || '23:59';
    if (!/^([01]\d|2[0-3]):([0-5]\d)$/.test(deadline)) {
      throw new ValidationError('Invalid deadline time format (use HH:mm)');
    }

    // Validate reminder time format if provided
    if (reminderTime && !/^([01]\d|2[0-3]):([0-5]\d)$/.test(reminderTime)) {
      throw new ValidationError('Invalid reminder time format (use HH:mm)');
    }

    // Parse start date
    const start = startDate ? new Date(startDate) : new Date();
    if (isNaN(start.getTime())) {
      throw new ValidationError('Invalid start date');
    }

    // Parse end date if provided
    let end: Date | null = null;
    if (endDate) {
      end = new Date(endDate);
      if (isNaN(end.getTime())) {
        throw new ValidationError('Invalid end date');
      }
      if (end <= start) {
        throw new ValidationError('End date must be after start date');
      }
    }

    const goal = await prisma.goal.create({
      data: {
        podId,
        userId: req.user!.id,
        title: title.trim(),
        description: description?.trim() || null,
        frequencyType: freq,
        frequencyDays: days,
        reminderTime: reminderTime || null,
        deadlineTime: deadline,
        timezone: tz,
        requiresProof: requiresProof || false,
        startDate: start,
        endDate: end,
      },
      include: {
        pod: {
          select: { id: true, name: true },
        },
      },
    });

    res.status(201).json({
      success: true,
      data: {
        id: goal.id,
        podId: goal.podId,
        podName: goal.pod.name,
        title: goal.title,
        description: goal.description,
        frequencyType: goal.frequencyType,
        frequencyDays: goal.frequencyDays,
        reminderTime: goal.reminderTime,
        deadlineTime: goal.deadlineTime,
        timezone: goal.timezone,
        requiresProof: goal.requiresProof,
        startDate: goal.startDate,
        endDate: goal.endDate,
        currentStreak: goal.currentStreak,
        longestStreak: goal.longestStreak,
        createdAt: goal.createdAt,
      },
    });
  } catch (error) {
    if (error instanceof ValidationError || error instanceof ForbiddenError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Create goal error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create goal' },
    });
  }
});

// GET /goals/:goalId - Get goal details
router.get('/:goalId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { goalId } = req.params;

    const goal = await prisma.goal.findUnique({
      where: { id: goalId },
      include: {
        pod: {
          select: { id: true, name: true },
        },
        checkIns: {
          orderBy: { date: 'desc' },
          take: 30, // Last 30 check-ins
        },
      },
    });

    if (!goal) {
      throw new NotFoundError('Goal not found');
    }

    // Verify user has access (is goal owner or pod member)
    if (goal.userId !== req.user!.id) {
      const membership = await prisma.podMember.findUnique({
        where: {
          podId_userId: { podId: goal.podId, userId: req.user!.id },
        },
      });

      if (!membership || membership.status !== 'ACTIVE') {
        throw new ForbiddenError('You do not have access to this goal');
      }
    }

    res.json({
      success: true,
      data: {
        id: goal.id,
        podId: goal.podId,
        podName: goal.pod.name,
        userId: goal.userId,
        title: goal.title,
        description: goal.description,
        frequencyType: goal.frequencyType,
        frequencyDays: goal.frequencyDays,
        reminderTime: goal.reminderTime,
        deadlineTime: goal.deadlineTime,
        timezone: goal.timezone,
        requiresProof: goal.requiresProof,
        startDate: goal.startDate,
        endDate: goal.endDate,
        currentStreak: goal.currentStreak,
        longestStreak: goal.longestStreak,
        isArchived: goal.isArchived,
        createdAt: goal.createdAt,
        checkIns: goal.checkIns.map((c) => ({
          id: c.id,
          date: c.date,
          status: c.status,
          proofUrl: c.proofUrl,
          comment: c.comment,
          createdAt: c.createdAt,
        })),
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
    console.error('Get goal error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get goal' },
    });
  }
});

// PATCH /goals/:goalId - Update goal
router.patch('/:goalId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { goalId } = req.params;
    const { title, description, reminderTime, deadlineTime, requiresProof, endDate, isArchived } = req.body;

    const goal = await prisma.goal.findUnique({
      where: { id: goalId },
    });

    if (!goal) {
      throw new NotFoundError('Goal not found');
    }

    if (goal.userId !== req.user!.id) {
      throw new ForbiddenError('Only the goal owner can update it');
    }

    const updates: Record<string, unknown> = {};

    if (title !== undefined) {
      if (typeof title !== 'string' || title.trim().length === 0) {
        throw new ValidationError('Title cannot be empty');
      }
      if (title.length > 100) {
        throw new ValidationError('Title must be 100 characters or less');
      }
      updates.title = title.trim();
    }

    if (description !== undefined) {
      updates.description = description?.trim() || null;
    }

    if (reminderTime !== undefined) {
      if (reminderTime && !/^([01]\d|2[0-3]):([0-5]\d)$/.test(reminderTime)) {
        throw new ValidationError('Invalid reminder time format');
      }
      updates.reminderTime = reminderTime || null;
    }

    if (deadlineTime !== undefined) {
      if (!/^([01]\d|2[0-3]):([0-5]\d)$/.test(deadlineTime)) {
        throw new ValidationError('Invalid deadline time format');
      }
      updates.deadlineTime = deadlineTime;
    }

    if (requiresProof !== undefined) {
      updates.requiresProof = Boolean(requiresProof);
    }

    if (endDate !== undefined) {
      if (endDate === null) {
        updates.endDate = null;
      } else {
        const end = new Date(endDate);
        if (isNaN(end.getTime())) {
          throw new ValidationError('Invalid end date');
        }
        updates.endDate = end;
      }
    }

    if (isArchived !== undefined) {
      updates.isArchived = Boolean(isArchived);
    }

    const updated = await prisma.goal.update({
      where: { id: goalId },
      data: updates,
      include: {
        pod: {
          select: { id: true, name: true },
        },
      },
    });

    res.json({
      success: true,
      data: {
        id: updated.id,
        podId: updated.podId,
        podName: updated.pod.name,
        title: updated.title,
        description: updated.description,
        frequencyType: updated.frequencyType,
        frequencyDays: updated.frequencyDays,
        reminderTime: updated.reminderTime,
        deadlineTime: updated.deadlineTime,
        timezone: updated.timezone,
        requiresProof: updated.requiresProof,
        startDate: updated.startDate,
        endDate: updated.endDate,
        currentStreak: updated.currentStreak,
        longestStreak: updated.longestStreak,
        isArchived: updated.isArchived,
        createdAt: updated.createdAt,
      },
    });
  } catch (error) {
    if (
      error instanceof ValidationError ||
      error instanceof NotFoundError ||
      error instanceof ForbiddenError
    ) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Update goal error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update goal' },
    });
  }
});

// GET /pods/:podId/goals - List goals in a pod (for all members to see)
router.get('/pod/:podId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId } = req.params;

    // Verify user is a member
    const membership = await prisma.podMember.findUnique({
      where: {
        podId_userId: { podId, userId: req.user!.id },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    const goals = await prisma.goal.findMany({
      where: {
        podId,
        isArchived: false,
      },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
        _count: {
          select: { checkIns: { where: { status: 'COMPLETED' } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({
      success: true,
      data: goals.map((g) => ({
        id: g.id,
        userId: g.userId,
        userName: g.user.name,
        userAvatarUrl: g.user.avatarUrl,
        title: g.title,
        description: g.description,
        frequencyType: g.frequencyType,
        currentStreak: g.currentStreak,
        longestStreak: g.longestStreak,
        completedCheckIns: g._count.checkIns,
        createdAt: g.createdAt,
      })),
    });
  } catch (error) {
    if (error instanceof ForbiddenError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('List pod goals error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list pod goals' },
    });
  }
});

export default router;
