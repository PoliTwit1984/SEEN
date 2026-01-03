import { prisma } from './prisma';

// Push notification types
export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

// For MVP, we'll log push notifications
// In production, use @parse/node-apn for APNs
export async function sendPushToUser(userId: string, payload: PushPayload): Promise<void> {
  const tokens = await prisma.deviceToken.findMany({
    where: { userId },
  });

  if (tokens.length === 0) {
    console.log(`No device tokens for user ${userId}`);
    return;
  }

  for (const token of tokens) {
    await sendPush(token.token, payload);
  }
}

export async function sendPush(deviceToken: string, payload: PushPayload): Promise<void> {
  // MVP: Just log the notification
  // TODO: Implement actual APNs sending with @parse/node-apn
  console.log(`[PUSH] To: ${deviceToken.substring(0, 20)}...`);
  console.log(`[PUSH] Title: ${payload.title}`);
  console.log(`[PUSH] Body: ${payload.body}`);
  console.log(`[PUSH] Data:`, payload.data);
  
  // Production implementation would look like:
  // const apn = require('@parse/node-apn');
  // const provider = new apn.Provider({
  //   token: {
  //     key: process.env.APNS_KEY,
  //     keyId: process.env.APNS_KEY_ID,
  //     teamId: process.env.APPLE_TEAM_ID,
  //   },
  //   production: process.env.NODE_ENV === 'production',
  // });
  // 
  // const notification = new apn.Notification();
  // notification.alert = { title: payload.title, body: payload.body };
  // notification.payload = payload.data;
  // notification.topic = 'com.obey.SEEN';
  // 
  // await provider.send(notification, deviceToken);
}

// Notification helpers
export async function notifyHighFive(
  recipientUserId: string,
  senderName: string,
  goalTitle: string,
  checkInId: string
): Promise<void> {
  await sendPushToUser(recipientUserId, {
    title: '🙌 High Five!',
    body: `${senderName} gave you a high five for "${goalTitle}"`,
    data: {
      type: 'high_five',
      checkInId,
    },
  });
}

export async function notifyReaction(
  recipientUserId: string,
  senderName: string,
  reactionEmoji: string,
  goalTitle: string,
  checkInId: string
): Promise<void> {
  await sendPushToUser(recipientUserId, {
    title: `${reactionEmoji} New Reaction`,
    body: `${senderName} reacted to your check-in for "${goalTitle}"`,
    data: {
      type: 'reaction',
      checkInId,
    },
  });
}

export async function notifyReminder(
  userId: string,
  goalTitle: string,
  goalId: string
): Promise<void> {
  await sendPushToUser(userId, {
    title: '⏰ Reminder',
    body: `Don't forget: ${goalTitle}`,
    data: {
      type: 'reminder',
      goalId,
    },
  });
}

export async function notifyMissedCheckIn(
  userId: string,
  goalTitle: string,
  goalId: string
): Promise<void> {
  await sendPushToUser(userId, {
    title: '😢 Missed Check-in',
    body: `You missed your check-in for "${goalTitle}"`,
    data: {
      type: 'missed',
      goalId,
    },
  });
}
