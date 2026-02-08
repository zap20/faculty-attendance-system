-- Diagnose and fix NULL DayOfWeek issues
-- Run this step by step in XAMPP phpMyAdmin

-- Step 1: Check if DayOfWeek column exists
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'ATTENDANCES' 
AND TABLE_SCHEMA = 'faculty_attendance_db'
AND COLUMN_NAME = 'DayOfWeek';

-- Step 2: Check current table structure
DESCRIBE ATTENDANCES;

-- Step 3: Check if there are any records at all
SELECT COUNT(*) as total_records FROM ATTENDANCES;

-- Step 4: Check sample records with all columns
SELECT * FROM ATTENDANCES ORDER BY AttendanceID DESC LIMIT 5;

-- Step 5: If DayOfWeek column doesn't exist, add it
-- (Only run this if Step 1 shows no results)
ALTER TABLE ATTENDANCES 
ADD COLUMN DayOfWeek VARCHAR(20) NOT NULL DEFAULT 'Monday';

-- Step 6: If DayOfWeek column exists but has NULL values, update them
UPDATE ATTENDANCES 
SET DayOfWeek = CASE 
    WHEN Date = '2026-02-03' THEN 'Tuesday'
    WHEN Date = '2026-02-04' THEN 'Wednesday'
    WHEN Date = '2026-02-05' THEN 'Thursday'
    WHEN Date = '2026-02-06' THEN 'Friday'
    WHEN Date = '2026-02-07' THEN 'Saturday'
    WHEN Date = '2026-02-08' THEN 'Sunday'
    WHEN Date = '2026-02-09' THEN 'Monday'
    ELSE DAYNAME(Date)  -- Fallback to MySQL day function
END 
WHERE DayOfWeek IS NULL OR DayOfWeek = '';

-- Step 7: Verify the fix
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus
FROM ATTENDANCES 
WHERE Date IN ('2026-02-03', '2026-02-04') 
ORDER BY Date, AttendanceID;

-- Step 8: Test with clear display
SELECT 
    AttendanceID,
    FacultyID,
    Date,
    COALESCE(DayOfWeek, 'Unknown') AS "Day Name",
    TimeIn,
    AttendanceStatus
FROM ATTENDANCES 
WHERE Date = '2026-02-04'
ORDER BY TimeIn DESC;
