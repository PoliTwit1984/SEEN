import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { generateInviteCode } from '../lib/inviteCode';
import { ValidationError, NotFoundError, ConflictError, ForbiddenError } from '../lib/errors';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

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
