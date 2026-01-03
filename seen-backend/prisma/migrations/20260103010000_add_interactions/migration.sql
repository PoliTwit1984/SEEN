-- CreateEnum
CREATE TYPE "InteractionType" AS ENUM ('HIGH_FIVE', 'FIRE', 'CLAP', 'HEART');

-- CreateTable
CREATE TABLE "interactions" (
    "id" TEXT NOT NULL,
    "check_in_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "type" "InteractionType" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "interactions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "interactions_user_id_idx" ON "interactions"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "interactions_check_in_id_user_id_key" ON "interactions"("check_in_id", "user_id");

-- AddForeignKey
ALTER TABLE "interactions" ADD CONSTRAINT "interactions_check_in_id_fkey" FOREIGN KEY ("check_in_id") REFERENCES "check_ins"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "interactions" ADD CONSTRAINT "interactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
