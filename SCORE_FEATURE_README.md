# Tugas Score Feature - Implementation Guide

## Overview
This update implements a scoring system for students assigned "Tugas" (assignment) status. The feature allows automatic scoring (100) or manual score entry.

## What's Changed

### 1. Database Schema
**New columns added to `attendance` table:**
- `is_auto_score` (BOOLEAN, default: false) - Indicates if auto-scoring is enabled
- `score_nominal` (DECIMAL(5,2)) - Stores the score value (0-100)

### 2. TypeScript Types
Updated `Attendance` interface in `src/lib/types.ts` to include:
```typescript
is_auto_score?: boolean;
score_nominal?: number;
```

### 3. UI/UX Changes

#### Fixed Tugas Button Visibility
**Old behavior:**
- Tugas button hidden after clicking it

**New behavior:**
- Tugas button remains visible when status is "Hadir" or "Tugas"
- Tugas button hidden when status is "Izin", "Alpa", "Bolos", or "Sakit"

#### New Score Input UI
When a student's status is set to "Tugas", a purple panel appears showing:

1. **Checkbox: "Auto Score (100)"**
   - When checked: System automatically saves score as 100
   - Shows badge: "Nilai: 100 (Otomatis)"

2. **Manual Score Input** (visible when checkbox is unchecked)
   - Number input field (0-100)
   - Accepts decimal values (e.g., 85.5)
   - Allows manual score entry

### 4. Business Logic

**Score Data Management:**
- Score data is only saved when status is "Tugas"
- When switching away from "Tugas" status, score data is cleared
- Auto-score checkbox sets score to 100 automatically
- Manual input allows custom scores (0-100 range)

**Data Persistence:**
- Scores are loaded from database when viewing attendance
- Scores are saved when clicking "Simpan absensi" button
- Score state is maintained across page refreshes

## Installation Steps

### Step 1: Run Database Migration

Go to your Supabase Dashboard → SQL Editor and run the migration file:

```sql
-- Use the contents of migration_add_score_columns.sql
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS is_auto_score BOOLEAN DEFAULT false;

ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS score_nominal DECIMAL(5,2);

UPDATE attendance 
SET is_auto_score = false 
WHERE is_auto_score IS NULL;
```

### Step 2: Verify Migration
Run this query to verify the columns were added:
```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'attendance'
AND column_name IN ('is_auto_score', 'score_nominal');
```

Expected output:
```
column_name     | data_type | is_nullable | column_default
----------------|-----------|-------------|---------------
is_auto_score   | boolean   | YES         | false
score_nominal   | numeric   | YES         | NULL
```

### Step 3: Test the Application

1. Start the development server:
   ```bash
   npm run dev
   ```

2. Navigate to the Attendance page

3. Select a classroom and date

4. Test the following scenarios:

#### Test Case 1: Tugas Button Visibility
- ✅ Set student status to "Hadir" → Tugas button should be visible
- ✅ Click "Tugas" → Tugas button should remain visible (not hidden)
- ✅ Click "Alpa" → Tugas button should be hidden
- ✅ Click "Sakit" → Tugas button should be hidden
- ✅ Click "Izin" → Tugas button should be hidden
- ✅ Click "Bolos" → Tugas button should be hidden

#### Test Case 2: Auto Score
- ✅ Set student to "Tugas" status
- ✅ Score panel should appear below the student
- ✅ Check "Auto Score (100)" checkbox
- ✅ Should show: "Nilai: 100 (Otomatis)"
- ✅ Save attendance
- ✅ Reload page and verify score is saved

#### Test Case 3: Manual Score
- ✅ Set student to "Tugas" status
- ✅ Leave "Auto Score" checkbox unchecked
- ✅ Enter a score (e.g., 85.5) in the input field
- ✅ Save attendance
- ✅ Reload page and verify score is saved

#### Test Case 4: Score Data Clearing
- ✅ Set student to "Tugas" with a score
- ✅ Change status to "Hadir"
- ✅ Score panel should disappear
- ✅ Save attendance
- ✅ Reload and verify score is cleared (not saved)

## Files Modified

1. **supabase_schema.sql** - Updated schema documentation
2. **src/lib/types.ts** - Added score fields to Attendance interface
3. **src/routes/attendance/+page.svelte** - Main implementation
   - Added state management (Maps for scores)
   - Fixed Tugas button visibility logic
   - Added score input UI
   - Updated save/load functions

## Files Created

1. **migration_add_score_columns.sql** - Database migration script
2. **SCORE_FEATURE_README.md** - This documentation

## Data Flow

```
User Action → State Update → UI Reactivity → Save to Database
     ↓
1. Click Tugas button
     ↓
2. setAttendance() updates attendanceRecords Map
     ↓
3. Svelte reactivity shows score input panel
     ↓
4. User checks auto-score OR enters manual score
     ↓
5. toggleAutoScore() or updateScoreNominal() updates Maps
     ↓
6. Click "Simpan absensi"
     ↓
7. saveAttendance() includes score data in records
     ↓
8. Data saved to Supabase attendance table
```

## API Changes

### loadStudents() Function
Now loads score data from attendance records:
```typescript
if (record.is_auto_score !== undefined) {
  autoScoreRecords.set(record.student_id, record.is_auto_score);
}
if (record.score_nominal !== undefined) {
  scoreNominalRecords.set(record.student_id, record.score_nominal);
}
```

### saveAttendance() Function
Includes score data when saving:
```typescript
if (status === AttendanceStatus.Tugas) {
  const isAutoScore = autoScoreRecords.get(student.id) || false;
  record.is_auto_score = isAutoScore;
  
  if (isAutoScore) {
    record.score_nominal = 100;
  } else {
    record.score_nominal = manualScore || null;
  }
}
```

## Future Enhancements (Optional)

1. **Score Validation**: Add backend validation for score range
2. **Score History**: Track score changes over time
3. **Score Reports**: Add scoring reports in the reports page
4. **Bulk Score Entry**: Allow entering scores for multiple students at once
5. **Score Templates**: Create predefined score templates (e.g., 75, 80, 90, 100)

## Troubleshooting

### Issue: Columns not found error
**Solution**: Run the migration script in Supabase SQL Editor

### Issue: Score not saving
**Solution**: Check browser console for errors. Verify database migration was successful.

### Issue: UI not showing score panel
**Solution**: Clear browser cache and reload. Verify student status is "Tugas".

### Issue: Tugas button still hiding
**Solution**: Clear browser cache and hard reload (Ctrl+Shift+R or Cmd+Shift+R)

## Support

If you encounter any issues, check:
1. Supabase connection is active
2. Database migration completed successfully
3. Browser console for JavaScript errors
4. Network tab for API call failures

---

**Version**: 1.0.0  
**Last Updated**: January 3, 2026  
**Author**: Development Team
