-- Manual test to check if database accepts Wednesday
-- Run this step by step in XAMPP phpMyAdmin

-- Step 1: Test direct insertion with Wednesday
INSERT INTO ATTENDANCES (
    FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, 
    TimeIn, TimeOut, AttendanceStatus, Remarks
) VALUES (
    '2026-006', NULL, 16, '2026-02-04', 'Wednesday', 
    '09:30:00', NULL, 'Present', 'Manual test Wednesday'
);

-- Step 2: Check what was actually stored
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus, Remarks
FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:30:00';

-- Step 3: Clean up test record
DELETE FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:30:00';

-- Step 4: Check if there are any triggers
SHOW TRIGGERS LIKE 'ATTENDANCES%';

-- Step 5: Check column details
SELECT 
    COLUMN_NAME, 
    COLUMN_DEFAULT, 
    IS_NULLABLE, 
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'ATTENDANCES' 
AND TABLE_SCHEMA = 'faculty_attendance_db'
AND COLUMN_NAME = 'DayOfWeek';
