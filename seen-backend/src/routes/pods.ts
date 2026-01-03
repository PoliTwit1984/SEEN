import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { generateInviteCode } from '../lib/inviteCode';
import { ValidationError, NotFoundError, ConflictError, ForbiddenError } from '../lib/errors';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// GET /pods/with-status - List pods with activity indicators for visual feed
router.get('/with-status', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user!.id;

    // Get all pods the user is a member of
    const memberships = await prisma.podMember.findMany({
      where: {
        userId,
        status: 'ACTIVE',
      },
      include: {
        pod: {
          include: {
            _count: {
              select: { members: { where: { status: 'ACTIVE' } } },
            },
          },
        },
      },
      orderBy: { joinedAt: 'desc' },
    });

    // Get last viewed timestamps for all pods
    const podIds = memberships.map((m) => m.podId);
    const podViews = await prisma.podView.findMany({
      where: {
        userId,
        podId: { in: podIds },
      },
    });
    const viewMap = new Map(podViews.map((v) => [v.podId, v.viewedAt]));

    // Get today's date for pending goals calculation
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // For each pod, calculate activity status
    const podsWithStatus = await Promise.all(
      memberships.map(async (m) => {
        const lastViewed = viewMap.get(m.podId) || new Date(0);

        // Get check-ins since last viewed (new activity)
        const newCheckIns = await prisma.checkIn.findMany({
          where: {
            goal: {
              podId: m.podId,
              isArchived: false,
            },
            status: 'COMPLETED',
            createdAt: { gt: lastViewed },
          },
          include: {
            user: { select: { id: true } },
          },
          orderBy: { createdAt: 'desc' },
          take: 20,
        });

        // Filter out user's own check-ins for "new activity" indicator
        const otherUserCheckIns = newCheckIns.filter((c) => c.userId !== userId);

        // Get latest check-in photo from the pod (any user)
        const latestWithPhoto = await prisma.checkIn.findFirst({
          where: {
            goal: {
              podId: m.podId,
              isArchived: false,
            },
            status: 'COMPLETED',
            proofUrl: { not: null },
          },
          orderBy: { createdAt: 'desc' },
          select: { proofUrl: true },
        });

        // Count user's goals that are due today in this pod
        const pendingGoals = await prisma.goal.count({
          where: {
            podId: m.podId,
            userId,
            isArchived: false,
            checkIns: {
              none: {
                date: todayStart,
                status: 'COMPLETED',
              },
            },
          },
        });

        return {
          id: m.pod.id,
          name: m.pod.name,
          memberCount: m.pod._count.members,
          maxMembers: m.pod.maxMembers,
          hasNewActivity: otherUserCheckIns.length > 0,
          latestCheckInPhoto: latestWithPhoto?.proofUrl || null,
          unreadCount: otherUserCheckIns.length,
          myPendingGoals: pendingGoals,
        };
      })
    );

    res.json({
      success: true,
      data: podsWithStatus,
    });
  } catch (error) {
    console.error('Get pods with status error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get pods with status' },
    });
  }
});

// GET /pods/:podId/dashboard - Get pod dashboard with health, member statuses, needs encouragement
router.get('/:podId/dashboard', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId } = req.params;
    const userId = req.user!.id;

    // Verify membership
    const membership = await prisma.podMember.findUnique({
      where: { podId_userId: { podId, userId } },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    // Get pod with active members
    const pod = await prisma.pod.findUnique({
      where: { id: podId },
      include: {
        members: {
          where: { status: 'ACTIVE' },
          include: {
            user: {
              select: { id: true, name: true, avatarUrl: true },
            },
          },
        },
      },
    });

    if (!pod) {
      throw new NotFoundError('Pod not found');
    }

    // Get today's date for status calculation
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // Get all member statuses
    const memberStatuses = await Promise.all(
      pod.members.map(async (member) => {
        // Get member's active goals in this pod
        const goals = await prisma.goal.findMany({
          where: {
            podId,
            userId: member.userId,
            isArchived: false,
          },
          include: {
            checkIns: {
              where: { date: todayStart },
              take: 1,
            },
          },
        });

        // Calculate today's status
        const totalGoals = goals.length;
        const completedToday = goals.filter(
          (g) => g.checkIns.some((c) => c.status === 'COMPLETED')
        ).length;
        const missedToday = goals.filter(
          (g) => g.checkIns.some((c) => c.status === 'MISSED')
        ).length;

        // Calculate pending (goals due today without check-in)
        const pendingToday = totalGoals - completedToday - missedToday;

        // Get longest active streak
        const currentStreak = goals.length > 0
          ? Math.max(...goals.map((g) => g.currentStreak))
          : 0;

        // Determine status
        let todayStatus: 'completed' | 'pending' | 'missed' | 'no_goals' = 'no_goals';
        if (totalGoals === 0) {
          todayStatus = 'no_goals';
        } else if (completedToday === totalGoals) {
          todayStatus = 'completed';
        } else if (missedToday > 0) {
          todayStatus = 'missed';
        } else {
          todayStatus = 'pending';
        }

        return {
          userId: member.user.id,
          name: member.user.name,
          avatarUrl: member.user.avatarUrl,
          todayStatus,
          currentStreak,
          totalGoals,
          completedToday,
          pendingToday,
          isCurrentUser: member.userId === userId,
        };
      })
    );

    // Calculate pod health
    const membersWithGoals = memberStatuses.filter((m) => m.totalGoals > 0);
    const membersCompleted = memberStatuses.filter((m) => m.todayStatus === 'completed').length;
    const membersPending = memberStatuses.filter((m) => m.todayStatus === 'pending').length;
    const membersMissed = memberStatuses.filter((m) => m.todayStatus === 'missed').length;

    // Identify members who need encouragement (pending or missed)
    const needsEncouragement = memberStatuses
      .filter((m) => m.todayStatus === 'pending' || m.todayStatus === 'missed')
      .filter((m) => !m.isCurrentUser) // Exclude current user
      .map((m) => ({
        userId: m.userId,
        name: m.name,
        avatarUrl: m.avatarUrl,
        status: m.todayStatus,
        pendingGoals: m.pendingToday,
      }));

    res.json({
      success: true,
      data: {
        pod: {
          id: pod.id,
          name: pod.name,
          description: pod.description,
          stakes: pod.stakes,
          inviteCode: pod.inviteCode,
        },
        health: {
          totalMembers: pod.members.length,
          membersWithGoals: membersWithGoals.length,
          completedToday: membersCompleted,
          pendingToday: membersPending,
          missedToday: membersMissed,
        },
        memberStatuses,
        needsEncouragement,
      },
    });
  } catch (error) {
    if (error instanceof ForbiddenError || error instanceof NotFoundError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Get pod dashboard error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get pod dashboard' },
    });
  }
});

// GET /pods/:podId/members/status - Get member statuses for a pod
router.get('/:podId/members/status', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId } = req.params;
    const userId = req.user!.id;

    // Verify membership
    const membership = await prisma.podMember.findUnique({
      where: { podId_userId: { podId, userId } },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    // Get active members
    const members = await prisma.podMember.findMany({
      where: { podId, status: 'ACTIVE' },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
      },
    });

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const statuses = await Promise.all(
      members.map(async (member) => {
        const goals = await prisma.goal.findMany({
          where: {
            podId,
            userId: member.userId,
            isArchived: false,
          },
          include: {
            checkIns: {
              where: { date: todayStart },
              orderBy: { createdAt: 'desc' },
              take: 1,
            },
          },
        });

        const totalGoals = goals.length;
        const completedToday = goals.filter(
          (g) => g.checkIns.some((c) => c.status === 'COMPLETED')
        ).length;
        const currentStreak = goals.length > 0
          ? Math.max(...goals.map((g) => g.currentStreak))
          : 0;

        // Get today's status
        let todayStatus: 'completed' | 'pending' | 'missed' | 'no_goals' = 'no_goals';
        if (totalGoals === 0) {
          todayStatus = 'no_goals';
        } else if (completedToday === totalGoals) {
          todayStatus = 'completed';
        } else {
          todayStatus = 'pending';
        }

        // Get pending goals (goals without completed check-in today)
        const pendingGoals = goals.filter(
          (g) => !g.checkIns.some((c) => c.status === 'COMPLETED')
        ).map((g) => ({
          id: g.id,
          title: g.title,
        }));

        return {
          userId: member.user.id,
          name: member.user.name,
          avatarUrl: member.user.avatarUrl,
          todayStatus,
          currentStreak,
          pendingGoals,
        };
      })
    );

    res.json({
      success: true,
      data: statuses,
    });
  } catch (error) {
    if (error instanceof ForbiddenError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Get member statuses error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get member statuses' },
    });
  }
});

// POST /pods/:podId/view - Mark pod as viewed (for clearing activity indicator)
router.post('/:podId/view', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId } = req.params;
    const userId = req.user!.id;

    // Verify user is a member
    const membership = await prisma.podMember.findUnique({
      where: {
        podId_userId: { podId, userId },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    // Upsert the pod view
    await prisma.podView.upsert({
      where: {
        podId_userId: { podId, userId },
      },
      update: {
        viewedAt: new Date(),
      },
      create: {
        podId,
        userId,
        viewedAt: new Date(),
      },
    });

    res.json({
      success: true,
      data: { message: 'Pod marked as viewed' },
    });
  } catch (error) {
    if (error instanceof ForbiddenError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Mark pod viewed error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to mark pod as viewed' },
    });
  }
});

// GET /pods - List user's pods
router.get('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const memberships = await prisma.podMember.findMany({
      where: {
        userId: req.user!.id,
        status: 'ACTIVE',
      },
      include: {
        pod: {
          include: {
            _count: {
              select: { members: { where: { status: 'ACTIVE' } } },
            },
          },
        },
      },
      orderBy: { joinedAt: 'desc' },
    });

    const pods = memberships.map((m) => ({
      id: m.pod.id,
      name: m.pod.name,
      description: m.pod.description,
      stakes: m.pod.stakes,
      memberCount: m.pod._count.members,
      maxMembers: m.pod.maxMembers,
      role: m.role,
      joinedAt: m.joinedAt,
      createdAt: m.pod.createdAt,
    }));

    res.json({
      success: true,
      data: pods,
    });
  } catch (error) {
    console.error('List pods error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list pods' },
    });
  }
});

// POST /pods - Create a new pod
router.post('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { name, description, stakes, maxMembers } = req.body;

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      throw new ValidationError('Pod name is required');
    }

    if (name.length > 50) {
      throw new ValidationError('Pod name must be 50 characters or less');
    }

    if (description && description.length > 200) {
      throw new ValidationError('Description must be 200 characters or less');
    }

    if (stakes && stakes.length > 100) {
      throw new ValidationError('Stakes must be 100 characters or less');
    }

    const memberLimit = maxMembers ? Math.min(Math.max(2, maxMembers), 10) : 8;

    const inviteCode = await generateInviteCode();

    const pod = await prisma.pod.create({
      data: {
        name: name.trim(),
        description: description?.trim() || null,
        stakes: stakes?.trim() || null,
        maxMembers: memberLimit,
        ownerId: req.user!.id,
        inviteCode,
        members: {
          create: {
            userId: req.user!.id,
            role: 'OWNER',
            status: 'ACTIVE',
          },
        },
      },
      include: {
        _count: {
          select: { members: { where: { status: 'ACTIVE' } } },
        },
      },
    });

    res.status(201).json({
      success: true,
      data: {
        id: pod.id,
        name: pod.name,
        description: pod.description,
        stakes: pod.stakes,
        maxMembers: pod.maxMembers,
        inviteCode: pod.inviteCode,
        memberCount: pod._count.members,
        createdAt: pod.createdAt,
      },
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Create pod error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create pod' },
    });
  }
});

// GET /pods/:podId - Get pod details
router.get('/:podId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId } = req.params;

    // Check if user is a member
    const membership = await prisma.podMember.findUnique({
      where: {
        podId_userId: { podId, userId: req.user!.id },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    const pod = await prisma.pod.findUnique({
      where: { id: podId },
      include: {
        members: {
          where: { status: 'ACTIVE' },
          include: {
            user: {
              select: { id: true, name: true, avatarUrl: true },
            },
          },
          orderBy: { joinedAt: 'asc' },
        },
      },
    });

    if (!pod) {
      throw new NotFoundError('Pod not found');
    }

    res.json({
      success: true,
      data: {
        id: pod.id,
        name: pod.name,
        description: pod.description,
        stakes: pod.stakes,
        maxMembers: pod.maxMembers,
        inviteCode: pod.inviteCode,
        isPrivate: pod.isPrivate,
        createdAt: pod.createdAt,
        members: pod.members.map((m) => ({
          id: m.user.id,
          name: m.user.name,
          avatarUrl: m.user.avatarUrl,
          role: m.role,
          joinedAt: m.joinedAt,
        })),
      },
    });
  } catch (error) {
    if (error instanceof ForbiddenError || error instanceof NotFoundError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Get pod error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get pod' },
    });
  }
});

// POST /pods/join - Join a pod via invite code
router.post('/join', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { inviteCode } = req.body;

    if (!inviteCode || typeof inviteCode !== 'string') {
      throw new ValidationError('Invite code is required');
    }

    const code = inviteCode.toUpperCase().trim();

    if (code.length !== 6) {
      throw new ValidationError('Invite code must be 6 characters');
    }

    const pod = await prisma.pod.findUnique({
      where: { inviteCode: code },
      include: {
        _count: {
          select: { members: { where: { status: 'ACTIVE' } } },
        },
      },
    });

    if (!pod) {
      throw new NotFoundError('Invalid invite code');
    }

    // Check if already a member
    const existingMembership = await prisma.podMember.findUnique({
      where: {
        podId_userId: { podId: pod.id, userId: req.user!.id },
      },
    });

    if (existingMembership) {
      if (existingMembership.status === 'ACTIVE') {
        throw new ConflictError('You are already a member of this pod');
      }
      // Reactivate if previously left
      await prisma.podMember.update({
        where: { id: existingMembership.id },
        data: { status: 'ACTIVE', joinedAt: new Date() },
      });
    } else {
      // Check if pod is full
      if (pod._count.members >= pod.maxMembers) {
        throw new ConflictError('This pod is full', 'POD_FULL');
      }

      await prisma.podMember.create({
        data: {
          podId: pod.id,
          userId: req.user!.id,
          role: 'MEMBER',
          status: 'ACTIVE',
        },
      });
    }

    res.json({
      success: true,
      data: {
        id: pod.id,
        name: pod.name,
        description: pod.description,
        stakes: pod.stakes,
      },
    });
  } catch (error) {
    if (
      error instanceof ValidationError ||
      error instanceof NotFoundError ||
      error instanceof ConflictError
    ) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Join pod error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to join pod' },
    });
  }
});

// DELETE /pods/:podId/members/:userId - Leave or remove member
router.delete('/:podId/members/:userId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId, userId } = req.params;

    // Check if requester is a member
    const requesterMembership = await prisma.podMember.findUnique({
      where: {
        podId_userId: { podId, userId: req.user!.id },
      },
    });

    if (!requesterMembership || requesterMembership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    const isOwner = requesterMembership.role === 'OWNER';
    const isSelf = userId === req.user!.id;

    if (!isOwner && !isSelf) {
      throw new ForbiddenError('Only the owner can remove other members');
    }

    // Owner can't leave (must transfer ownership first or delete pod)
    if (isSelf && isOwner) {
      throw new ValidationError('Pod owner cannot leave. Transfer ownership or delete the pod.');
    }

    const targetMembership = await prisma.podMember.findUnique({
      where: {
        podId_userId: { podId, userId },
      },
    });

    if (!targetMembership || targetMembership.status !== 'ACTIVE') {
      throw new NotFoundError('Member not found');
    }

    await prisma.podMember.update({
      where: { id: targetMembership.id },
      data: { status: isSelf ? 'LEFT' : 'KICKED' },
    });

    res.json({
      success: true,
      data: { message: isSelf ? 'Left pod successfully' : 'Member removed successfully' },
    });
  } catch (error) {
    if (
      error instanceof ValidationError ||
      error instanceof ForbiddenError ||
      error instanceof NotFoundError
    ) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Remove member error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to remove member' },
    });
  }
});

export default router;
