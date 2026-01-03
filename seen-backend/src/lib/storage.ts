import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

// Cloudflare R2 is S3-compatible
const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID;
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID;
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY;
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || 'seen-photos';
const R2_PUBLIC_URL = process.env.R2_PUBLIC_URL; // e.g., https://photos.seenapp.co

// Initialize S3 client for R2
const getS3Client = () => {
  if (!R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY) {
    console.warn('R2 credentials not configured - photo upload will fail');
    return null;
  }

  return new S3Client({
    region: 'auto',
    endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: R2_ACCESS_KEY_ID,
      secretAccessKey: R2_SECRET_ACCESS_KEY,
    },
  });
};

export interface PresignedUploadResult {
  uploadUrl: string;
  publicUrl: string;
  key: string;
}

/**
 * Generate a presigned URL for uploading a file to R2
 */
export async function generateUploadUrl(
  userId: string,
  goalId: string,
  fileExtension: string = 'jpg'
): Promise<PresignedUploadResult> {
  const s3 = getS3Client();

  if (!s3) {
    throw new Error('Storage not configured');
  }

  // Generate unique key: proofs/{userId}/{goalId}/{timestamp}.{ext}
  const timestamp = Date.now();
  const key = `proofs/${userId}/${goalId}/${timestamp}.${fileExtension}`;

  const command = new PutObjectCommand({
    Bucket: R2_BUCKET_NAME,
    Key: key,
    ContentType: `image/${fileExtension === 'jpg' ? 'jpeg' : fileExtension}`,
  });

  // URL expires in 5 minutes
  const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 });

  // Public URL for accessing the file after upload
  const publicUrl = R2_PUBLIC_URL
    ? `${R2_PUBLIC_URL}/${key}`
    : `https://${R2_BUCKET_NAME}.${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${key}`;

  return {
    uploadUrl,
    publicUrl,
    key,
  };
}

/**
 * Generate a presigned URL for uploading an avatar to R2
 */
export async function generateAvatarUploadUrl(
  userId: string,
  fileExtension: string = 'jpg'
): Promise<PresignedUploadResult> {
  const s3 = getS3Client();

  if (!s3) {
    throw new Error('Storage not configured');
  }

  // Generate unique key: avatars/{userId}/{timestamp}.{ext}
  const timestamp = Date.now();
  const key = `avatars/${userId}/${timestamp}.${fileExtension}`;

  const command = new PutObjectCommand({
    Bucket: R2_BUCKET_NAME,
    Key: key,
    ContentType: `image/${fileExtension === 'jpg' ? 'jpeg' : fileExtension}`,
  });

  // URL expires in 5 minutes
  const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 });

  // Public URL for accessing the file after upload
  const publicUrl = R2_PUBLIC_URL
    ? `${R2_PUBLIC_URL}/${key}`
    : `https://${R2_BUCKET_NAME}.${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${key}`;

  return {
    uploadUrl,
    publicUrl,
    key,
  };
}

/**
 * Generate a presigned URL for viewing a private file
 */
export async function generateViewUrl(key: string): Promise<string> {
  const s3 = getS3Client();

  if (!s3) {
    throw new Error('Storage not configured');
  }

  const command = new GetObjectCommand({
    Bucket: R2_BUCKET_NAME,
    Key: key,
  });

  // URL expires in 1 hour
  return await getSignedUrl(s3, command, { expiresIn: 3600 });
}

/**
 * Check if storage is configured
 */
export function isStorageConfigured(): boolean {
  return !!(R2_ACCOUNT_ID && R2_ACCESS_KEY_ID && R2_SECRET_ACCESS_KEY);
}
