-- Fix the DayOfWeek column default value
-- Run this in XAMPP phpMyAdmin

-- Step 1: Remove the default 'Monday' value from DayOfWeek column
ALTER TABLE ATTENDANCES ALTER COLUMN DayOfWeek DROP DEFAULT;

-- Step 2: Verify the fix
SELECT 
    COLUMN_NAME, 
    COLUMN_DEFAULT, 
    IS_NULLABLE, 
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    EXTRA
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'ATTENDANCES' 
AND TABLE_SCHEMA = 'faculty_attendance_db'
AND COLUMN_NAME = 'DayOfWeek';

-- Step 3: Test direct insertion with Wednesday
INSERT INTO ATTENDANCES (
    FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, 
    TimeIn, TimeOut, AttendanceStatus, Remarks
) VALUES (
    '2026-006', NULL, 16, '2026-02-04', 'Wednesday', 
    '09:45:00', NULL, 'Present', 'Test after fix'
);

-- Step 4: Check what was stored
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus, Remarks
FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:45:00';

-- Step 5: Clean up test record
DELETE FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:45:00';
