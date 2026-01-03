import { Router, Request, Response } from 'express';
import { prisma } from '../lib/prisma';
import { ValidationError, ConflictError } from '../lib/errors';

const router = Router();

interface WaitlistRequest {
  email: string;
  name?: string;
  referralCode?: string;
  priority?: number;
}

// POST /waitlist - Add email to waitlist (Direct or from Frontend)
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, name, referralCode, priority } = req.body as WaitlistRequest;

    if (!email) {
      throw new ValidationError('Email is required');
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new ValidationError('Invalid email format');
    }

    const entry = await prisma.waitlistEntry.upsert({
      where: { email: email.toLowerCase() },
      update: {
        name: name || undefined,
        referralCode: referralCode || undefined,
        priority: priority || undefined,
      },
      create: {
        email: email.toLowerCase(),
        name: name || null,
        referralCode: referralCode || null,
        priority: priority || null,
      },
    });

    res.status(201).json({
      success: true,
      data: entry,
    });
  } catch (error) {
    if (error instanceof ValidationError || error instanceof ConflictError) {
      res.status(error.statusCode).json({
        success: false,
        error: { code: error.code, message: error.message },
      });
      return;
    }
    console.error('Waitlist error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to join waitlist' },
    });
  }
});

// POST /waitlist/webhook - GetWaitlist Webhook Sync
// You can set this URL in the GetWaitlist dashboard
router.post('/webhook', async (req: Request, res: Response): Promise<void> => {
  try {
    // GetWaitlist usually sends the user object in the body
    const { email, name, referral_code, priority } = req.body;

    if (!email) {
      res.status(400).json({ success: false, message: 'No email provided in webhook' });
      return;
    }

    await prisma.waitlistEntry.upsert({
      where: { email: email.toLowerCase() },
      update: {
        name: name || undefined,
        referralCode: referral_code || undefined,
        priority: priority || undefined,
      },
      create: {
        email: email.toLowerCase(),
        name: name || null,
        referralCode: referral_code || null,
        priority: priority || null,
      },
    });

    res.json({ success: true, message: 'Synced' });
  } catch (error) {
    console.error('Webhook sync error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// GET /waitlist/count - Get waitlist count (public)
router.get('/count', async (_req: Request, res: Response): Promise<void> => {
  try {
    const count = await prisma.waitlistEntry.count();

    res.json({
      success: true,
      data: { count },
    });
  } catch (error) {
    console.error('Waitlist count error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get count' },
    });
  }
});

export default router;
