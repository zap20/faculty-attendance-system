-- Check for any triggers or constraints that might override DayOfWeek
-- Run this in XAMPP phpMyAdmin

-- 1. Check for triggers
SHOW TRIGGERS LIKE 'ATTENDANCES%';

-- 2. Check table constraints
SELECT 
    CONSTRAINT_NAME, 
    CONSTRAINT_TYPE, 
    TABLE_NAME, 
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
WHERE TABLE_NAME = 'ATTENDANCES' 
AND TABLE_SCHEMA = 'faculty_attendance_db';

-- 3. Check for any default values
SELECT 
    COLUMN_NAME, 
    COLUMN_DEFAULT, 
    IS_NULLABLE, 
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'ATTENDANCES' 
AND TABLE_SCHEMA = 'faculty_attendance_db'
AND COLUMN_NAME = 'DayOfWeek';

-- 4. Test direct insertion
INSERT INTO ATTENDANCES (
    FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, 
    TimeIn, TimeOut, AttendanceStatus, Remarks
) VALUES (
    '2026-006', NULL, 16, '2026-02-04', 'Wednesday', 
    '09:15:00', NULL, 'Present', 'Test direct insertion'
);

-- 5. Check what was actually stored
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus, Remarks
FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:15:00';

-- 6. Clean up
DELETE FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:15:00';
