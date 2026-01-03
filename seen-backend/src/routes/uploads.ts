import { Router, Response } from 'express';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { generateUploadUrl, generateAvatarUploadUrl, isStorageConfigured } from '../lib/storage';
import { ValidationError } from '../lib/errors';
import { prisma } from '../lib/prisma';

const router = Router();

router.use(authMiddleware);

// POST /uploads/presign - Get a presigned URL for uploading a photo
router.post('/presign', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { goalId, fileType } = req.body;

    if (!goalId || typeof goalId !== 'string') {
      throw new ValidationError('Goal ID is required');
    }

    // Validate file type
    const validTypes = ['jpg', 'jpeg', 'png', 'heic'];
    const extension = (fileType || 'jpg').toLowerCase();
    if (!validTypes.includes(extension)) {
      throw new ValidationError(`Invalid file type. Use: ${validTypes.join(', ')}`);
    }

    // Verify user owns or is a member of the goal's pod
    const goal = await prisma.goal.findUnique({
      where: { id: goalId },
      select: { userId: true, podId: true },
    });

    if (!goal) {
      throw new ValidationError('Goal not found');
    }

    if (goal.userId !== req.user!.id) {
      const membership = await prisma.podMember.findUnique({
        where: {
          podId_userId: { podId: goal.podId, userId: req.user!.id },
        },
      });
      if (!membership || membership.status !== 'ACTIVE') {
        throw new ValidationError('Not authorized to upload for this goal');
      }
    }

    // Check if storage is configured
    if (!isStorageConfigured()) {
      // Return a mock URL for development
      res.json({
        success: true,
        data: {
          uploadUrl: 'https://mock-upload.example.com/upload',
          publicUrl: `https://mock-photos.example.com/proofs/${req.user!.id}/${goalId}/${Date.now()}.${extension}`,
          key: `proofs/${req.user!.id}/${goalId}/${Date.now()}.${extension}`,
          configured: false,
        },
      });
      return;
    }

    const result = await generateUploadUrl(req.user!.id, goalId, extension);

    res.json({
      success: true,
      data: {
        ...result,
        configured: true,
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
    console.error('Generate presigned URL error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to generate upload URL' },
    });
  }
});

// POST /uploads/avatar/presign - Get a presigned URL for uploading an avatar
router.post('/avatar/presign', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { fileType } = req.body;

    // Validate file type
    const validTypes = ['jpg', 'jpeg', 'png', 'heic'];
    const extension = (fileType || 'jpg').toLowerCase();
    if (!validTypes.includes(extension)) {
      throw new ValidationError(`Invalid file type. Use: ${validTypes.join(', ')}`);
    }

    // Check if storage is configured
    if (!isStorageConfigured()) {
      // Return a mock URL for development
      res.json({
        success: true,
        data: {
          uploadUrl: 'https://mock-upload.example.com/upload',
          publicUrl: `https://mock-photos.example.com/avatars/${req.user!.id}/${Date.now()}.${extension}`,
          key: `avatars/${req.user!.id}/${Date.now()}.${extension}`,
          configured: false,
        },
      });
      return;
    }

    const result = await generateAvatarUploadUrl(req.user!.id, extension);

    res.json({
      success: true,
      data: {
        ...result,
        configured: true,
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
    console.error('Generate avatar presigned URL error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to generate upload URL' },
    });
  }
});

export default router;
