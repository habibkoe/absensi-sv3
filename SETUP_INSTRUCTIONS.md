# Student Attendance System - Setup Instructions

## Overview
A comprehensive student attendance management system built with SvelteKit and Supabase, featuring classroom management, student management, attendance tracking, and Excel reporting.

## Database Schema Design

### Key Design Decisions:

1. **year_of_study** is stored in the `master_class_room` table
   - Rationale: All students in a classroom are typically in the same year
   - More normalized approach
   - When students advance, they move to a different classroom

2. **attendance** table includes both `student_id` AND `class_room_id`
   - Rationale: 
     - Historical accuracy (tracks which classroom student was in when attendance was taken)
     - Better query performance for classroom-specific reports
     - Data validation and integrity

## Prerequisites

- Node.js (v18 or higher)
- A Supabase account (free tier is sufficient)
- Modern web browser

## Step 1: Supabase Setup

### 1.1 Create a Supabase Project
1. Go to https://supabase.com
2. Sign up or log in
3. Click "New Project"
4. Fill in:
   - **Name**: Student Attendance System
   - **Database Password**: (create a strong password and save it)
   - **Region**: Choose closest to you
5. Wait for the project to be created (1-2 minutes)

### 1.2 Get Your Credentials
1. Go to Project Settings (gear icon)
2. Click on "API" in the left sidebar
3. Copy the following:
   - **Project URL** (under "Project URL")
   - **anon/public key** (under "Project API keys")

### 1.3 Create Database Tables
1. In your Supabase dashboard, click on "SQL Editor"
2. Click "New Query"
3. Copy the entire content from `supabase_schema.sql` file
4. Click "Run" to execute the SQL
5. Verify tables are created by going to "Table Editor"

### 1.4 Create Storage Bucket for Photos
1. Go to "Storage" in the left sidebar
2. Click "Create a new bucket"
3. Name it: `student-photos`
4. Set it to **Public**
5. Click "Create bucket"

### 1.5 Create Your First User Account
1. Go to "Authentication" in the left sidebar
2. Click "Add user" → "Create new user"
3. Enter an email and password
4. Click "Create user"
5. This will be your login credentials

## Step 2: Configure the Application

### 2.1 Set Environment Variables
1. In the project root, create a `.env` file:
   ```bash
   copy .env.example .env
   ```

2. Open `.env` and add your Supabase credentials:
   ```env
   PUBLIC_SUPABASE_URL=your-project-url-here
   PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
   ```

## Step 3: Run the Application

### 3.1 Install Dependencies (if not already done)
```bash
npm install
```

### 3.2 Start Development Server
```bash
npm run dev
```

### 3.3 Access the Application
Open your browser and go to: http://localhost:5173

## Step 4: Using the System

### 4.1 Login
- Use the email and password you created in Supabase Authentication

### 4.2 Set Up Classrooms
1. Navigate to "Classrooms"
2. Click "+ Add Classroom"
3. Enter classroom name and year of study
4. Example: "Class 10A", Year of Study: 10

### 4.3 Add Students
1. Navigate to "Students"
2. Click "+ Add Student"
3. Fill in:
   - Student Name
   - Registration Number (up to 20 digits)
   - Select Classroom
   - Upload Photo (optional, max 5MB)

### 4.4 Take Attendance
1. Navigate to "Attendance"
2. Select a classroom
3. Select a date
4. Mark attendance status for each student:
   - Present
   - Absent
   - Late
   - Excused
5. Use "Quick Actions" to mark all students at once
6. Click "Save Attendance"

### 4.5 Generate Reports
1. Navigate to "Reports"
2. Choose report type:
   - **Classroom Report**: Summary of all students in a classroom
   - **Individual Student Report**: Detailed history for one student
3. Select date range
4. Select classroom (and student if needed)
5. Click "Generate Report"
6. Click "Export to Excel" to download

## Features

### ✅ Authentication
- Secure login with Supabase Auth
- Protected routes
- Session management

### ✅ Classroom Management
- Create, edit, and delete classrooms
- Associate year of study with classroom
- View all classrooms

### ✅ Student Management
- Add students with photos
- 20-digit registration number support
- Assign students to classrooms
- Search and filter students
- Photo upload to Supabase Storage

### ✅ Attendance System
- Daily attendance tracking
- Four status types: Present, Absent, Late, Excused
- Quick mark all students
- Bulk save functionality
- Historical data tracking

### ✅ Reports & Analytics
- Classroom attendance summary
- Individual student attendance history
- Date range filtering
- Attendance rate calculations
- Excel export functionality

### ✅ Dashboard
- Real-time statistics
- Today's attendance overview
- Quick action links
- System information

## Database Schema

### Tables:
1. **master_class_room**
   - id, name, year_of_study, created_at, updated_at

2. **students**
   - id, name, registration_number, photo_url, class_room_id, created_at, updated_at

3. **attendance**
   - id, student_id, class_room_id, attendance_status, date, created_at
   - Unique constraint: (student_id, date)

### Attendance Status Values:
- 0 = Absent
- 1 = Present
- 2 = Late
- 3 = Excused

## Troubleshooting

### Can't login?
- Verify you created a user in Supabase Authentication
- Check that your email and password are correct

### Tables not showing data?
- Ensure you ran the SQL schema in Supabase SQL Editor
- Check Row Level Security policies are enabled

### Photo upload failing?
- Verify the `student-photos` bucket exists
- Ensure the bucket is set to Public
- Check file size is under 5MB

### Environment variables not working?
- Restart the development server after changing `.env`
- Verify the variable names start with `PUBLIC_`

## Production Deployment

### Build for Production
```bash
npm run build
```

### Preview Production Build
```bash
npm run preview
```

### Deploy to Vercel/Netlify
1. Push your code to GitHub
2. Connect your repository to Vercel or Netlify
3. Add environment variables in the deployment settings
4. Deploy!

## Support

For issues or questions:
- Check the Supabase documentation: https://supabase.com/docs
- Review SvelteKit documentation: https://kit.svelte.dev/docs

## License

This project is open source and available for educational purposes.
