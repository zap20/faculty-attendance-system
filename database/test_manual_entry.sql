-- Test manual entry DayOfWeek calculation
-- Run this in XAMPP phpMyAdmin

-- Test direct insertion with current date (2026-02-04) and correct day (Wednesday)
INSERT INTO ATTENDANCES (
    FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, 
    TimeIn, TimeOut, AttendanceStatus, Remarks
) VALUES (
    '2026-006', 8, 15, '2026-02-04', 'Wednesday', 
    '09:55:00', NULL, 'Present', 'Manual entry test - Wednesday'
);

-- Check what was stored
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus, Remarks
FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:55:00';

-- Clean up test record
DELETE FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '09:55:00';
