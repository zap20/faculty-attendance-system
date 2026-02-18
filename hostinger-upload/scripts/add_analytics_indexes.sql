-- Analytics Performance Indexes
-- Run this script to optimize queries for the Admin Analytics Dashboard

-- Attendance indexes
CREATE INDEX IF NOT EXISTS idx_attendances_date ON attendances(Date);
CREATE INDEX IF NOT EXISTS idx_attendances_status ON attendances(AttendanceStatus);
CREATE INDEX IF NOT EXISTS idx_attendances_faculty_date ON attendances(FacultyID, Date);
CREATE INDEX IF NOT EXISTS idx_attendances_schedule ON attendances(ScheduleID);

-- Faculty indexes
CREATE INDEX IF NOT EXISTS idx_faculties_department ON faculties(DepartmentID);

-- Schedule indexes
CREATE INDEX IF NOT EXISTS idx_schedules_faculty ON schedules(FacultyID);
CREATE INDEX IF NOT EXISTS idx_schedules_room ON schedules(RoomID);
CREATE INDEX IF NOT EXISTS idx_schedules_day ON schedules(DayOfWeek);
