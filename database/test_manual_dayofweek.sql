-- Test manual entry DayOfWeek insertion
-- Run this in XAMPP phpMyAdmin to check what's happening

-- Step 1: Check current DayOfWeek column status
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'ATTENDANCES' 
AND TABLE_SCHEMA = 'faculty_attendance_db'
AND COLUMN_NAME = 'DayOfWeek';

-- Step 2: Check recent records to see what's being inserted
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus, Remarks
FROM ATTENDANCES 
ORDER BY AttendanceID DESC 
LIMIT 10;

-- Step 3: Test direct insertion with manual DayOfWeek
INSERT INTO ATTENDANCES (
    FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, 
    TimeIn, TimeOut, AttendanceStatus, Remarks
) VALUES (
    '2026-006', NULL, 16, '2026-02-04', 'Wednesday', 
    '10:20:00', NULL, 'Present', 'Manual test - Wednesday'
);

-- Step 4: Check if the test record was inserted correctly
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus, Remarks
FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '10:20:00';

-- Step 5: Clean up test record
DELETE FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '10:20:00';

-- Step 6: If still NULL, try to fix the column
ALTER TABLE ATTENDANCES 
MODIFY COLUMN DayOfWeek VARCHAR(20) NOT NULL DEFAULT 'Monday';

-- Step 7: Test again after fix
INSERT INTO ATTENDANCES (
    FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, 
    TimeIn, TimeOut, AttendanceStatus, Remarks
) VALUES (
    '2026-006', NULL, 16, '2026-02-04', 'Wednesday', 
    '10:25:00', NULL, 'Present', 'Manual test after fix - Wednesday'
);

-- Step 8: Check final result
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus, Remarks
FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '10:25:00';
