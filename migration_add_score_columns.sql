-- Migration: Add score columns to attendance table
-- Run this SQL in your Supabase SQL Editor to add the new columns

-- Add is_auto_score column
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS is_auto_score BOOLEAN DEFAULT false;

-- Add score_nominal column
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS score_nominal DECIMAL(5,2);

-- Update existing records to have default values
UPDATE attendance 
SET is_auto_score = false 
WHERE is_auto_score IS NULL;

-- Add comment to columns for documentation
COMMENT ON COLUMN attendance.is_auto_score IS 'Indicates if score is automatically set to 100';
COMMENT ON COLUMN attendance.score_nominal IS 'Nominal score value (0-100) for Tugas status';

-- Verify the migration
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'attendance'
AND column_name IN ('is_auto_score', 'score_nominal');
