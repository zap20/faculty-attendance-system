-- Fix all existing DayOfWeek values to match actual calendar days
-- Run this in XAMPP phpMyAdmin

-- Update 2026-02-03 records from Monday to Tuesday
UPDATE ATTENDANCES 
SET DayOfWeek = 'Tuesday' 
WHERE Date = '2026-02-03' AND DayOfWeek = 'Monday';

-- Update 2026-02-04 records from Monday to Wednesday  
UPDATE ATTENDANCES 
SET DayOfWeek = 'Wednesday' 
WHERE Date = '2026-02-04' AND DayOfWeek = 'Monday';

-- Verify the fixes
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus 
FROM ATTENDANCES 
WHERE Date IN ('2026-02-03', '2026-02-04') 
ORDER BY Date, AttendanceID;
