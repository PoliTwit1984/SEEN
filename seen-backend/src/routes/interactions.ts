import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { ValidationError, NotFoundError, ForbiddenError } from '../lib/errors';
import { notifyReaction } from '../lib/push';

const router = Router();

router.use(authMiddleware);

// POST /interactions - Add interaction to a check-in
router.post('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { checkInId, type } = req.body;

    if (!checkInId || typeof checkInId !== 'string') {
      throw new ValidationError('Check-in ID is required');
    }

    const validTypes = ['HIGH_FIVE', 'FIRE', 'CLAP', 'HEART'];
    if (!type || !validTypes.includes(type)) {
      throw new ValidationError(`Invalid interaction type. Use: ${validTypes.join(', ')}`);
    }

    // Get the check-in and verify access
    const checkIn = await prisma.checkIn.findUnique({
      where: { id: checkInId },
      include: {
        goal: {
          include: {
            pod: {
              include: {
                members: {
                  where: { userId: req.user!.id, status: 'ACTIVE' },
                },
              },
            },
          },
        },
      },
    });

    if (!checkIn) {
      throw new NotFoundError('Check-in not found');
    }

    // User must be a pod member to interact
    if (checkIn.goal.pod.members.length === 0) {
      throw new ForbiddenError('You must be a pod member to interact');
    }

    // Check if already interacted
    const existing = await prisma.interaction.findUnique({
      where: {
        checkInId_userId: { checkInId, userId: req.user!.id },
      },
    });

    if (existing) {
      // Update existing interaction
      const updated = await prisma.interaction.update({
        where: { id: existing.id },
        data: { type },
        include: {
          user: {
            select: { id: true, name: true },
          },
        },
      });

      res.json({
        success: true,
        data: {
          id: updated.id,
          checkInId: updated.checkInId,
          type: updated.type,
          user: updated.user,
          createdAt: updated.createdAt,
        },
      });
      return;
    }

    // Create new interaction
    const interaction = await prisma.interaction.create({
      data: {
        checkInId,
        userId: req.user!.id,
        type,
      },
      include: {
        user: {
          select: { id: true, name: true },
        },
      },
    });

    // Send push notification (don't notify yourself)
    if (checkIn.userId !== req.user!.id) {
      const emoji = type === 'HIGH_FIVE' ? '🙌' : type === 'FIRE' ? '🔥' : type === 'CLAP' ? '👏' : '❤️';
      notifyReaction(
        checkIn.userId,
        req.user!.name,
        emoji,
        checkIn.goal.title,
        checkInId
      ).catch((err) => console.error('Push notification error:', err));
    }

    res.status(201).json({
      success: true,
      data: {
        id: interaction.id,
        checkInId: interaction.checkInId,
        type: interaction.type,
        user: interaction.user,
        createdAt: interaction.createdAt,
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
    console.error('Add interaction error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to add interaction' },
    });
  }
});

// DELETE /interactions/:checkInId - Remove interaction from a check-in
router.delete('/:checkInId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { checkInId } = req.params;

    const interaction = await prisma.interaction.findUnique({
      where: {
        checkInId_userId: { checkInId, userId: req.user!.id },
      },
    });

    if (!interaction) {
      throw new NotFoundError('Interaction not found');
    }

    await prisma.interaction.delete({
      where: { id: interaction.id },
    });

    res.json({
      success: true,
      data: { message: 'Interaction removed' },
    });
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Remove interaction error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to remove interaction' },
    });
  }
});

// GET /interactions/:checkInId - Get interactions for a check-in
router.get('/:checkInId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { checkInId } = req.params;

    const interactions = await prisma.interaction.findMany({
      where: { checkInId },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    res.json({
      success: true,
      data: interactions.map((i) => ({
        id: i.id,
        type: i.type,
        user: i.user,
        createdAt: i.createdAt,
      })),
    });
  } catch (error) {
    console.error('Get interactions error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get interactions' },
    });
  }
});

export default router;
