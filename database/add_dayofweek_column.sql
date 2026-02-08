-- Add DayOfWeek column to ATTENDANCES table
-- Run this in XAMPP phpMyAdmin or MySQL console

USE faculty_attendance_db;

-- Add DayOfWeek column to ATTENDANCES table
ALTER TABLE ATTENDANCES 
ADD COLUMN DayOfWeek VARCHAR(10) NOT NULL DEFAULT 'Monday' 
AFTER Date;

-- Add index for better performance on DayOfWeek queries
CREATE INDEX idx_attendances_day_of_week ON ATTENDANCES(DayOfWeek);

-- Verify the column was added
DESCRIBE ATTENDANCES;
