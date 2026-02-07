-- Ultimate test to find where Monday is coming from
-- Run this step by step in XAMPP phpMyAdmin

-- Step 1: Check if there are any triggers on ATTENDANCES table
SHOW TRIGGERS LIKE 'ATTENDANCES%';

-- Step 2: Check if there are any constraints that might override DayOfWeek
SELECT 
    CONSTRAINT_NAME, 
    CONSTRAINT_TYPE, 
    CHECK_CLAUSE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
WHERE TABLE_NAME = 'ATTENDANCES' 
AND TABLE_SCHEMA = 'faculty_attendance_db';

-- Step 3: Check column details for DayOfWeek
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

-- Step 4: Test direct insertion with explicit Wednesday
INSERT INTO ATTENDANCES (
    FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, 
    TimeIn, TimeOut, AttendanceStatus, Remarks
) VALUES (
    '2026-006', NULL, 16, '2026-02-04', 'Wednesday', 
    '09:40:00', NULL, 'Present', 'Ultimate test Wednesday'
);

-- Step 5: Check what was actually stored
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus, Remarks
FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:40:00';

-- Step 6: Clean up
DELETE FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:40:00';
