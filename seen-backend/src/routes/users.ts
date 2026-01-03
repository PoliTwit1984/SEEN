import { Router, Response } from 'express';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { prisma } from '../lib/prisma';

const router = Router();

// GET /users/me
router.get('/me', authMiddleware, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: {
        id: true,
        email: true,
        name: true,
        avatarUrl: true,
        timezone: true,
        createdAt: true,
      },
    });

    if (!user) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'User not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: user,
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get user' },
    });
  }
});

// GET /users/me/stats - Get aggregated user statistics
router.get('/me/stats', authMiddleware, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user!.id;

    // Get all user's goals with their stats
    const goals = await prisma.goal.findMany({
      where: {
        userId,
        isArchived: false,
      },
      select: {
        currentStreak: true,
        longestStreak: true,
        _count: {
          select: { checkIns: true },
        },
      },
    });

    // Get total completed check-ins
    const totalCheckIns = await prisma.checkIn.count({
      where: {
        userId,
        status: 'COMPLETED',
      },
    });

    // Calculate current streak (max of all active goals)
    const currentStreak = goals.length > 0
      ? Math.max(...goals.map((g) => g.currentStreak))
      : 0;

    // Calculate longest streak (max ever achieved)
    const longestStreak = goals.length > 0
      ? Math.max(...goals.map((g) => g.longestStreak))
      : 0;

    // Get pods count
    const podsCount = await prisma.podMember.count({
      where: {
        userId,
        status: 'ACTIVE',
      },
    });

    // Get member since date
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { createdAt: true },
    });

    res.json({
      success: true,
      data: {
        currentStreak,
        longestStreak,
        totalCheckIns,
        activeGoals: goals.length,
        podsCount,
        memberSince: user?.createdAt,
      },
    });
  } catch (error) {
    console.error('Get user stats error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get user stats' },
    });
  }
});

// PATCH /users/me
router.patch('/me', authMiddleware, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { name, timezone, avatarUrl } = req.body;

    const updateData: { name?: string; timezone?: string; avatarUrl?: string } = {};
    if (name) updateData.name = name;
    if (timezone) updateData.timezone = timezone;
    if (avatarUrl !== undefined) updateData.avatarUrl = avatarUrl;

    const user = await prisma.user.update({
      where: { id: req.user!.id },
      data: updateData,
      select: {
        id: true,
        email: true,
        name: true,
        avatarUrl: true,
        timezone: true,
        createdAt: true,
      },
    });

    res.json({
      success: true,
      data: user,
    });
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update user' },
    });
  }
});

export default router;
