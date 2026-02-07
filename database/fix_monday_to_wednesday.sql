-- Fix all Monday records for 2026-02-04 to Wednesday
-- Run this in XAMPP phpMyAdmin

-- Update all records for 2026-02-04 to have Wednesday as DayOfWeek
UPDATE ATTENDANCES 
SET DayOfWeek = 'Wednesday' 
WHERE Date = '2026-02-04' AND DayOfWeek = 'Monday';

-- Verify the fix
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus 
FROM ATTENDANCES 
WHERE Date = '2026-02-04' 
ORDER BY AttendanceID DESC;
