import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth';
import { ValidationError, NotFoundError, ForbiddenError } from '../lib/errors';

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

// GET /feed/unified - Get unified feed from all user's pods (posts + check-ins)
router.get('/unified', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { cursor, limit = '20' } = req.query;
    const take = Math.min(parseInt(limit as string), 50);

    // Get all pods the user is a member of
    const memberships = await prisma.podMember.findMany({
      where: {
        userId: req.user!.id,
        status: 'ACTIVE',
      },
      select: {
        podId: true,
        pod: {
          select: { id: true, name: true },
        },
      },
    });

    const podIds = memberships.map((m) => m.podId);

    if (podIds.length === 0) {
      res.json({
        success: true,
        data: {
          items: [],
          nextCursor: null,
        },
      });
      return;
    }

    // Build cursor condition
    const cursorCondition = cursor ? { createdAt: { lt: new Date(cursor as string) } } : {};

    // Get posts from all pods with reactions and comments
    const posts = await prisma.podPost.findMany({
      where: {
        podId: { in: podIds },
        ...cursorCondition,
      },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
        target: {
          select: { id: true, name: true, avatarUrl: true },
        },
        pod: {
          select: { id: true, name: true },
        },
        reactions: {
          select: { type: true, userId: true },
        },
        _count: {
          select: { feedComments: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
    });

    // Get check-ins from all pods with reactions and comments
    const checkIns = await prisma.checkIn.findMany({
      where: {
        goal: {
          podId: { in: podIds },
          isArchived: false,
        },
        status: 'COMPLETED',
        ...cursorCondition,
      },
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
        goal: {
          select: {
            id: true,
            title: true,
            description: true,
            frequencyType: true,
            frequencyDays: true,
            currentStreak: true,
            podId: true,
            pod: {
              select: { id: true, name: true },
            },
          },
        },
        interactions: {
          select: { type: true, userId: true },
        },
        _count: {
          select: { feedComments: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
    });

    // Helper to get top reactions
    const getTopReactions = (reactions: { type: string }[]): string[] => {
      const typeCounts: Record<string, number> = {};
      reactions.forEach((r) => {
        typeCounts[r.type] = (typeCounts[r.type] || 0) + 1;
      });
      return Object.entries(typeCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([type]) => type);
    };

    // Helper to format frequency
    const formatFrequency = (type: string, days: number[]): string => {
      if (type === 'DAILY') return 'Daily';
      if (type === 'WEEKLY') return 'Weekly';
      if (type === 'SPECIFIC_DAYS') {
        const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        return days.map((d) => dayNames[d]).join(', ');
      }
      return type;
    };

    // Combine and format feed items
    interface FeedItem {
      id: string;
      type: string;
      content: string | null;
      mediaUrl: string | null;
      mediaType: string | null;
      author: { id: string; name: string; avatarUrl: string | null };
      target: { id: string; name: string; avatarUrl: string | null } | null;
      podId: string;
      podName: string;
      goalTitle?: string;
      goalDescription?: string | null;
      goalFrequency?: string;
      currentStreak?: number;
      completedAt?: string;
      reactionCount: number;
      commentCount: number;
      myReaction: string | null;
      topReactions: string[];
      createdAt: Date;
    }

    const userId = req.user!.id;

    const feedItems: FeedItem[] = [
      ...posts.map((post) => ({
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
        podId: post.pod.id,
        podName: post.pod.name,
        reactionCount: post.reactions.length,
        commentCount: post._count.feedComments,
        myReaction: post.reactions.find((r) => r.userId === userId)?.type || null,
        topReactions: getTopReactions(post.reactions),
        createdAt: post.createdAt,
      })),
      ...checkIns.map((checkIn) => ({
        id: checkIn.id,
        type: 'CHECK_IN',
        content: checkIn.comment,
        mediaUrl: checkIn.proofUrl,
        mediaType: checkIn.proofUrl ? 'PHOTO' : null,
        author: {
          id: checkIn.user.id,
          name: checkIn.user.name,
          avatarUrl: checkIn.user.avatarUrl,
        },
        target: null,
        podId: checkIn.goal.pod.id,
        podName: checkIn.goal.pod.name,
        goalTitle: checkIn.goal.title,
        goalDescription: checkIn.goal.description,
        goalFrequency: formatFrequency(checkIn.goal.frequencyType, checkIn.goal.frequencyDays),
        currentStreak: checkIn.goal.currentStreak,
        completedAt: checkIn.createdAt.toISOString(),
        reactionCount: checkIn.interactions.length,
        commentCount: checkIn._count.feedComments,
        myReaction: checkIn.interactions.find((i) => i.userId === userId)?.type || null,
        topReactions: getTopReactions(checkIn.interactions),
        createdAt: checkIn.createdAt,
      })),
    ];

    // Sort by createdAt descending
    feedItems.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

    // Apply limit
    const hasMore = feedItems.length > take;
    const resultItems = feedItems.slice(0, take);
    const nextCursor = hasMore ? resultItems[resultItems.length - 1].createdAt.toISOString() : null;

    // Format response
    const formattedItems = resultItems.map((item) => ({
      id: item.id,
      type: item.type,
      content: item.content,
      mediaUrl: item.mediaUrl,
      mediaType: item.mediaType,
      author: item.author,
      target: item.target,
      podId: item.podId,
      podName: item.podName,
      goalTitle: item.goalTitle,
      goalDescription: item.goalDescription,
      goalFrequency: item.goalFrequency,
      currentStreak: item.currentStreak,
      completedAt: item.completedAt,
      reactionCount: item.reactionCount,
      commentCount: item.commentCount,
      myReaction: item.myReaction,
      topReactions: item.topReactions,
      createdAt: item.createdAt.toISOString(),
    }));

    res.json({
      success: true,
      data: {
        items: formattedItems,
        nextCursor,
      },
    });
  } catch (error) {
    console.error('Get unified feed error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get unified feed' },
    });
  }
});

// ============== REACTIONS ==============

// POST /feed/items/:itemType/:itemId/react - Add/update reaction
router.post(
  '/items/:itemType/:itemId/react',
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { itemType, itemId } = req.params;
      const { type } = req.body;

      // Validate reaction type
      const validTypes = ['HIGH_FIVE', 'FIRE', 'CLAP', 'HEART'];
      if (!type || !validTypes.includes(type)) {
        throw new ValidationError('Invalid reaction type');
      }

      if (itemType === 'checkin') {
        // Verify check-in exists and user has access
        const checkIn = await prisma.checkIn.findUnique({
          where: { id: itemId },
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

        if (checkIn.goal.pod.members.length === 0) {
          throw new ForbiddenError('You are not a member of this pod');
        }

        // Upsert reaction (existing Interaction model)
        const reaction = await prisma.interaction.upsert({
          where: {
            checkInId_userId: { checkInId: itemId, userId: req.user!.id },
          },
          update: { type },
          create: {
            checkInId: itemId,
            userId: req.user!.id,
            type,
          },
          include: {
            user: { select: { id: true, name: true } },
          },
        });

        res.json({
          success: true,
          data: {
            id: reaction.id,
            type: reaction.type,
            user: reaction.user,
            createdAt: reaction.createdAt,
          },
        });
      } else if (itemType === 'post') {
        // Verify post exists and user has access
        const post = await prisma.podPost.findUnique({
          where: { id: itemId },
          include: {
            pod: {
              include: {
                members: {
                  where: { userId: req.user!.id, status: 'ACTIVE' },
                },
              },
            },
          },
        });

        if (!post) {
          throw new NotFoundError('Post not found');
        }

        if (post.pod.members.length === 0) {
          throw new ForbiddenError('You are not a member of this pod');
        }

        // Upsert reaction (PostReaction model)
        const reaction = await prisma.postReaction.upsert({
          where: {
            postId_userId: { postId: itemId, userId: req.user!.id },
          },
          update: { type },
          create: {
            postId: itemId,
            userId: req.user!.id,
            type,
          },
          include: {
            user: { select: { id: true, name: true } },
          },
        });

        res.json({
          success: true,
          data: {
            id: reaction.id,
            type: reaction.type,
            user: reaction.user,
            createdAt: reaction.createdAt,
          },
        });
      } else {
        throw new ValidationError('Invalid item type. Use "checkin" or "post"');
      }
    } catch (error) {
      if (error instanceof ValidationError || error instanceof NotFoundError || error instanceof ForbiddenError) {
        res.status(error.statusCode).json({
          success: false,
          error: { code: error.code, message: error.message },
        });
        return;
      }
      console.error('Add reaction error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to add reaction' },
      });
    }
  }
);

// DELETE /feed/items/:itemType/:itemId/react - Remove reaction
router.delete(
  '/items/:itemType/:itemId/react',
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { itemType, itemId } = req.params;

      if (itemType === 'checkin') {
        await prisma.interaction.deleteMany({
          where: { checkInId: itemId, userId: req.user!.id },
        });
      } else if (itemType === 'post') {
        await prisma.postReaction.deleteMany({
          where: { postId: itemId, userId: req.user!.id },
        });
      } else {
        throw new ValidationError('Invalid item type. Use "checkin" or "post"');
      }

      res.json({
        success: true,
        data: { message: 'Reaction removed' },
      });
    } catch (error) {
      if (error instanceof ValidationError) {
        res.status(error.statusCode).json({
          success: false,
          error: { code: error.code, message: error.message },
        });
        return;
      }
      console.error('Remove reaction error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to remove reaction' },
      });
    }
  }
);

// ============== COMMENTS ==============

// GET /feed/items/:itemType/:itemId/comments - Get comments for an item
router.get(
  '/items/:itemType/:itemId/comments',
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { itemType, itemId } = req.params;
      const { limit = '20', cursor } = req.query;
      const take = Math.min(parseInt(limit as string), 50);

      const cursorCondition = cursor ? { createdAt: { lt: new Date(cursor as string) } } : {};

      let whereClause: { checkInId?: string; postId?: string };
      if (itemType === 'checkin') {
        whereClause = { checkInId: itemId };
      } else if (itemType === 'post') {
        whereClause = { postId: itemId };
      } else {
        throw new ValidationError('Invalid item type. Use "checkin" or "post"');
      }

      const comments = await prisma.feedComment.findMany({
        where: {
          ...whereClause,
          ...cursorCondition,
        },
        include: {
          user: { select: { id: true, name: true, avatarUrl: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: take + 1,
      });

      const hasMore = comments.length > take;
      const resultComments = comments.slice(0, take);
      const nextCursor = hasMore ? resultComments[resultComments.length - 1].createdAt.toISOString() : null;

      res.json({
        success: true,
        data: {
          comments: resultComments.map((c) => ({
            id: c.id,
            content: c.content,
            mediaUrl: c.mediaUrl,
            mediaType: c.mediaType,
            author: {
              id: c.user.id,
              name: c.user.name,
              avatarUrl: c.user.avatarUrl,
            },
            createdAt: c.createdAt.toISOString(),
          })),
          nextCursor,
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
      console.error('Get comments error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to get comments' },
      });
    }
  }
);

// POST /feed/items/:itemType/:itemId/comments - Add comment to an item
router.post(
  '/items/:itemType/:itemId/comments',
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { itemType, itemId } = req.params;
      const { content, mediaUrl, mediaType } = req.body;

      // Validate that we have content or media
      if (!content && !mediaUrl) {
        throw new ValidationError('Comment must have content or media');
      }

      // Validate media type if provided
      if (mediaUrl && mediaType) {
        const validMediaTypes = ['PHOTO', 'VIDEO', 'AUDIO'];
        if (!validMediaTypes.includes(mediaType)) {
          throw new ValidationError('Invalid media type');
        }
      }

      let commentData: { checkInId?: string; postId?: string };

      if (itemType === 'checkin') {
        // Verify check-in exists and user has access
        const checkIn = await prisma.checkIn.findUnique({
          where: { id: itemId },
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

        if (checkIn.goal.pod.members.length === 0) {
          throw new ForbiddenError('You are not a member of this pod');
        }

        commentData = { checkInId: itemId };
      } else if (itemType === 'post') {
        // Verify post exists and user has access
        const post = await prisma.podPost.findUnique({
          where: { id: itemId },
          include: {
            pod: {
              include: {
                members: {
                  where: { userId: req.user!.id, status: 'ACTIVE' },
                },
              },
            },
          },
        });

        if (!post) {
          throw new NotFoundError('Post not found');
        }

        if (post.pod.members.length === 0) {
          throw new ForbiddenError('You are not a member of this pod');
        }

        commentData = { postId: itemId };
      } else {
        throw new ValidationError('Invalid item type. Use "checkin" or "post"');
      }

      const comment = await prisma.feedComment.create({
        data: {
          userId: req.user!.id,
          content: content?.trim() || null,
          mediaUrl: mediaUrl || null,
          mediaType: mediaType || null,
          ...commentData,
        },
        include: {
          user: { select: { id: true, name: true, avatarUrl: true } },
        },
      });

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
          createdAt: comment.createdAt.toISOString(),
        },
      });
    } catch (error) {
      if (error instanceof ValidationError || error instanceof NotFoundError || error instanceof ForbiddenError) {
        res.status(error.statusCode).json({
          success: false,
          error: { code: error.code, message: error.message },
        });
        return;
      }
      console.error('Add comment error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to add comment' },
      });
    }
  }
);

// DELETE /feed/comments/:commentId - Delete own comment
router.delete('/comments/:commentId', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { commentId } = req.params;

    const comment = await prisma.feedComment.findUnique({
      where: { id: commentId },
    });

    if (!comment) {
      throw new NotFoundError('Comment not found');
    }

    if (comment.userId !== req.user!.id) {
      throw new ForbiddenError('You can only delete your own comments');
    }

    await prisma.feedComment.delete({
      where: { id: commentId },
    });

    res.json({
      success: true,
      data: { message: 'Comment deleted' },
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
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
