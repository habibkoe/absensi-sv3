-- Migration: Add gender column to students table
-- Run this SQL in your Supabase SQL Editor

-- Add gender column to students table
ALTER TABLE students 
ADD COLUMN gender CHAR(1) CHECK (gender IN ('L', 'P'));

-- Add comment to document the field
COMMENT ON COLUMN students.gender IS 'Student gender: L = Laki-Laki (Male), P = Perempuan (Female)';

-- Create index for better query performance (optional, useful for filtering/reporting)
CREATE INDEX idx_students_gender ON students(gender);
