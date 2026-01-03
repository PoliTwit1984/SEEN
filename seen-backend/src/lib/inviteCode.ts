import { prisma } from './prisma';

const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluding confusing chars: I, O, 0, 1

export async function generateInviteCode(): Promise<string> {
  const maxAttempts = 10;
  
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += CHARS.charAt(Math.floor(Math.random() * CHARS.length));
    }
    
    // Check for collision
    const existing = await prisma.pod.findUnique({
      where: { inviteCode: code },
    });
    
    if (!existing) {
      return code;
    }
  }
  
  throw new Error('Failed to generate unique invite code');
}
