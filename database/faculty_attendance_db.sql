-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Feb 13, 2026 at 05:16 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `faculty_attendance_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `attendancedevices`
--

CREATE TABLE `attendancedevices` (
  `DeviceID` int(11) NOT NULL,
  `DeviceType` varchar(50) NOT NULL,
  `Location` varchar(100) NOT NULL,
  `RoomID` int(11) DEFAULT NULL,
  `Status` enum('Active','Inactive') DEFAULT 'Active',
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `UpdatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `attendancedevices`
--

INSERT INTO `attendancedevices` (`DeviceID`, `DeviceType`, `Location`, `RoomID`, `Status`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'Biometric Scanner', 'Room 101 Entrance', 1, 'Active', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(2, 'Biometric Scanner', 'Room 102 Entrance', 2, 'Active', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(3, 'RFID Reader', 'Room 201 Entrance', 3, 'Active', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(4, 'RFID Reader', 'Room 202 Entrance', 4, 'Active', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(5, 'Biometric Scanner', 'Lab 1 Entrance', 5, 'Active', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(6, 'Biometric Scanner', 'Lab 2 Entrance', 6, 'Active', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(7, 'Biometric Scanner', 'Lab 3 Entrance', 7, 'Active', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(8, 'RFID Reader', 'Lecture Hall A Entrance', 8, 'Active', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(9, 'RFID Reader', 'Lecture Hall B Entrance', 9, 'Inactive', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(10, 'Biometric Scanner', 'Room 301 Entrance', 10, 'Active', '2026-02-02 16:35:47', '2026-02-02 16:35:47');

-- --------------------------------------------------------

--
-- Table structure for table `attendances`
--

CREATE TABLE `attendances` (
  `AttendanceID` int(11) NOT NULL,
  `FacultyID` varchar(20) NOT NULL,
  `DeviceID` int(11) DEFAULT NULL,
  `ScheduleID` int(11) DEFAULT NULL,
  `Date` date NOT NULL,
  `DayOfWeek` varchar(20) NOT NULL,
  `TimeIn` time DEFAULT NULL,
  `TimeOut` time DEFAULT NULL,
  `AttendanceStatus` varchar(50) NOT NULL,
  `Remarks` text DEFAULT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `UpdatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `attendances`
--

INSERT INTO `attendances` (`AttendanceID`, `FacultyID`, `DeviceID`, `ScheduleID`, `Date`, `DayOfWeek`, `TimeIn`, `TimeOut`, `AttendanceStatus`, `Remarks`, `CreatedAt`, `UpdatedAt`) VALUES
(3, '2026-001', 5, 1, '2026-02-04', '', '07:55:00', '10:05:00', 'Present', 'On time', '2026-02-04 02:16:35', '2026-02-04 02:16:35'),
(4, '2026-002', 6, 5, '2026-02-04', '', '13:05:00', '15:00:00', 'Present', 'On time', '2026-02-04 02:16:35', '2026-02-04 02:16:35'),
(5, '2026-004', 7, 10, '2026-02-04', '', '10:15:00', '12:00:00', 'Late', 'Arrived 15 minutes late', '2026-02-04 02:16:35', '2026-02-04 02:16:35'),
(28, '2026-003', NULL, 9, '2026-02-05', 'Thursday', '08:02:21', NULL, 'Present', 'On time for Introduction to Programming. Recorded via QR scan by officer1', '2026-02-05 00:02:21', '2026-02-05 00:02:21');

--
-- Triggers `attendances`
--
DELIMITER $$
CREATE TRIGGER `trg_attendances_dayofweek_bi` BEFORE INSERT ON `attendances` FOR EACH ROW BEGIN
  IF NEW.DayOfWeek IS NULL OR NEW.DayOfWeek = '' THEN
    SET NEW.DayOfWeek = DAYNAME(NEW.Date);
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_attendances_dayofweek_bu` BEFORE UPDATE ON `attendances` FOR EACH ROW BEGIN
  IF NEW.DayOfWeek IS NULL OR NEW.DayOfWeek = '' THEN
    SET NEW.DayOfWeek = DAYNAME(NEW.Date);
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `auth_tokens`
--

CREATE TABLE `auth_tokens` (
  `TokenID` int(11) NOT NULL,
  `UserID` int(11) NOT NULL,
  `Token` varchar(255) NOT NULL,
  `ExpiresAt` datetime NOT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `auth_tokens`
--

INSERT INTO `auth_tokens` (`TokenID`, `UserID`, `Token`, `ExpiresAt`, `CreatedAt`) VALUES
(145, 2, 'be6ce2408fd1ff4d0a82ce46b71479e7229187e415530cbe2a7cfbe732cfae1b', '2026-02-15 19:38:29', '2026-02-14 11:38:29'),
(146, 1, '90b4494b3020b42a2a1449c9d3d714ae08fe287f1b558faaa1a987179e5bc488', '2026-02-15 19:38:59', '2026-02-14 11:38:59');

-- --------------------------------------------------------

--
-- Table structure for table `departments`
--

CREATE TABLE `departments` (
  `DepartmentID` int(11) NOT NULL,
  `DepartmentName` varchar(100) NOT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `UpdatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `DepartmentDeanID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `departments`
--

INSERT INTO `departments` (`DepartmentID`, `DepartmentName`, `CreatedAt`, `UpdatedAt`, `DepartmentDeanID`) VALUES
(1, 'Computer Science', '2026-02-02 16:35:47', '2026-02-10 11:34:58', 1),
(2, 'Information Technology', '2026-02-02 16:35:47', '2026-02-10 11:34:58', 2),
(3, 'Mathematics', '2026-02-02 16:35:47', '2026-02-10 11:34:58', 3),
(4, 'Engineering', '2026-02-02 16:35:47', '2026-02-10 11:34:58', 4),
(5, 'Business Administration', '2026-02-02 16:35:47', '2026-02-10 11:34:58', 5);

-- --------------------------------------------------------

--
-- Table structure for table `department_deans`
--

CREATE TABLE `department_deans` (
  `DepartmentDeanID` int(11) NOT NULL,
  `DepartmentID` int(11) NOT NULL,
  `FirstName` varchar(100) NOT NULL,
  `LastName` varchar(100) NOT NULL,
  `Email` varchar(255) DEFAULT NULL,
  `Phone` varchar(50) DEFAULT NULL,
  `AppointmentDate` date NOT NULL,
  `IsActive` tinyint(1) DEFAULT 1,
  `Notes` text DEFAULT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `UpdatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `department_deans`
--

INSERT INTO `department_deans` (`DepartmentDeanID`, `DepartmentID`, `FirstName`, `LastName`, `Email`, `Phone`, `AppointmentDate`, `IsActive`, `Notes`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 1, 'Alan', 'Turing', 'alan.turing@university.edu', '555-0101', '2025-01-15', 1, 'Founding Dean of Computer Science', '2026-02-10 11:34:13', '2026-02-10 11:34:13'),
(2, 2, 'Tim', 'Berners-Lee', 'tim.berners-lee@university.edu', '555-0102', '2025-01-15', 1, 'Dean of Information Technology', '2026-02-10 11:34:13', '2026-02-10 11:34:13'),
(3, 3, 'Carl', 'Gauss', 'carl.gauss@university.edu', '555-0103', '2025-02-01', 1, 'Mathematics Department Dean', '2026-02-10 11:34:13', '2026-02-10 11:34:13'),
(4, 4, 'Nikola', 'Tesla', 'nikola.tesla@university.edu', '555-0104', '2025-02-01', 1, 'Engineering Department Dean', '2026-02-10 11:34:13', '2026-02-10 11:34:13'),
(5, 5, 'Peter', 'Drucker', 'peter.drucker@university.edu', '555-0105', '2025-02-10', 1, 'Business Administration Dean', '2026-02-10 11:34:13', '2026-02-10 11:34:13');

-- --------------------------------------------------------

--
-- Table structure for table `faculties`
--

CREATE TABLE `faculties` (
  `FacultyID` varchar(20) NOT NULL,
  `FacultyName` varchar(100) NOT NULL,
  `DepartmentID` int(11) NOT NULL,
  `Position` varchar(50) NOT NULL,
  `EmploymentStatus` varchar(50) NOT NULL,
  `ContactInformation` varchar(255) DEFAULT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `UpdatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `faculties`
--

INSERT INTO `faculties` (`FacultyID`, `FacultyName`, `DepartmentID`, `Position`, `EmploymentStatus`, `ContactInformation`, `CreatedAt`, `UpdatedAt`) VALUES
('2026-001', 'Dr. John Smith', 1, 'Professor', 'Full-time', 'john.smith@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
('2026-002', 'Prof. Maria Garcia', 1, 'Associate Professor', 'Full-time', 'maria.garcia@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
('2026-003', 'Mr. David Lee', 1, 'Instructor', 'Part-time', 'david.lee@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
('2026-004', 'Dr. Sarah Williams', 2, 'Professor', 'Full-time', 'sarah.williams@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
('2026-005', 'Ms. Jennifer Taylor', 2, 'Assistant Professor', 'Full-time', 'jennifer.taylor@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
('2026-006', 'Dr. Michael Brown', 3, 'Professor', 'Full-time', 'michael.brown@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
('2026-007', 'Mr. Robert Chen', 3, 'Instructor', 'Part-time', 'robert.chen@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
('2026-008', 'Dr. Lisa Anderson', 4, 'Professor', 'Full-time', 'lisa.anderson@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
('2026-009', 'Dr. James Wilson', 5, 'Professor', 'Full-time', 'james.wilson@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
('2026-010', 'Ms. Amanda White', 5, 'Instructor', 'Full-time', 'amanda.white@university.edu', '2026-02-02 16:35:47', '2026-02-02 16:35:47');

-- --------------------------------------------------------

--
-- Table structure for table `rooms`
--

CREATE TABLE `rooms` (
  `RoomID` int(11) NOT NULL,
  `RoomName` varchar(50) NOT NULL,
  `Building` varchar(100) NOT NULL,
  `Capacity` int(11) DEFAULT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `UpdatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `rooms`
--

INSERT INTO `rooms` (`RoomID`, `RoomName`, `Building`, `Capacity`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'Room 101', 'Main Building', 40, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(2, 'Room 102', 'Main Building', 35, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(3, 'Room 201', 'Main Building', 50, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(4, 'Room 202', 'Main Building', 45, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(5, 'Lab 1', 'Science Building', 30, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(6, 'Lab 2', 'Science Building', 30, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(7, 'Lab 3', 'Science Building', 25, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(8, 'Lecture Hall A', 'Auditorium', 200, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(9, 'Lecture Hall B', 'Auditorium', 150, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(10, 'Room 301', 'Business Building', 40, '2026-02-02 16:35:47', '2026-02-02 16:35:47');

-- --------------------------------------------------------

--
-- Table structure for table `schedules`
--

CREATE TABLE `schedules` (
  `ScheduleID` int(11) NOT NULL,
  `FacultyID` varchar(20) NOT NULL,
  `SubjectID` int(11) NOT NULL,
  `RoomID` int(11) NOT NULL,
  `DayOfWeek` varchar(10) NOT NULL,
  `StartTime` time NOT NULL,
  `EndTime` time NOT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `UpdatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `schedules`
--

INSERT INTO `schedules` (`ScheduleID`, `FacultyID`, `SubjectID`, `RoomID`, `DayOfWeek`, `StartTime`, `EndTime`, `CreatedAt`, `UpdatedAt`) VALUES
(1, '2026-001', 1, 5, 'Monday', '08:00:00', '10:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(2, '2026-001', 1, 5, 'Wednesday', '08:00:00', '10:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(3, '2026-001', 2, 5, 'Monday', '10:00:00', '12:00:00', '2026-02-02 16:35:47', '2026-02-03 08:23:21'),
(4, '2026-001', 2, 5, 'Thursday', '10:00:00', '12:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(5, '2026-002', 2, 6, 'Monday', '13:00:00', '15:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(6, '2026-002', 3, 6, 'Wednesday', '13:00:00', '15:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(7, '2026-002', 3, 6, 'Friday', '10:00:00', '12:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(8, '2026-003', 1, 1, 'Tuesday', '08:00:00', '10:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(9, '2026-003', 1, 1, 'Thursday', '08:00:00', '10:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(10, '2026-004', 4, 7, 'Monday', '10:00:00', '12:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(11, '2026-004', 4, 7, 'Wednesday', '10:00:00', '12:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(12, '2026-004', 5, 7, 'Friday', '13:00:00', '15:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(13, '2026-005', 4, 2, 'Tuesday', '13:00:00', '15:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(14, '2026-005', 5, 2, 'Thursday', '13:00:00', '15:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(15, '2026-006', 6, 8, 'Monday', '09:00:00', '10:30:00', '2026-02-02 16:35:47', '2026-02-04 00:48:40'),
(16, '2026-006', 6, 8, 'Wednesday', '08:00:00', '10:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(17, '2026-006', 7, 3, 'Friday', '08:00:00', '10:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(18, '2026-009', 9, 10, 'Tuesday', '10:00:00', '12:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(19, '2026-009', 9, 10, 'Thursday', '10:00:00', '12:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(20, '2026-010', 10, 10, 'Monday', '14:00:00', '16:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(21, '2026-010', 10, 10, 'Wednesday', '14:00:00', '16:00:00', '2026-02-02 16:35:47', '2026-02-02 16:35:47');

-- --------------------------------------------------------

--
-- Table structure for table `subjects`
--

CREATE TABLE `subjects` (
  `SubjectID` int(11) NOT NULL,
  `SubjectName` varchar(100) NOT NULL,
  `CourseCode` varchar(20) NOT NULL,
  `Units` int(11) NOT NULL,
  `DepartmentID` int(11) NOT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `UpdatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `subjects`
--

INSERT INTO `subjects` (`SubjectID`, `SubjectName`, `CourseCode`, `Units`, `DepartmentID`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'Introduction to Programming', 'CS101', 3, 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(2, 'Data Structures', 'CS201', 3, 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(3, 'Database Management', 'CS301', 3, 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(4, 'Web Development', 'IT101', 3, 2, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(5, 'Network Administration', 'IT201', 3, 2, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(6, 'Calculus I', 'MATH101', 4, 3, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(7, 'Linear Algebra', 'MATH201', 3, 3, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(8, 'Engineering Mechanics', 'ENG101', 4, 4, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(9, 'Principles of Management', 'BA101', 3, 5, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(10, 'Financial Accounting', 'BA201', 3, 5, '2026-02-02 16:35:47', '2026-02-02 16:35:47');

-- --------------------------------------------------------

--
-- Table structure for table `useraccounts`
--

CREATE TABLE `useraccounts` (
  `UserID` int(11) NOT NULL,
  `Username` varchar(50) NOT NULL,
  `Password` varchar(255) NOT NULL,
  `Role` enum('Admin','AttendanceOfficer','Faculty','DepartmentHead') NOT NULL,
  `FacultyID` varchar(20) DEFAULT NULL,
  `IsActive` tinyint(1) DEFAULT 1,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `UpdatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `useraccounts`
--

INSERT INTO `useraccounts` (`UserID`, `Username`, `Password`, `Role`, `FacultyID`, `IsActive`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'admin', '$2y$12$GcioK6SCGnpTT8pg8mBfQe6uwPRb5fFWiGpN9ig0xbC3XaUAGhd8K', 'Admin', NULL, 1, '2026-02-02 16:35:47', '2026-02-04 01:52:21'),
(2, 'officer1', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'AttendanceOfficer', NULL, 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(3, 'john.smith', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'DepartmentHead', '2026-001', 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(4, 'maria.garcia', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'Faculty', '2026-002', 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(5, 'david.lee', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'Faculty', '2026-003', 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(6, 'sarah.williams', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'DepartmentHead', '2026-004', 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(7, 'jennifer.taylor', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'Faculty', '2026-005', 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(8, 'michael.brown', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'DepartmentHead', '2026-006', 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(9, 'james.wilson', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'DepartmentHead', '2026-009', 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(10, 'amanda.white', '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW', 'Faculty', '2026-010', 1, '2026-02-02 16:35:47', '2026-02-02 16:35:47'),
(11, 'dean.cs', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:37:49', '2026-02-10 11:37:49'),
(12, 'dean.it', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:37:49', '2026-02-10 11:37:49'),
(13, 'dean.math', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:37:49', '2026-02-10 11:37:49'),
(14, 'dean.eng', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:37:49', '2026-02-10 11:37:49'),
(15, 'dean.ba', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:37:49', '2026-02-10 11:37:49'),
(16, 'alan.turing', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:39:04', '2026-02-10 11:39:04'),
(17, 'tim.berners-lee', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:39:04', '2026-02-10 11:39:04'),
(18, 'carl.gauss', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:39:04', '2026-02-10 11:39:04'),
(19, 'nikola.tesla', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:39:04', '2026-02-10 11:39:04'),
(20, 'peter.drucker', '$2y$10$abcdefghijklmnopqrstuvwx', 'DepartmentHead', NULL, 1, '2026-02-10 11:39:04', '2026-02-10 11:39:04');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `attendancedevices`
--
ALTER TABLE `attendancedevices`
  ADD PRIMARY KEY (`DeviceID`),
  ADD KEY `RoomID` (`RoomID`);

--
-- Indexes for table `attendances`
--
ALTER TABLE `attendances`
  ADD PRIMARY KEY (`AttendanceID`),
  ADD KEY `DeviceID` (`DeviceID`),
  ADD KEY `ScheduleID` (`ScheduleID`),
  ADD KEY `idx_attendances_date` (`Date`),
  ADD KEY `idx_attendances_faculty` (`FacultyID`);

--
-- Indexes for table `auth_tokens`
--
ALTER TABLE `auth_tokens`
  ADD PRIMARY KEY (`TokenID`),
  ADD UNIQUE KEY `Token` (`Token`),
  ADD KEY `UserID` (`UserID`),
  ADD KEY `idx_auth_tokens_token` (`Token`);

--
-- Indexes for table `departments`
--
ALTER TABLE `departments`
  ADD PRIMARY KEY (`DepartmentID`),
  ADD KEY `fk_departments_dept_dean` (`DepartmentDeanID`);

--
-- Indexes for table `department_deans`
--
ALTER TABLE `department_deans`
  ADD PRIMARY KEY (`DepartmentDeanID`),
  ADD UNIQUE KEY `unique_dept_active` (`DepartmentID`,`IsActive`);

--
-- Indexes for table `faculties`
--
ALTER TABLE `faculties`
  ADD PRIMARY KEY (`FacultyID`),
  ADD KEY `DepartmentID` (`DepartmentID`);

--
-- Indexes for table `rooms`
--
ALTER TABLE `rooms`
  ADD PRIMARY KEY (`RoomID`);

--
-- Indexes for table `schedules`
--
ALTER TABLE `schedules`
  ADD PRIMARY KEY (`ScheduleID`),
  ADD KEY `SubjectID` (`SubjectID`),
  ADD KEY `RoomID` (`RoomID`),
  ADD KEY `idx_schedules_faculty` (`FacultyID`),
  ADD KEY `idx_schedules_day` (`DayOfWeek`);

--
-- Indexes for table `subjects`
--
ALTER TABLE `subjects`
  ADD PRIMARY KEY (`SubjectID`),
  ADD KEY `DepartmentID` (`DepartmentID`);

--
-- Indexes for table `useraccounts`
--
ALTER TABLE `useraccounts`
  ADD PRIMARY KEY (`UserID`),
  ADD UNIQUE KEY `Username` (`Username`),
  ADD KEY `FacultyID` (`FacultyID`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `attendancedevices`
--
ALTER TABLE `attendancedevices`
  MODIFY `DeviceID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `attendances`
--
ALTER TABLE `attendances`
  MODIFY `AttendanceID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=30;

--
-- AUTO_INCREMENT for table `auth_tokens`
--
ALTER TABLE `auth_tokens`
  MODIFY `TokenID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=147;

--
-- AUTO_INCREMENT for table `departments`
--
ALTER TABLE `departments`
  MODIFY `DepartmentID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `department_deans`
--
ALTER TABLE `department_deans`
  MODIFY `DepartmentDeanID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `rooms`
--
ALTER TABLE `rooms`
  MODIFY `RoomID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `schedules`
--
ALTER TABLE `schedules`
  MODIFY `ScheduleID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `subjects`
--
ALTER TABLE `subjects`
  MODIFY `SubjectID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `useraccounts`
--
ALTER TABLE `useraccounts`
  MODIFY `UserID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `attendancedevices`
--
ALTER TABLE `attendancedevices`
  ADD CONSTRAINT `attendancedevices_ibfk_1` FOREIGN KEY (`RoomID`) REFERENCES `rooms` (`RoomID`) ON DELETE SET NULL;

--
-- Constraints for table `attendances`
--
ALTER TABLE `attendances`
  ADD CONSTRAINT `attendances_ibfk_1` FOREIGN KEY (`FacultyID`) REFERENCES `faculties` (`FacultyID`) ON DELETE CASCADE,
  ADD CONSTRAINT `attendances_ibfk_2` FOREIGN KEY (`DeviceID`) REFERENCES `attendancedevices` (`DeviceID`) ON DELETE SET NULL,
  ADD CONSTRAINT `attendances_ibfk_3` FOREIGN KEY (`ScheduleID`) REFERENCES `schedules` (`ScheduleID`) ON DELETE SET NULL;

--
-- Constraints for table `auth_tokens`
--
ALTER TABLE `auth_tokens`
  ADD CONSTRAINT `auth_tokens_ibfk_1` FOREIGN KEY (`UserID`) REFERENCES `useraccounts` (`UserID`) ON DELETE CASCADE;

--
-- Constraints for table `departments`
--
ALTER TABLE `departments`
  ADD CONSTRAINT `fk_departments_dept_dean` FOREIGN KEY (`DepartmentDeanID`) REFERENCES `department_deans` (`DepartmentDeanID`) ON DELETE SET NULL;

--
-- Constraints for table `department_deans`
--
ALTER TABLE `department_deans`
  ADD CONSTRAINT `fk_dept_deans_dept` FOREIGN KEY (`DepartmentID`) REFERENCES `departments` (`DepartmentID`) ON DELETE CASCADE;

--
-- Constraints for table `faculties`
--
ALTER TABLE `faculties`
  ADD CONSTRAINT `faculties_ibfk_1` FOREIGN KEY (`DepartmentID`) REFERENCES `departments` (`DepartmentID`);

--
-- Constraints for table `schedules`
--
ALTER TABLE `schedules`
  ADD CONSTRAINT `schedules_ibfk_1` FOREIGN KEY (`FacultyID`) REFERENCES `faculties` (`FacultyID`) ON DELETE CASCADE,
  ADD CONSTRAINT `schedules_ibfk_2` FOREIGN KEY (`SubjectID`) REFERENCES `subjects` (`SubjectID`) ON DELETE CASCADE,
  ADD CONSTRAINT `schedules_ibfk_3` FOREIGN KEY (`RoomID`) REFERENCES `rooms` (`RoomID`) ON DELETE CASCADE;

--
-- Constraints for table `subjects`
--
ALTER TABLE `subjects`
  ADD CONSTRAINT `subjects_ibfk_1` FOREIGN KEY (`DepartmentID`) REFERENCES `departments` (`DepartmentID`);

--
-- Constraints for table `useraccounts`
--
ALTER TABLE `useraccounts`
  ADD CONSTRAINT `useraccounts_ibfk_1` FOREIGN KEY (`FacultyID`) REFERENCES `faculties` (`FacultyID`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
