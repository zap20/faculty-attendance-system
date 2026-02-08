<?php
/**
 * Schedule Model
 * Handles SCHEDULES table operations with conflict checking
 */

class ScheduleModel extends BaseModel {
    protected $table = 'SCHEDULES';
    protected $primaryKey = 'ScheduleID';

    public function findByDepartment(int $departmentId, ?string $facultyId = null, ?array $daysOfWeek = null): array {
        $sql = "
            SELECT s.*, 
                   f.FacultyName, 
                   sub.SubjectName, sub.CourseCode,
                   r.RoomName, r.Building
            FROM SCHEDULES s
            JOIN FACULTIES f ON s.FacultyID = f.FacultyID
            JOIN SUBJECTS sub ON s.SubjectID = sub.SubjectID
            JOIN ROOMS r ON s.RoomID = r.RoomID
            WHERE f.DepartmentID = ?
        ";
        $params = [$departmentId];

        if (!empty($facultyId)) {
            $sql .= " AND s.FacultyID = ?";
            $params[] = $facultyId;
        }

        if (!empty($daysOfWeek) && is_array($daysOfWeek)) {
            $placeholders = implode(', ', array_fill(0, count($daysOfWeek), '?'));
            $sql .= " AND s.DayOfWeek IN ($placeholders)";
            foreach ($daysOfWeek as $d) {
                $params[] = $d;
            }
        }

        $sql .= " ORDER BY FIELD(s.DayOfWeek, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'), s.StartTime";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function findAllWithDetails(): array {
        $stmt = $this->db->prepare("
            SELECT s.*, 
                   f.FacultyName, 
                   sub.SubjectName, sub.CourseCode,
                   r.RoomName, r.Building
            FROM SCHEDULES s
            JOIN FACULTIES f ON s.FacultyID = f.FacultyID
            JOIN SUBJECTS sub ON s.SubjectID = sub.SubjectID
            JOIN ROOMS r ON s.RoomID = r.RoomID
            ORDER BY s.DayOfWeek, s.StartTime
        ");
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function findByIdWithDetails($scheduleId): ?array {
        $stmt = $this->db->prepare("
            SELECT s.*, 
                   f.FacultyName, 
                   sub.SubjectName, sub.CourseCode,
                   r.RoomName, r.Building
            FROM SCHEDULES s
            JOIN FACULTIES f ON s.FacultyID = f.FacultyID
            JOIN SUBJECTS sub ON s.SubjectID = sub.SubjectID
            JOIN ROOMS r ON s.RoomID = r.RoomID
            WHERE s.ScheduleID = ?
        ");
        $stmt->execute([$scheduleId]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    public function findByFaculty($facultyId): array {
        $stmt = $this->db->prepare("
            SELECT s.*, 
                   f.FacultyName, 
                   sub.SubjectName, sub.CourseCode,
                   r.RoomName, r.Building
            FROM SCHEDULES s
            JOIN FACULTIES f ON s.FacultyID = f.FacultyID
            JOIN SUBJECTS sub ON s.SubjectID = sub.SubjectID
            JOIN ROOMS r ON s.RoomID = r.RoomID
            WHERE s.FacultyID = ?
            ORDER BY FIELD(s.DayOfWeek, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'), s.StartTime
        ");
        $stmt->execute([$facultyId]);
        return $stmt->fetchAll();
    }

    public function findByFacultyAndDay($facultyId, string $dayOfWeek): array {
        $stmt = $this->db->prepare("
            SELECT s.*, 
                   f.FacultyName, 
                   sub.SubjectName, sub.CourseCode,
                   r.RoomName, r.Building
            FROM SCHEDULES s
            JOIN FACULTIES f ON s.FacultyID = f.FacultyID
            JOIN SUBJECTS sub ON s.SubjectID = sub.SubjectID
            JOIN ROOMS r ON s.RoomID = r.RoomID
            WHERE s.FacultyID = ? AND s.DayOfWeek = ?
            ORDER BY s.StartTime
        ");
        $stmt->execute([$facultyId, $dayOfWeek]);
        return $stmt->fetchAll();
    }

    /**
     * Find current schedule for faculty based on day and time
     */
    public function findCurrentSchedule($facultyId, string $dayOfWeek, string $currentTime): ?array {
        $stmt = $this->db->prepare("
            SELECT s.*, 
                   f.FacultyName, 
                   sub.SubjectName, sub.CourseCode,
                   r.RoomName, r.Building
            FROM SCHEDULES s
            JOIN FACULTIES f ON s.FacultyID = f.FacultyID
            JOIN SUBJECTS sub ON s.SubjectID = sub.SubjectID
            JOIN ROOMS r ON s.RoomID = r.RoomID
            WHERE s.FacultyID = ? 
              AND s.DayOfWeek = ?
              AND s.StartTime <= ?
              AND s.EndTime >= ?
            LIMIT 1
        ");
        $stmt->execute([$facultyId, $dayOfWeek, $currentTime, $currentTime]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    /**
     * Check for schedule conflicts
     * Returns conflicting schedules if any
     */
    public function checkConflicts($facultyId, $roomId, string $dayOfWeek, 
                                   string $startTime, string $endTime, $excludeId = null): array {
        $conflicts = [];

        // Check faculty conflict (same faculty, same day, overlapping time)
        $sql = "
            SELECT s.*, f.FacultyName, r.RoomName
            FROM SCHEDULES s
            JOIN FACULTIES f ON s.FacultyID = f.FacultyID
            JOIN ROOMS r ON s.RoomID = r.RoomID
            WHERE s.FacultyID = ? 
              AND s.DayOfWeek = ?
              AND ((s.StartTime < ? AND s.EndTime > ?) OR (s.StartTime < ? AND s.EndTime > ?) OR (s.StartTime >= ? AND s.EndTime <= ?))
        ";
        $params = [$facultyId, $dayOfWeek, $endTime, $startTime, $endTime, $startTime, $startTime, $endTime];
        
        if ($excludeId) {
            $sql .= " AND s.ScheduleID != ?";
            $params[] = $excludeId;
        }

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $facultyConflicts = $stmt->fetchAll();
        
        foreach ($facultyConflicts as $conflict) {
            $conflicts[] = [
                'type' => 'faculty',
                'message' => "Faculty {$conflict['FacultyName']} already has a schedule on {$dayOfWeek} from {$conflict['StartTime']} to {$conflict['EndTime']}"
            ];
        }

        // Check room conflict (same room, same day, overlapping time)
        $sql = "
            SELECT s.*, f.FacultyName, r.RoomName
            FROM SCHEDULES s
            JOIN FACULTIES f ON s.FacultyID = f.FacultyID
            JOIN ROOMS r ON s.RoomID = r.RoomID
            WHERE s.RoomID = ? 
              AND s.DayOfWeek = ?
              AND ((s.StartTime < ? AND s.EndTime > ?) OR (s.StartTime < ? AND s.EndTime > ?) OR (s.StartTime >= ? AND s.EndTime <= ?))
        ";
        $params = [$roomId, $dayOfWeek, $endTime, $startTime, $endTime, $startTime, $startTime, $endTime];
        
        if ($excludeId) {
            $sql .= " AND s.ScheduleID != ?";
            $params[] = $excludeId;
        }

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $roomConflicts = $stmt->fetchAll();
        
        foreach ($roomConflicts as $conflict) {
            $conflicts[] = [
                'type' => 'room',
                'message' => "Room {$conflict['RoomName']} is already booked on {$dayOfWeek} from {$conflict['StartTime']} to {$conflict['EndTime']} by {$conflict['FacultyName']}"
            ];
        }

        return $conflicts;
    }
}
