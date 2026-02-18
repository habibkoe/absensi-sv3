-- Add semester column to attendance table
-- Semester 1: July - December
-- Semester 2: January - June

ALTER TABLE attendance 
ADD COLUMN semester SMALLINT DEFAULT 1;

-- Optional: Update existing records based on date
-- UPDATE attendance 
-- SET semester = CASE 
--     WHEN EXTRACT(MONTH FROM date) >= 7 THEN 1
--     ELSE 2
-- END;
