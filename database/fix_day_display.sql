-- Comprehensive fix for DayOfWeek display issues
-- Run this step by step in XAMPP phpMyAdmin

-- Step 1: Check current DayOfWeek values
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus
FROM ATTENDANCES 
WHERE Date = '2026-02-04' 
ORDER BY AttendanceID DESC;

-- Step 2: Update all 2026-02-04 records to show Wednesday (correct day)
UPDATE ATTENDANCES 
SET DayOfWeek = 'Wednesday' 
WHERE Date = '2026-02-04' AND DayOfWeek = 'Monday';

-- Step 3: Update all 2026-02-03 records to show Tuesday (correct day)
UPDATE ATTENDANCES 
SET DayOfWeek = 'Tuesday' 
WHERE Date = '2026-02-03' AND DayOfWeek = 'Monday';

-- Step 4: Verify the updates
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus
FROM ATTENDANCES 
WHERE Date IN ('2026-02-03', '2026-02-04') 
ORDER BY Date, AttendanceID;

-- Step 5: Create a simple query to show day names clearly
SELECT 
    AttendanceID,
    FacultyID,
    Date,
    DayOfWeek AS "Day Name",
    TimeIn,
    AttendanceStatus,
    Remarks
FROM ATTENDANCES 
WHERE Date = '2026-02-04'
ORDER BY TimeIn DESC;

-- Step 6: Alternative query with formatted display
SELECT 
    AttendanceID,
    FacultyID,
    Date,
    CASE 
        WHEN DayOfWeek = 'Monday' THEN '📅 Monday'
        WHEN DayOfWeek = 'Tuesday' THEN '📅 Tuesday'
        WHEN DayOfWeek = 'Wednesday' THEN '📅 Wednesday'
        WHEN DayOfWeek = 'Thursday' THEN '📅 Thursday'
        WHEN DayOfWeek = 'Friday' THEN '📅 Friday'
        WHEN DayOfWeek = 'Saturday' THEN '📅 Saturday'
        WHEN DayOfWeek = 'Sunday' THEN '📅 Sunday'
        ELSE DayOfWeek
    END AS "Day with Icon",
    TimeIn,
    AttendanceStatus
FROM ATTENDANCES 
WHERE Date = '2026-02-04'
ORDER BY TimeIn DESC;
