import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';

const router = Router();

router.use(authMiddleware);

// GET /feed - Get activity feed for user's pods
router.get('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { limit = '20', offset = '0' } = req.query;
    const take = Math.min(parseInt(limit as string), 50);
    const skip = parseInt(offset as string);

    // Get all pods the user is a member of
    const memberships = await prisma.podMember.findMany({
      where: {
        userId: req.user!.id,
        status: 'ACTIVE',
      },
      select: { podId: true },
    });

    const podIds = memberships.map((m) => m.podId);

    if (podIds.length === 0) {
      res.json({ success: true, data: [] });
      return;
    }

    // Get recent check-ins from those pods
    const checkIns = await prisma.checkIn.findMany({
      where: {
        goal: {
          podId: { in: podIds },
          isArchived: false,
        },
        status: 'COMPLETED', // Only show completed check-ins in feed
      },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
        goal: {
          select: {
            id: true,
            title: true,
            podId: true,
            pod: {
              select: { id: true, name: true },
            },
          },
        },
        interactions: {
          include: {
            user: {
              select: { id: true, name: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take,
      skip,
    });

    const feedItems = checkIns.map((c) => ({
      id: c.id,
      type: 'check_in',
      user: {
        id: c.user.id,
        name: c.user.name,
        avatarUrl: c.user.avatarUrl,
      },
      goal: {
        id: c.goal.id,
        title: c.goal.title,
      },
      pod: {
        id: c.goal.pod.id,
        name: c.goal.pod.name,
      },
      checkIn: {
        date: c.date,
        status: c.status,
        proofUrl: c.proofUrl,
        comment: c.comment,
      },
      interactions: c.interactions.map((i) => ({
        id: i.id,
        type: i.type,
        userId: i.user.id,
        userName: i.user.name,
      })),
      interactionCount: c.interactions.length,
      hasInteracted: c.interactions.some((i) => i.userId === req.user!.id),
      myInteractionType: c.interactions.find((i) => i.userId === req.user!.id)?.type || null,
      createdAt: c.createdAt,
    }));

    res.json({
      success: true,
      data: feedItems,
    });
  } catch (error) {
    console.error('Get feed error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get feed' },
    });
  }
});

// GET /feed/pod/:podId - Get feed for a specific pod
router.get('/pod/:podId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId } = req.params;
    const { limit = '20', offset = '0' } = req.query;
    const take = Math.min(parseInt(limit as string), 50);
    const skip = parseInt(offset as string);

    // Verify user is a member
    const membership = await prisma.podMember.findUnique({
      where: {
        podId_userId: { podId, userId: req.user!.id },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: 'You are not a member of this pod' },
      });
      return;
    }

    const checkIns = await prisma.checkIn.findMany({
      where: {
        goal: {
          podId,
          isArchived: false,
        },
        status: 'COMPLETED',
      },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
        goal: {
          select: { id: true, title: true },
        },
        interactions: {
          include: {
            user: {
              select: { id: true, name: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take,
      skip,
    });

    const feedItems = checkIns.map((c) => ({
      id: c.id,
      type: 'check_in',
      user: {
        id: c.user.id,
        name: c.user.name,
        avatarUrl: c.user.avatarUrl,
      },
      goal: {
        id: c.goal.id,
        title: c.goal.title,
      },
      checkIn: {
        date: c.date,
        status: c.status,
        proofUrl: c.proofUrl,
        comment: c.comment,
      },
      interactions: c.interactions.map((i) => ({
        id: i.id,
        type: i.type,
        userId: i.user.id,
        userName: i.user.name,
      })),
      interactionCount: c.interactions.length,
      hasInteracted: c.interactions.some((i) => i.userId === req.user!.id),
      myInteractionType: c.interactions.find((i) => i.userId === req.user!.id)?.type || null,
      createdAt: c.createdAt,
    }));

    res.json({
      success: true,
      data: feedItems,
    });
  } catch (error) {
    console.error('Get pod feed error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get pod feed' },
    });
  }
});

export default router;
