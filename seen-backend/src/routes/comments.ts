import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { ValidationError, ForbiddenError, NotFoundError } from '../lib/errors';
import { sendPush } from '../lib/push';
import { MediaType } from '@prisma/client';

const router = Router();

router.use(authMiddleware);

// GET /goals/:goalId/comments - Get comments for a goal
router.get('/:goalId/comments', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { goalId } = req.params;
    const userId = req.user!.id;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const cursor = req.query.cursor as string | undefined;

    // Get the goal and verify membership in the pod
    const goal = await prisma.goal.findUnique({
      where: { id: goalId },
      include: { pod: true },
    });

    if (!goal) {
      throw new NotFoundError('Goal not found');
    }

    // Verify user is in the pod
    const membership = await prisma.podMember.findUnique({
      where: { podId_userId: { podId: goal.podId, userId } },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    const comments = await prisma.goalComment.findMany({
      where: { goalId },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
      },
      orderBy: { createdAt: 'asc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = comments.length > limit;
    const resultComments = hasMore ? comments.slice(0, limit) : comments;
    const nextCursor = hasMore ? resultComments[resultComments.length - 1].id : null;

    res.json({
      success: true,
      data: {
        comments: resultComments.map((comment) => ({
          id: comment.id,
          content: comment.content,
          mediaUrl: comment.mediaUrl,
          mediaType: comment.mediaType,
          author: {
            id: comment.user.id,
            name: comment.user.name,
            avatarUrl: comment.user.avatarUrl,
          },
          createdAt: comment.createdAt,
        })),
        nextCursor,
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
    console.error('Get goal comments error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get comments' },
    });
  }
});

// POST /goals/:goalId/comments - Add a comment to a goal
router.post('/:goalId/comments', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { goalId } = req.params;
    const userId = req.user!.id;
    const { content, mediaUrl, mediaType } = req.body;

    // Get the goal and verify membership
    const goal = await prisma.goal.findUnique({
      where: { id: goalId },
      include: {
        pod: { select: { name: true } },
        user: { select: { id: true, name: true } },
      },
    });

    if (!goal) {
      throw new NotFoundError('Goal not found');
    }

    // Verify user is in the pod
    const membership = await prisma.podMember.findUnique({
      where: { podId_userId: { podId: goal.podId, userId } },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    // Validate content or media
    if (!content && !mediaUrl) {
      throw new ValidationError('Comment must have content or media');
    }

    // Validate media type
    if (mediaType && !['PHOTO', 'VIDEO', 'AUDIO'].includes(mediaType)) {
      throw new ValidationError('Invalid media type');
    }

    // Get commenter info
    const commenter = await prisma.user.findUnique({
      where: { id: userId },
      select: { name: true },
    });

    const comment = await prisma.goalComment.create({
      data: {
        goalId,
        userId,
        content: content?.trim() || null,
        mediaUrl: mediaUrl || null,
        mediaType: mediaType as MediaType || null,
      },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
      },
    });

    // Send push notification to goal owner (if not the commenter)
    if (goal.userId !== userId) {
      const deviceTokens = await prisma.deviceToken.findMany({
        where: { userId: goal.userId },
      });

      const hasMedia = mediaUrl ? ` ${mediaType === 'VIDEO' ? '🎥' : mediaType === 'AUDIO' ? '🎤' : '📸'}` : '';

      for (const dt of deviceTokens) {
        await sendPush(dt.token, {
          title: goal.pod.name,
          body: `${commenter?.name || 'Someone'} commented on "${goal.title}"${hasMedia}`,
          data: { goalId, commentId: comment.id, type: 'GOAL_COMMENT' },
        });
      }
    }

    res.status(201).json({
      success: true,
      data: {
        id: comment.id,
        content: comment.content,
        mediaUrl: comment.mediaUrl,
        mediaType: comment.mediaType,
        author: {
          id: comment.user.id,
          name: comment.user.name,
          avatarUrl: comment.user.avatarUrl,
        },
        createdAt: comment.createdAt,
      },
    });
  } catch (error) {
    if (
      error instanceof ForbiddenError ||
      error instanceof NotFoundError ||
      error instanceof ValidationError
    ) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Create goal comment error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create comment' },
    });
  }
});

// DELETE /goals/:goalId/comments/:commentId - Delete a comment
router.delete('/:goalId/comments/:commentId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { goalId, commentId } = req.params;
    const userId = req.user!.id;

    // Get the comment
    const comment = await prisma.goalComment.findUnique({
      where: { id: commentId },
      include: { goal: { select: { podId: true } } },
    });

    if (!comment) {
      throw new NotFoundError('Comment not found');
    }

    if (comment.goalId !== goalId) {
      throw new NotFoundError('Comment not found');
    }

    // Only the comment author can delete
    if (comment.userId !== userId) {
      throw new ForbiddenError('You can only delete your own comments');
    }

    await prisma.goalComment.delete({
      where: { id: commentId },
    });

    res.json({
      success: true,
      data: { message: 'Comment deleted' },
    });
  } catch (error) {
    if (error instanceof ForbiddenError || error instanceof NotFoundError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Delete comment error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to delete comment' },
    });
  }
});

export default router;
