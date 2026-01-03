import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { ValidationError, ForbiddenError, NotFoundError } from '../lib/errors';
import { sendPush } from '../lib/push';
import { PostType, MediaType } from '@prisma/client';

const router = Router();

router.use(authMiddleware);

// GET /pods/:podId/posts - Get pod encouragement feed
router.get('/:podId/posts', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId } = req.params;
    const userId = req.user!.id;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const cursor = req.query.cursor as string | undefined;

    // Verify membership
    const membership = await prisma.podMember.findUnique({
      where: { podId_userId: { podId, userId } },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    const posts = await prisma.podPost.findMany({
      where: { podId },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
        target: {
          select: { id: true, name: true, avatarUrl: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = posts.length > limit;
    const resultPosts = hasMore ? posts.slice(0, limit) : posts;
    const nextCursor = hasMore ? resultPosts[resultPosts.length - 1].id : null;

    res.json({
      success: true,
      data: {
        posts: resultPosts.map((post) => ({
          id: post.id,
          type: post.type,
          content: post.content,
          mediaUrl: post.mediaUrl,
          mediaType: post.mediaType,
          author: {
            id: post.user.id,
            name: post.user.name,
            avatarUrl: post.user.avatarUrl,
          },
          target: post.target
            ? {
                id: post.target.id,
                name: post.target.name,
                avatarUrl: post.target.avatarUrl,
              }
            : null,
          createdAt: post.createdAt,
        })),
        nextCursor,
      },
    });
  } catch (error) {
    if (error instanceof ForbiddenError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Get pod posts error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get pod posts' },
    });
  }
});

// POST /pods/:podId/posts - Create encouragement post
router.post('/:podId/posts', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId } = req.params;
    const userId = req.user!.id;
    const { type, content, mediaUrl, mediaType, targetUserId } = req.body;

    // Verify membership
    const membership = await prisma.podMember.findUnique({
      where: { podId_userId: { podId, userId } },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    // Validate type
    if (!type || !['ENCOURAGEMENT', 'NUDGE', 'CELEBRATION'].includes(type)) {
      throw new ValidationError('Invalid post type');
    }

    // Validate media
    if (mediaType && !['PHOTO', 'VIDEO', 'AUDIO'].includes(mediaType)) {
      throw new ValidationError('Invalid media type');
    }

    // Must have content or media
    if (!content && !mediaUrl) {
      throw new ValidationError('Post must have content or media');
    }

    // If targeting a user, verify they're in the pod
    if (targetUserId) {
      const targetMembership = await prisma.podMember.findUnique({
        where: { podId_userId: { podId, userId: targetUserId } },
      });

      if (!targetMembership || targetMembership.status !== 'ACTIVE') {
        throw new ValidationError('Target user is not a member of this pod');
      }
    }

    const post = await prisma.podPost.create({
      data: {
        podId,
        userId,
        type: type as PostType,
        content: content?.trim() || null,
        mediaUrl: mediaUrl || null,
        mediaType: mediaType as MediaType || null,
        targetUserId: targetUserId || null,
      },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
        target: {
          select: { id: true, name: true, avatarUrl: true },
        },
      },
    });

    // Get the pod name
    const pod = await prisma.pod.findUnique({
      where: { id: podId },
      select: { name: true },
    });

    // Send push notification to target (or all pod members for general posts)
    if (targetUserId) {
      // Send to specific user
      const deviceTokens = await prisma.deviceToken.findMany({
        where: { userId: targetUserId },
      });

      const author = post.user;
      let message = '';
      switch (type) {
        case 'NUDGE':
          message = `${author.name} is nudging you to check in!`;
          break;
        case 'ENCOURAGEMENT':
          message = `${author.name} sent you encouragement!`;
          break;
        case 'CELEBRATION':
          message = `${author.name} is celebrating with you! 🎉`;
          break;
      }

      for (const dt of deviceTokens) {
        await sendPush(dt.token, {
          title: pod?.name || 'SEEN',
          body: message,
          data: { podId, postId: post.id },
        });
      }
    }

    res.status(201).json({
      success: true,
      data: {
        id: post.id,
        type: post.type,
        content: post.content,
        mediaUrl: post.mediaUrl,
        mediaType: post.mediaType,
        author: {
          id: post.user.id,
          name: post.user.name,
          avatarUrl: post.user.avatarUrl,
        },
        target: post.target
          ? {
              id: post.target.id,
              name: post.target.name,
              avatarUrl: post.target.avatarUrl,
            }
          : null,
        createdAt: post.createdAt,
      },
    });
  } catch (error) {
    if (error instanceof ForbiddenError || error instanceof ValidationError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Create pod post error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create post' },
    });
  }
});

// POST /pods/:podId/nudge/:targetUserId - Send a nudge to a specific member
router.post('/:podId/nudge/:targetUserId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { podId, targetUserId } = req.params;
    const userId = req.user!.id;
    const { content } = req.body;

    // Verify sender is in pod
    const senderMembership = await prisma.podMember.findUnique({
      where: { podId_userId: { podId, userId } },
    });

    if (!senderMembership || senderMembership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not a member of this pod');
    }

    // Verify target is in pod
    const targetMembership = await prisma.podMember.findUnique({
      where: { podId_userId: { podId, userId: targetUserId } },
    });

    if (!targetMembership || targetMembership.status !== 'ACTIVE') {
      throw new NotFoundError('User is not a member of this pod');
    }

    // Can't nudge yourself
    if (userId === targetUserId) {
      throw new ValidationError('You cannot nudge yourself');
    }

    // Create the nudge post
    const post = await prisma.podPost.create({
      data: {
        podId,
        userId,
        type: 'NUDGE',
        content: content?.trim() || null,
        targetUserId,
      },
      include: {
        user: { select: { id: true, name: true } },
      },
    });

    // Get pod name
    const pod = await prisma.pod.findUnique({
      where: { id: podId },
      select: { name: true },
    });

    // Send push notification
    const deviceTokens = await prisma.deviceToken.findMany({
      where: { userId: targetUserId },
    });

    for (const dt of deviceTokens) {
      await sendPush(dt.token, {
        title: pod?.name || 'SEEN',
        body: `${post.user.name} is nudging you to check in! 👊`,
        data: { podId, postId: post.id, type: 'NUDGE' },
      });
    }

    res.status(201).json({
      success: true,
      data: {
        id: post.id,
        type: post.type,
        message: 'Nudge sent successfully',
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
    console.error('Send nudge error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to send nudge' },
    });
  }
});

export default router;
