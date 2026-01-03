-- CreateTable
CREATE TABLE "post_reactions" (
    "id" TEXT NOT NULL,
    "post_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "type" "InteractionType" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_reactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "feed_comments" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "content" TEXT,
    "media_url" TEXT,
    "media_type" "MediaType",
    "check_in_id" TEXT,
    "post_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "feed_comments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "post_reactions_user_id_idx" ON "post_reactions"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "post_reactions_post_id_user_id_key" ON "post_reactions"("post_id", "user_id");

-- CreateIndex
CREATE INDEX "feed_comments_check_in_id_idx" ON "feed_comments"("check_in_id");

-- CreateIndex
CREATE INDEX "feed_comments_post_id_idx" ON "feed_comments"("post_id");

-- CreateIndex
CREATE INDEX "feed_comments_user_id_idx" ON "feed_comments"("user_id");

-- AddForeignKey
ALTER TABLE "post_reactions" ADD CONSTRAINT "post_reactions_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "pod_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_reactions" ADD CONSTRAINT "post_reactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "feed_comments" ADD CONSTRAINT "feed_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "feed_comments" ADD CONSTRAINT "feed_comments_check_in_id_fkey" FOREIGN KEY ("check_in_id") REFERENCES "check_ins"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "feed_comments" ADD CONSTRAINT "feed_comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "pod_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
