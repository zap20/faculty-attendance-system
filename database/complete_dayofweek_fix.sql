-- Complete fix for NULL DayOfWeek - Run this entire script in XAMPP phpMyAdmin

-- Step 1: First, let's see what we're working with
SELECT 'Current table structure:' as info;
DESCRIBE ATTENDANCES;

-- Step 2: Check if DayOfWeek column exists
SELECT 'Checking DayOfWeek column:' as info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'ATTENDANCES' 
AND TABLE_SCHEMA = 'faculty_attendance_db'
AND COLUMN_NAME = 'DayOfWeek';

-- Step 3: Add DayOfWeek column if it doesn't exist
-- This will show an error if column already exists - that's OK
ALTER TABLE ATTENDANCES 
ADD COLUMN IF NOT EXISTS DayOfWeek VARCHAR(20) DEFAULT 'Monday';

-- Step 4: Update all NULL or empty DayOfWeek values
UPDATE ATTENDANCES 
SET DayOfWeek = CASE 
    WHEN Date = '2026-02-03' THEN 'Tuesday'
    WHEN Date = '2026-02-04' THEN 'Wednesday'
    WHEN Date = '2026-02-05' THEN 'Thursday'
    WHEN Date = '2026-02-06' THEN 'Friday'
    WHEN Date = '2026-02-07' THEN 'Saturday'
    WHEN Date = '2026-02-08' THEN 'Sunday'
    WHEN Date = '2026-02-09' THEN 'Monday'
    WHEN Date = '2026-02-10' THEN 'Tuesday'
    WHEN Date = '2026-02-11' THEN 'Wednesday'
    WHEN Date = '2026-02-12' THEN 'Thursday'
    WHEN Date = '2026-02-13' THEN 'Friday'
    WHEN Date = '2026-02-14' THEN 'Saturday'
    WHEN Date = '2026-02-15' THEN 'Sunday'
    WHEN Date = '2026-02-16' THEN 'Monday'
    ELSE DAYNAME(Date)  -- Use MySQL's built-in function as fallback
END 
WHERE DayOfWeek IS NULL OR DayOfWeek = '' OR DayOfWeek = 'Monday';

-- Step 5: Make sure the column is NOT NULL
ALTER TABLE ATTENDANCES 
MODIFY COLUMN DayOfWeek VARCHAR(20) NOT NULL;

-- Step 6: Verify the fix
SELECT 'Verification - Updated records:' as info;
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus
FROM ATTENDANCES 
WHERE Date IN ('2026-02-03', '2026-02-04', '2026-02-05') 
ORDER BY Date, AttendanceID;

-- Step 7: Show final result with clear day names
SELECT 'Final result with clear display:' as info;
SELECT 
    AttendanceID,
    FacultyID,
    Date,
    DayOfWeek AS "Day Name",
    TimeIn,
    AttendanceStatus,
    CASE 
        WHEN DayOfWeek = 'Monday' THEN '📅 Monday'
        WHEN DayOfWeek = 'Tuesday' THEN '📅 Tuesday'
        WHEN DayOfWeek = 'Wednesday' THEN '📅 Wednesday'
        WHEN DayOfWeek = 'Thursday' THEN '📅 Thursday'
        WHEN DayOfWeek = 'Friday' THEN '📅 Friday'
        WHEN DayOfWeek = 'Saturday' THEN '📅 Saturday'
        WHEN DayOfWeek = 'Sunday' THEN '📅 Sunday'
        ELSE DayOfWeek
    END AS "Day with Icon"
FROM ATTENDANCES 
WHERE Date = '2026-02-04'
ORDER BY TimeIn DESC;
