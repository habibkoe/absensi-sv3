-- Student Attendance System Database Schema
-- Run this SQL in your Supabase SQL Editor

-- 1. Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Classroom Master Table
CREATE TABLE master_class_room (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  year_of_study INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Students Table
CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  registration_number VARCHAR(20) UNIQUE NOT NULL,
  photo_url TEXT,
  class_room_id UUID REFERENCES master_class_room(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Attendance Table
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  class_room_id UUID NOT NULL REFERENCES master_class_room(id) ON DELETE CASCADE,
  attendance_status INTEGER NOT NULL, -- 1=present, 0=absent, 2=late, 3=excused
  date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(student_id, date) -- Prevent duplicate attendance entries for same student on same day
);

-- 5. Create indexes for better query performance
CREATE INDEX idx_students_classroom ON students(class_room_id);
CREATE INDEX idx_students_registration ON students(registration_number);
CREATE INDEX idx_attendance_student ON attendance(student_id);
CREATE INDEX idx_attendance_classroom ON attendance(class_room_id);
CREATE INDEX idx_attendance_date ON attendance(date);
CREATE INDEX idx_attendance_classroom_date ON attendance(class_room_id, date);

-- 6. Enable Row Level Security (RLS)
ALTER TABLE master_class_room ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS Policies (Allow authenticated users to perform all operations)
-- Classroom policies
CREATE POLICY "Allow authenticated users to read classrooms" ON master_class_room
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert classrooms" ON master_class_room
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update classrooms" ON master_class_room
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to delete classrooms" ON master_class_room
  FOR DELETE TO authenticated USING (true);

-- Students policies
CREATE POLICY "Allow authenticated users to read students" ON students
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert students" ON students
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update students" ON students
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to delete students" ON students
  FOR DELETE TO authenticated USING (true);

-- Attendance policies
CREATE POLICY "Allow authenticated users to read attendance" ON attendance
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert attendance" ON attendance
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update attendance" ON attendance
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to delete attendance" ON attendance
  FOR DELETE TO authenticated USING (true);

-- 8. Create a storage bucket for student photos (run this after creating tables)
-- Go to Storage > Create a new bucket named "student-photos" with public access
-- Or run this in SQL if you have proper permissions:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('student-photos', 'student-photos', true);

-- 9. Storage policies for student photos bucket
-- Run these after creating the storage bucket
CREATE POLICY "Allow authenticated users to upload student photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'student-photos');

CREATE POLICY "Allow public to view student photos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'student-photos');

CREATE POLICY "Allow authenticated users to update student photos"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'student-photos');

CREATE POLICY "Allow authenticated users to delete student photos"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'student-photos');
