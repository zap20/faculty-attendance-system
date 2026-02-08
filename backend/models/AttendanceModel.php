<?php
/**
 * Attendance Model
 * Handles ATTENDANCES table operations with verification logic
 */

class AttendanceModel extends BaseModel {
    protected $table = 'ATTENDANCES';
    protected $primaryKey = 'AttendanceID';

    public function findAllWithDetails(array $filters = []): array {
        $sql = "
            SELECT a.*, 
                   f.FacultyName, f.DepartmentID,
                   d.DeviceType, d.Location as DeviceLocation,
                   s.SubjectID, sub.SubjectName, sub.CourseCode,
                   r.RoomName, r.Building,
                   dept.DepartmentName
            FROM ATTENDANCES a
            JOIN FACULTIES f ON a.FacultyID = f.FacultyID
            LEFT JOIN ATTENDANCEDEVICES d ON a.DeviceID = d.DeviceID
            LEFT JOIN SCHEDULES s ON a.ScheduleID = s.ScheduleID
            LEFT JOIN SUBJECTS sub ON s.SubjectID = sub.SubjectID
            LEFT JOIN ROOMS r ON s.RoomID = r.RoomID
            LEFT JOIN DEPARTMENTS dept ON f.DepartmentID = dept.DepartmentID
            WHERE 1=1
        ";
        $params = [];

        if (!empty($filters['from'])) {
            $sql .= " AND a.Date >= ?";
            $params[] = $filters['from'];
        }
        if (!empty($filters['to'])) {
            $sql .= " AND a.Date <= ?";
            $params[] = $filters['to'];
        }
        if (!empty($filters['facultyId'])) {
            $sql .= " AND a.FacultyID = ?";
            $params[] = $filters['facultyId'];
        }
        if (!empty($filters['departmentId'])) {
            $sql .= " AND f.DepartmentID = ?";
            $params[] = $filters['departmentId'];
        }
        if (!empty($filters['status'])) {
            $sql .= " AND a.AttendanceStatus = ?";
            $params[] = $filters['status'];
        }

        $sql .= " ORDER BY a.Date DESC, a.TimeIn DESC";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function findByFacultyAndDate($facultyId, string $date): array {
        $stmt = $this->db->prepare("
            SELECT a.*, 
                   d.DeviceType, d.Location as DeviceLocation,
                   s.SubjectID, sub.SubjectName, sub.CourseCode,
                   r.RoomName, r.Building
            FROM ATTENDANCES a
            LEFT JOIN ATTENDANCEDEVICES d ON a.DeviceID = d.DeviceID
            LEFT JOIN SCHEDULES s ON a.ScheduleID = s.ScheduleID
            LEFT JOIN SUBJECTS sub ON s.SubjectID = sub.SubjectID
            LEFT JOIN ROOMS r ON s.RoomID = r.RoomID
            WHERE a.FacultyID = ? AND a.Date = ?
            ORDER BY a.TimeIn
        ");
        $stmt->execute([$facultyId, $date]);
        return $stmt->fetchAll();
    }

    /**
     * Find open attendance (TimeIn exists but TimeOut is null)
     */
    public function findOpenAttendance($facultyId, string $date): ?array {
        $stmt = $this->db->prepare("
            SELECT * FROM ATTENDANCES 
            WHERE FacultyID = ? AND Date = ? AND TimeIn IS NOT NULL AND TimeOut IS NULL
            ORDER BY TimeIn DESC
            LIMIT 1
        ");
        $stmt->execute([$facultyId, $date]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    /**
     * Check if faculty already has attendance for specific schedule today
     */
    public function hasAttendanceForSchedule($facultyId, $scheduleId, string $date): bool {
        $stmt = $this->db->prepare("
            SELECT 1 FROM ATTENDANCES 
            WHERE FacultyID = ? AND ScheduleID = ? AND Date = ?
            LIMIT 1
        ");
        $stmt->execute([$facultyId, $scheduleId, $date]);
        return $stmt->fetch() !== false;
    }

    /**
     * Get attendance summary for a date
     */
    public function getSummary(string $date, $departmentId = null): array {
        $sql = "
            SELECT 
                COUNT(DISTINCT a.FacultyID) as TotalPresent,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) as OnTime,
                SUM(CASE WHEN a.AttendanceStatus = 'Late' THEN 1 ELSE 0 END) as Late,
                SUM(CASE WHEN a.AttendanceStatus = 'No Schedule' THEN 1 ELSE 0 END) as NoSchedule,
                SUM(CASE WHEN a.AttendanceStatus = 'Wrong Room' THEN 1 ELSE 0 END) as WrongRoom
            FROM ATTENDANCES a
            JOIN FACULTIES f ON a.FacultyID = f.FacultyID
            WHERE a.Date = ?
        ";
        $params = [$date];

        if ($departmentId) {
            $sql .= " AND f.DepartmentID = ?";
            $params[] = $departmentId;
        }

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetch();
    }

    /**
     * Get department attendance report
     */
    public function getDepartmentReport($departmentId, string $from, string $to): array {
        $stmt = $this->db->prepare("
            SELECT 
                f.FacultyID, f.FacultyName,
                COUNT(DISTINCT a.Date) as DaysPresent,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) as OnTimeCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Late' THEN 1 ELSE 0 END) as LateCount,
                SUM(CASE WHEN a.AttendanceStatus = 'No Schedule' THEN 1 ELSE 0 END) as NoScheduleCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Wrong Room' THEN 1 ELSE 0 END) as WrongRoomCount
            FROM FACULTIES f
            LEFT JOIN ATTENDANCES a ON f.FacultyID = a.FacultyID AND a.Date BETWEEN ? AND ?
            WHERE f.DepartmentID = ?
            GROUP BY f.FacultyID, f.FacultyName
            ORDER BY f.FacultyName
        ");
        $stmt->execute([$from, $to, $departmentId]);
        return $stmt->fetchAll();
    }

    public function getStatusBreakdown(int $departmentId, string $from, string $to, array $filters = []): array {
        $sql = "
            SELECT a.AttendanceStatus, COUNT(*) as Count
            FROM ATTENDANCES a
            JOIN FACULTIES f ON a.FacultyID = f.FacultyID
            LEFT JOIN SCHEDULES s ON a.ScheduleID = s.ScheduleID
            WHERE a.Date BETWEEN ? AND ?
              AND f.DepartmentID = ?
        ";
        $params = [$from, $to, $departmentId];

        if (!empty($filters['facultyId'])) {
            $sql .= " AND a.FacultyID = ?";
            $params[] = $filters['facultyId'];
        }
        if (!empty($filters['subjectId'])) {
            $sql .= " AND s.SubjectID = ?";
            $params[] = (int) $filters['subjectId'];
        }
        if (!empty($filters['roomId'])) {
            $sql .= " AND s.RoomID = ?";
            $params[] = (int) $filters['roomId'];
        }

        $sql .= " GROUP BY a.AttendanceStatus";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function getTrendByDay(int $departmentId, string $from, string $to, array $filters = []): array {
        $sql = "
            SELECT a.Date,
                   SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) as Present,
                   SUM(CASE WHEN a.AttendanceStatus = 'Late' THEN 1 ELSE 0 END) as Late,
                   SUM(CASE WHEN a.AttendanceStatus = 'Wrong Room' THEN 1 ELSE 0 END) as WrongRoom,
                   SUM(CASE WHEN a.AttendanceStatus = 'No Schedule' THEN 1 ELSE 0 END) as NoSchedule,
                   SUM(CASE WHEN a.AttendanceStatus = 'Absent' THEN 1 ELSE 0 END) as Absent
            FROM ATTENDANCES a
            JOIN FACULTIES f ON a.FacultyID = f.FacultyID
            LEFT JOIN SCHEDULES s ON a.ScheduleID = s.ScheduleID
            WHERE a.Date BETWEEN ? AND ?
              AND f.DepartmentID = ?
        ";
        $params = [$from, $to, $departmentId];

        if (!empty($filters['facultyId'])) {
            $sql .= " AND a.FacultyID = ?";
            $params[] = $filters['facultyId'];
        }
        if (!empty($filters['subjectId'])) {
            $sql .= " AND s.SubjectID = ?";
            $params[] = (int) $filters['subjectId'];
        }
        if (!empty($filters['roomId'])) {
            $sql .= " AND s.RoomID = ?";
            $params[] = (int) $filters['roomId'];
        }

        $sql .= " GROUP BY a.Date ORDER BY a.Date";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function getTopExceptions(int $departmentId, string $from, string $to, int $limit = 5, array $filters = []): array {
        $sql = "
            SELECT a.AttendanceStatus, COUNT(*) as Count
            FROM ATTENDANCES a
            JOIN FACULTIES f ON a.FacultyID = f.FacultyID
            LEFT JOIN SCHEDULES s ON a.ScheduleID = s.ScheduleID
            WHERE a.Date BETWEEN ? AND ?
              AND f.DepartmentID = ?
              AND a.AttendanceStatus IN ('Absent', 'Late', 'Wrong Room', 'No Schedule')
        ";
        $params = [$from, $to, $departmentId];

        if (!empty($filters['facultyId'])) {
            $sql .= " AND a.FacultyID = ?";
            $params[] = $filters['facultyId'];
        }
        if (!empty($filters['subjectId'])) {
            $sql .= " AND s.SubjectID = ?";
            $params[] = (int) $filters['subjectId'];
        }
        if (!empty($filters['roomId'])) {
            $sql .= " AND s.RoomID = ?";
            $params[] = (int) $filters['roomId'];
        }

        $sql .= " GROUP BY a.AttendanceStatus ORDER BY Count DESC LIMIT " . (int) $limit;

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function getAttendanceRate(int $departmentId, string $from, string $to, int $totalFaculty): float {
        $stmt = $this->db->prepare("
            SELECT COUNT(DISTINCT CONCAT(a.FacultyID, '|', a.Date)) as PresentFacultyDays
            FROM ATTENDANCES a
            JOIN FACULTIES f ON a.FacultyID = f.FacultyID
            WHERE a.Date BETWEEN ? AND ?
              AND f.DepartmentID = ?
              AND a.AttendanceStatus IN ('Present', 'Late')
        ");
        $stmt->execute([$from, $to, $departmentId]);
        $row = $stmt->fetch();
        $presentFacultyDays = (int) ($row['PresentFacultyDays'] ?? 0);

        $days = (int) ((strtotime($to) - strtotime($from)) / 86400) + 1;
        if ($days <= 0 || $totalFaculty <= 0) return 0.0;

        $denominator = $totalFaculty * $days;
        return ($presentFacultyDays / $denominator) * 100.0;
    }
}
