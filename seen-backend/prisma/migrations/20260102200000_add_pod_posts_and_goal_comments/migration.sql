-- CreateEnum
CREATE TYPE "PostType" AS ENUM ('ENCOURAGEMENT', 'NUDGE', 'CELEBRATION');

-- CreateEnum
CREATE TYPE "MediaType" AS ENUM ('PHOTO', 'VIDEO', 'AUDIO');

-- CreateTable
CREATE TABLE "pod_posts" (
    "id" TEXT NOT NULL,
    "pod_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "type" "PostType" NOT NULL,
    "content" TEXT,
    "media_url" TEXT,
    "media_type" "MediaType",
    "target_user_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pod_posts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "goal_comments" (
    "id" TEXT NOT NULL,
    "goal_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "content" TEXT,
    "media_url" TEXT,
    "media_type" "MediaType",
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "goal_comments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "pod_posts_pod_id_idx" ON "pod_posts"("pod_id");

-- CreateIndex
CREATE INDEX "pod_posts_user_id_idx" ON "pod_posts"("user_id");

-- CreateIndex
CREATE INDEX "pod_posts_target_user_id_idx" ON "pod_posts"("target_user_id");

-- CreateIndex
CREATE INDEX "goal_comments_goal_id_idx" ON "goal_comments"("goal_id");

-- CreateIndex
CREATE INDEX "goal_comments_user_id_idx" ON "goal_comments"("user_id");

-- AddForeignKey
ALTER TABLE "pod_posts" ADD CONSTRAINT "pod_posts_pod_id_fkey" FOREIGN KEY ("pod_id") REFERENCES "pods"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pod_posts" ADD CONSTRAINT "pod_posts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pod_posts" ADD CONSTRAINT "pod_posts_target_user_id_fkey" FOREIGN KEY ("target_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "goal_comments" ADD CONSTRAINT "goal_comments_goal_id_fkey" FOREIGN KEY ("goal_id") REFERENCES "goals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "goal_comments" ADD CONSTRAINT "goal_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
