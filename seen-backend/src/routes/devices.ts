import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { ValidationError } from '../lib/errors';

const router = Router();

router.use(authMiddleware);

// POST /devices - Register a device token
router.post('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { token, platform } = req.body;

    if (!token || typeof token !== 'string') {
      throw new ValidationError('Device token is required');
    }

    const devicePlatform = platform || 'ios';
    if (!['ios', 'android'].includes(devicePlatform)) {
      throw new ValidationError('Platform must be ios or android');
    }

    // Check if token already exists
    const existing = await prisma.deviceToken.findUnique({
      where: { token },
    });

    if (existing) {
      // Update to current user if different
      if (existing.userId !== req.user!.id) {
        await prisma.deviceToken.update({
          where: { id: existing.id },
          data: { userId: req.user!.id },
        });
      }
      
      res.json({
        success: true,
        data: { message: 'Device token registered' },
      });
      return;
    }

    // Create new token
    await prisma.deviceToken.create({
      data: {
        userId: req.user!.id,
        token,
        platform: devicePlatform,
      },
    });

    res.status(201).json({
      success: true,
      data: { message: 'Device token registered' },
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Register device error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to register device' },
    });
  }
});

// DELETE /devices/:token - Unregister a device token
router.delete('/:token', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { token } = req.params;

    await prisma.deviceToken.deleteMany({
      where: {
        token,
        userId: req.user!.id,
      },
    });

    res.json({
      success: true,
      data: { message: 'Device token unregistered' },
    });
  } catch (error) {
    console.error('Unregister device error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to unregister device' },
    });
  }
});

export default router;
