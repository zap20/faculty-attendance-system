-- Create a view to show attendance with clear day names
-- Run this in XAMPP phpMyAdmin

-- Create a view that shows attendance with day names clearly
CREATE OR REPLACE VIEW attendance_with_days AS
SELECT 
    a.AttendanceID,
    a.FacultyID,
    f.FacultyName,
    a.Date,
    a.DayOfWeek AS DayName,  -- This shows "Wednesday", "Thursday", etc.
    a.TimeIn,
    a.TimeOut,
    a.AttendanceStatus,
    a.Remarks,
    a.CreatedAt,
    a.UpdatedAt,
    -- Additional helpful columns
    CASE 
        WHEN a.DayOfWeek = 'Monday' THEN '📅 Monday'
        WHEN a.DayOfWeek = 'Tuesday' THEN '📅 Tuesday'
        WHEN a.DayOfWeek = 'Wednesday' THEN '📅 Wednesday'
        WHEN a.DayOfWeek = 'Thursday' THEN '📅 Thursday'
        WHEN a.DayOfWeek = 'Friday' THEN '📅 Friday'
        WHEN a.DayOfWeek = 'Saturday' THEN '📅 Saturday'
        WHEN a.DayOfWeek = 'Sunday' THEN '📅 Sunday'
        ELSE a.DayOfWeek
    END AS DayWithIcon,
    -- Format date nicely
    DATE_FORMAT(a.Date, '%M %d, %Y') AS FormattedDate,
    -- Format time nicely
    DATE_FORMAT(a.TimeIn, '%h:%i %p') AS FormattedTimeIn,
    DATE_FORMAT(a.TimeOut, '%h:%i %p') AS FormattedTimeOut
FROM ATTENDANCES a
LEFT JOIN FACULTIES f ON a.FacultyID = f.FacultyID
ORDER BY a.Date DESC, a.TimeIn DESC;

-- How to use this view:
-- SELECT * FROM attendance_with_days WHERE FacultyID = '2026-006';
-- SELECT * FROM attendance_with_days WHERE Date = '2026-02-04';
-- SELECT * FROM attendance_with_days WHERE DayName = 'Wednesday';
