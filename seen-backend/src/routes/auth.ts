import { Router, Request, Response } from 'express';
import appleSignin from 'apple-signin-auth';
import { prisma } from '../lib/prisma';
import {
  generateAccessToken,
  createRefreshToken,
  verifyAndRotateRefreshToken,
  revokeRefreshToken,
} from '../lib/jwt';
import { ValidationError, UnauthorizedError } from '../lib/errors';

const router = Router();

interface AppleAuthRequest {
  identityToken: string;
  firstName?: string;
  lastName?: string;
}

interface RefreshRequest {
  refreshToken: string;
}

// POST /auth/apple
router.post('/apple', async (req: Request, res: Response): Promise<void> => {
  try {
    const { identityToken, firstName, lastName } = req.body as AppleAuthRequest;

    if (!identityToken) {
      throw new ValidationError('Identity token is required');
    }

    // Verify the Apple identity token
    let applePayload;
    try {
      applePayload = await appleSignin.verifyIdToken(identityToken, {
        audience: process.env.APPLE_CLIENT_ID || 'com.obey.SEEN',
        ignoreExpiration: false,
      });
    } catch (error) {
      console.error('Apple token verification failed:', error);
      throw new UnauthorizedError('Invalid Apple identity token');
    }

    const appleId = applePayload.sub;
    const email = applePayload.email || null;

    // Find existing user or create new one
    let user = await prisma.user.findUnique({
      where: { appleId },
    });

    const isNewUser = !user;

    if (!user) {
      // Create new user
      const name = [firstName, lastName].filter(Boolean).join(' ') || 'User';
      
      user = await prisma.user.create({
        data: {
          appleId,
          email,
          name,
        },
      });
    } else if (email && !user.email) {
      // Update email if we got it and user doesn't have one
      user = await prisma.user.update({
        where: { id: user.id },
        data: { email },
      });
    }

    // Generate tokens
    const accessToken = generateAccessToken(user.id);
    const refreshToken = await createRefreshToken(user.id);

    res.json({
      success: true,
      data: {
        accessToken,
        refreshToken,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          avatarUrl: user.avatarUrl,
          timezone: user.timezone,
        },
        isNewUser,
      },
    });
  } catch (error) {
    if (error instanceof ValidationError || error instanceof UnauthorizedError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Auth error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Authentication failed' },
    });
  }
});

// POST /auth/refresh
router.post('/refresh', async (req: Request, res: Response): Promise<void> => {
  try {
    const { refreshToken } = req.body as RefreshRequest;

    if (!refreshToken) {
      throw new ValidationError('Refresh token is required');
    }

    const tokens = await verifyAndRotateRefreshToken(refreshToken);

    res.json({
      success: true,
      data: {
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      },
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      res.status(400).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    res.status(401).json({
      success: false,
      error: { code: 'UNAUTHORIZED', message: 'Invalid or expired refresh token' },
    });
  }
});

// POST /auth/logout
router.post('/logout', async (req: Request, res: Response): Promise<void> => {
  try {
    const { refreshToken } = req.body as RefreshRequest;

    if (refreshToken) {
      await revokeRefreshToken(refreshToken);
    }

    res.json({
      success: true,
      data: { message: 'Logged out successfully' },
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Logout failed' },
    });
  }
});

export default router;
