-- Faculty Attendance and Monitoring System
-- Database Schema and Seed Data
-- MariaDB / MySQL

-- Create Database
CREATE DATABASE IF NOT EXISTS faculty_attendance_db;
USE faculty_attendance_db;

-- Drop tables if exist (for clean install)
DROP TABLE IF EXISTS ATTENDANCES;
DROP TABLE IF EXISTS ATTENDANCEDEVICES;
DROP TABLE IF EXISTS SCHEDULES;
DROP TABLE IF EXISTS SUBJECTS;
DROP TABLE IF EXISTS ROOMS;
DROP TABLE IF EXISTS USERACCOUNTS;
DROP TABLE IF EXISTS FACULTIES;
DROP TABLE IF EXISTS DEPARTMENTS;
DROP TABLE IF EXISTS AUTH_TOKENS;

-- DEPARTMENTS Table
CREATE TABLE DEPARTMENTS (
    DepartmentID INT AUTO_INCREMENT PRIMARY KEY,
    DepartmentName VARCHAR(100) NOT NULL,
    DepartmentHead VARCHAR(100) NULL,
    DepartmentDean VARCHAR(100) NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- FACULTIES Table
CREATE TABLE FACULTIES (
    FacultyID VARCHAR(20) PRIMARY KEY,
    FacultyName VARCHAR(100) NOT NULL,
    DepartmentID INT NOT NULL,
    Position VARCHAR(50) NOT NULL,
    EmploymentStatus VARCHAR(50) NOT NULL,
    ContactInformation VARCHAR(255) NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (DepartmentID) REFERENCES DEPARTMENTS(DepartmentID) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- USERACCOUNTS Table
CREATE TABLE USERACCOUNTS (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    Username VARCHAR(50) NOT NULL UNIQUE,
    Password VARCHAR(255) NOT NULL,
    Role ENUM('Admin', 'AttendanceOfficer', 'Faculty', 'DepartmentHead') NOT NULL,
    FacultyID VARCHAR(20) NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (FacultyID) REFERENCES FACULTIES(FacultyID) ON DELETE SET NULL
) ENGINE=InnoDB;

-- AUTH_TOKENS Table (for token-based authentication)
CREATE TABLE AUTH_TOKENS (
    TokenID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    Token VARCHAR(255) NOT NULL UNIQUE,
    ExpiresAt DATETIME NOT NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserID) REFERENCES USERACCOUNTS(UserID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ROOMS Table
CREATE TABLE ROOMS (
    RoomID INT AUTO_INCREMENT PRIMARY KEY,
    RoomName VARCHAR(50) NOT NULL,
    Building VARCHAR(100) NOT NULL,
    Capacity INT NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- SUBJECTS Table
CREATE TABLE SUBJECTS (
    SubjectID INT AUTO_INCREMENT PRIMARY KEY,
    SubjectName VARCHAR(100) NOT NULL,
    CourseCode VARCHAR(20) NOT NULL,
    Units INT NOT NULL,
    DepartmentID INT NOT NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (DepartmentID) REFERENCES DEPARTMENTS(DepartmentID) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- SCHEDULES Table
CREATE TABLE SCHEDULES (
    ScheduleID INT AUTO_INCREMENT PRIMARY KEY,
    FacultyID VARCHAR(20) NOT NULL,
    SubjectID INT NOT NULL,
    RoomID INT NOT NULL,
    DayOfWeek VARCHAR(10) NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (FacultyID) REFERENCES FACULTIES(FacultyID) ON DELETE CASCADE,
    FOREIGN KEY (SubjectID) REFERENCES SUBJECTS(SubjectID) ON DELETE CASCADE,
    FOREIGN KEY (RoomID) REFERENCES ROOMS(RoomID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ATTENDANCEDEVICES Table
CREATE TABLE ATTENDANCEDEVICES (
    DeviceID INT AUTO_INCREMENT PRIMARY KEY,
    DeviceType VARCHAR(50) NOT NULL,
    Location VARCHAR(100) NOT NULL,
    RoomID INT NULL,
    Status ENUM('Active', 'Inactive') DEFAULT 'Active',
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (RoomID) REFERENCES ROOMS(RoomID) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ATTENDANCES Table
CREATE TABLE ATTENDANCES (
    AttendanceID INT AUTO_INCREMENT PRIMARY KEY,
    FacultyID VARCHAR(20) NOT NULL,
    DeviceID INT NULL,
    ScheduleID INT NULL,
    Date DATE NOT NULL,
    DayOfWeek VARCHAR(10) NOT NULL,
    TimeIn TIME NULL,
    TimeOut TIME NULL,
    AttendanceStatus VARCHAR(50) NOT NULL,
    Remarks TEXT NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (FacultyID) REFERENCES FACULTIES(FacultyID) ON DELETE CASCADE,
    FOREIGN KEY (DeviceID) REFERENCES ATTENDANCEDEVICES(DeviceID) ON DELETE SET NULL,
    FOREIGN KEY (ScheduleID) REFERENCES SCHEDULES(ScheduleID) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Create indexes for better performance
CREATE INDEX idx_schedules_faculty ON SCHEDULES(FacultyID);
CREATE INDEX idx_schedules_day ON SCHEDULES(DayOfWeek);
CREATE INDEX idx_attendances_date ON ATTENDANCES(Date);
CREATE INDEX idx_attendances_faculty ON ATTENDANCES(FacultyID);
CREATE INDEX idx_attendances_day_of_week ON ATTENDANCES(DayOfWeek);
CREATE INDEX idx_auth_tokens_token ON AUTH_TOKENS(Token);

-- =====================================================
-- SEED DATA
-- =====================================================

-- Insert Departments
INSERT INTO DEPARTMENTS (DepartmentName, DepartmentHead, DepartmentDean) VALUES
('Computer Science', 'Dr. John Smith', 'Dr. Emily Johnson'),
('Information Technology', 'Dr. Sarah Williams', 'Dr. Emily Johnson'),
('Mathematics', 'Dr. Michael Brown', 'Dr. Robert Davis'),
('Engineering', 'Dr. Lisa Anderson', 'Dr. Robert Davis'),
('Business Administration', 'Dr. James Wilson', 'Dr. Patricia Martinez');

-- Insert Faculties
INSERT INTO FACULTIES (FacultyID, FacultyName, DepartmentID, Position, EmploymentStatus, ContactInformation) VALUES
('2026-001', 'Dr. John Smith', 1, 'Professor', 'Full-time', 'john.smith@university.edu'),
('2026-002', 'Prof. Maria Garcia', 1, 'Associate Professor', 'Full-time', 'maria.garcia@university.edu'),
('2026-003', 'Mr. David Lee', 1, 'Instructor', 'Part-time', 'david.lee@university.edu'),
('2026-004', 'Dr. Sarah Williams', 2, 'Professor', 'Full-time', 'sarah.williams@university.edu'),
('2026-005', 'Ms. Jennifer Taylor', 2, 'Assistant Professor', 'Full-time', 'jennifer.taylor@university.edu'),
('2026-006', 'Dr. Michael Brown', 3, 'Professor', 'Full-time', 'michael.brown@university.edu'),
('2026-007', 'Mr. Robert Chen', 3, 'Instructor', 'Part-time', 'robert.chen@university.edu'),
('2026-008', 'Dr. Lisa Anderson', 4, 'Professor', 'Full-time', 'lisa.anderson@university.edu'),
('2026-009', 'Dr. James Wilson', 5, 'Professor', 'Full-time', 'james.wilson@university.edu'),
('2026-010', 'Ms. Amanda White', 5, 'Instructor', 'Full-time', 'amanda.white@university.edu');

-- Insert User Accounts (passwords are hashed using password_hash with PASSWORD_DEFAULT)
-- Default password for all users: "password123"
INSERT INTO USERACCOUNTS (Username, Password, Role, FacultyID) VALUES
('admin', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'Admin', NULL),
('officer1', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'AttendanceOfficer', NULL),
('john.smith', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'DepartmentHead', '2026-001'),
('maria.garcia', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'Faculty', '2026-002'),
('david.lee', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'Faculty', '2026-003'),
('sarah.williams', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'DepartmentHead', '2026-004'),
('jennifer.taylor', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'Faculty', '2026-005'),
('michael.brown', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'DepartmentHead', '2026-006'),
('james.wilson', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'DepartmentHead', '2026-009'),
('amanda.white', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'Faculty', '2026-010');

-- Insert Rooms
INSERT INTO ROOMS (RoomName, Building, Capacity) VALUES
('Room 101', 'Main Building', 40),
('Room 102', 'Main Building', 35),
('Room 201', 'Main Building', 50),
('Room 202', 'Main Building', 45),
('Lab 1', 'Science Building', 30),
('Lab 2', 'Science Building', 30),
('Lab 3', 'Science Building', 25),
('Lecture Hall A', 'Auditorium', 200),
('Lecture Hall B', 'Auditorium', 150),
('Room 301', 'Business Building', 40);

-- Insert Subjects
INSERT INTO SUBJECTS (SubjectName, CourseCode, Units, DepartmentID) VALUES
('Introduction to Programming', 'CS101', 3, 1),
('Data Structures', 'CS201', 3, 1),
('Database Management', 'CS301', 3, 1),
('Web Development', 'IT101', 3, 2),
('Network Administration', 'IT201', 3, 2),
('Calculus I', 'MATH101', 4, 3),
('Linear Algebra', 'MATH201', 3, 3),
('Engineering Mechanics', 'ENG101', 4, 4),
('Principles of Management', 'BA101', 3, 5),
('Financial Accounting', 'BA201', 3, 5);

-- Insert Schedules (Monday to Friday schedules)
INSERT INTO SCHEDULES (FacultyID, SubjectID, RoomID, DayOfWeek, StartTime, EndTime) VALUES
-- Dr. John Smith (CS)
('2026-001', 1, 5, 'Monday', '08:00:00', '10:00:00'),
('2026-001', 1, 5, 'Wednesday', '08:00:00', '10:00:00'),
('2026-001', 2, 5, 'Tuesday', '10:00:00', '12:00:00'),
('2026-001', 2, 5, 'Thursday', '10:00:00', '12:00:00'),
-- Prof. Maria Garcia (CS)
('2026-002', 2, 6, 'Monday', '13:00:00', '15:00:00'),
('2026-002', 3, 6, 'Wednesday', '13:00:00', '15:00:00'),
('2026-002', 3, 6, 'Friday', '10:00:00', '12:00:00'),
-- Mr. David Lee (CS)
('2026-003', 1, 1, 'Tuesday', '08:00:00', '10:00:00'),
('2026-003', 1, 1, 'Thursday', '08:00:00', '10:00:00'),
-- Dr. Sarah Williams (IT)
('2026-004', 4, 7, 'Monday', '10:00:00', '12:00:00'),
('2026-004', 4, 7, 'Wednesday', '10:00:00', '12:00:00'),
('2026-004', 5, 7, 'Friday', '13:00:00', '15:00:00'),
-- Ms. Jennifer Taylor (IT)
('2026-005', 4, 2, 'Tuesday', '13:00:00', '15:00:00'),
('2026-005', 5, 2, 'Thursday', '13:00:00', '15:00:00'),
-- Dr. Michael Brown (Math)
('2026-006', 6, 8, 'Monday', '08:00:00', '10:00:00'),
('2026-006', 6, 8, 'Wednesday', '08:00:00', '10:00:00'),
('2026-006', 7, 3, 'Friday', '08:00:00', '10:00:00'),
-- Dr. James Wilson (Business)
('2026-009', 9, 10, 'Tuesday', '10:00:00', '12:00:00'),
('2026-009', 9, 10, 'Thursday', '10:00:00', '12:00:00'),
-- Ms. Amanda White (Business)
('2026-010', 10, 10, 'Monday', '14:00:00', '16:00:00'),
('2026-010', 10, 10, 'Wednesday', '14:00:00', '16:00:00');

-- Insert Attendance Devices
INSERT INTO ATTENDANCEDEVICES (DeviceType, Location, RoomID, Status) VALUES
('Biometric Scanner', 'Room 101 Entrance', 1, 'Active'),
('Biometric Scanner', 'Room 102 Entrance', 2, 'Active'),
('RFID Reader', 'Room 201 Entrance', 3, 'Active'),
('RFID Reader', 'Room 202 Entrance', 4, 'Active'),
('Biometric Scanner', 'Lab 1 Entrance', 5, 'Active'),
('Biometric Scanner', 'Lab 2 Entrance', 6, 'Active'),
('Biometric Scanner', 'Lab 3 Entrance', 7, 'Active'),
('RFID Reader', 'Lecture Hall A Entrance', 8, 'Active'),
('RFID Reader', 'Lecture Hall B Entrance', 9, 'Inactive'),
('Biometric Scanner', 'Room 301 Entrance', 10, 'Active');

-- Insert Sample Attendance Records
INSERT INTO ATTENDANCES (FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, TimeIn, TimeOut, AttendanceStatus, Remarks) VALUES
('2026-001', 5, 1, CURDATE(), DAYNAME(CURDATE()), '07:55:00', '10:05:00', 'Present', 'On time'),
('2026-002', 6, 5, CURDATE(), DAYNAME(CURDATE()), '13:05:00', '15:00:00', 'Present', 'On time'),
('2026-004', 7, 10, CURDATE(), DAYNAME(CURDATE()), '10:15:00', '12:00:00', 'Late', 'Arrived 15 minutes late'),
('2026-006', 8, 15, CURDATE(), DAYNAME(CURDATE()), '08:00:00', NULL, 'Present', 'Currently in class');

DROP TRIGGER IF EXISTS trg_attendances_dayofweek_bi;
DROP TRIGGER IF EXISTS trg_attendances_dayofweek_bu;

DELIMITER $$
CREATE TRIGGER trg_attendances_dayofweek_bi
BEFORE INSERT ON ATTENDANCES
FOR EACH ROW
BEGIN
  IF NEW.DayOfWeek IS NULL OR NEW.DayOfWeek = '' THEN
    SET NEW.DayOfWeek = DAYNAME(NEW.Date);
  END IF;
END$$

CREATE TRIGGER trg_attendances_dayofweek_bu
BEFORE UPDATE ON ATTENDANCES
FOR EACH ROW
BEGIN
  IF NEW.DayOfWeek IS NULL OR NEW.DayOfWeek = '' THEN
    SET NEW.DayOfWeek = DAYNAME(NEW.Date);
  END IF;
END$$
DELIMITER ;
