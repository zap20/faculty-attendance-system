-- Manual SQL Test for DayOfWeek Column
-- Run these commands in XAMPP phpMyAdmin SQL tab

-- Step 1: Check if DayOfWeek column exists
DESCRIBE ATTENDANCES;

-- Step 2: If DayOfWeek column is missing, add it
-- (Only run this if you don't see DayOfWeek in the output above)
ALTER TABLE ATTENDANCES 
ADD COLUMN DayOfWeek VARCHAR(10) NOT NULL DEFAULT 'Monday' 
AFTER Date;

-- Step 3: Verify the column was added
DESCRIBE ATTENDANCES;

-- Step 4: Test insertion with DayOfWeek
INSERT INTO ATTENDANCES (
    FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, 
    TimeIn, TimeOut, AttendanceStatus, Remarks
) VALUES (
    '2026-006', NULL, 16, '2026-02-04', 'Wednesday', 
    '14:30:00', NULL, 'Present', 'Manual test DayOfWeek'
);

-- Step 5: Check if DayOfWeek was saved
SELECT AttendanceID, FacultyID, Date, DayOfWeek, TimeIn, AttendanceStatus 
FROM ATTENDANCES 
WHERE FacultyID = '2026-006' AND Date = '2026-02-04' 
ORDER BY AttendanceID DESC LIMIT 1;

-- Step 6: Clean up test record (if needed)
-- DELETE FROM ATTENDANCES WHERE FacultyID = '2026-006' AND Date = '2026-02-04' AND TimeIn = '14:30:00';
