<?php

class DepartmentHeadController {
    private $attendanceModel;
    private $facultyModel;
    private $departmentModel;
    private $scheduleModel;
    private $subjectModel;
    private $roomModel;
    private $userModel;

    public function __construct() {
        $this->attendanceModel = new AttendanceModel();
        $this->facultyModel = new FacultyModel();
        $this->departmentModel = new DepartmentModel();
        $this->scheduleModel = new ScheduleModel();
        $this->subjectModel = new SubjectModel();
        $this->roomModel = new RoomModel();
        $this->userModel = new UserModel();
    }

    private function requireDepartmentHead(): array {
        $user = Auth::requireRole(['DepartmentHead']);
        if (empty($user['DepartmentID'])) {
            Response::error('DepartmentHead account is not linked to any department', 400);
        }
        return $user;
    }

    private function getRequestData(): array {
        $raw = file_get_contents('php://input');
        if ($raw !== false && trim($raw) !== '') {
            $trimmed = trim($raw);
            $decoded = json_decode($trimmed, true);
            if (is_string($decoded)) {
                $decoded = json_decode($decoded, true);
            }
            if (!is_array($decoded) && strlen($trimmed) >= 2 && $trimmed[0] === '"' && substr($trimmed, -1) === '"') {
                $asString = json_decode($trimmed, true);
                if (is_string($asString)) {
                    $decoded = json_decode($asString, true);
                }
            }
            if (is_array($decoded)) {
                return $decoded;
            }
            if (strpos($raw, '=') !== false) {
                $parsed = [];
                parse_str($raw, $parsed);
                if (is_array($parsed) && !empty($parsed)) {
                    return $parsed;
                }
            }
        }
        return $_POST ?? [];
    }

    public function dashboardSummary(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];
        $date = $_GET['date'] ?? date('Y-m-d');

        $summary = $this->attendanceModel->getSummary($date, $departmentId);
        $totalFaculty = $this->facultyModel->count(['DepartmentID' => $departmentId]);

        $dayOfWeek = date('l', strtotime($date));
        $scheduledToday = $this->scheduleModel->countScheduledSessions($dayOfWeek, $departmentId);
        $totalPresent = (int) ($summary['TotalPresent'] ?? 0);
        $totalRecords = (int) ($summary['TotalRecords'] ?? 0);
        $absent = max(0, $scheduledToday - $totalRecords);

        $weekFrom = date('Y-m-d', strtotime($date . ' -6 days'));
        $weekTo = $date;

        $weeklyPresent = $this->countAttendancesByStatus($departmentId, $weekFrom, $weekTo, 'Present');
        $days = 7;
        $weeklyRate = $totalFaculty > 0 ? round(($weeklyPresent / ($totalFaculty * $days)) * 100, 2) : 0.0;

        $exceptions = $this->getTopExceptions($departmentId, $weekFrom, $weekTo, 5);

        Response::success([
            'date' => $date,
            'departmentId' => $departmentId,
            'kpis' => [
                'totalFaculty' => $totalFaculty,
                'presentToday' => $totalPresent,
                'onTimeToday' => (int) ($summary['OnTime'] ?? 0),
                'lateToday' => (int) ($summary['Late'] ?? 0),
                'noScheduleToday' => (int) ($summary['NoSchedule'] ?? 0),
                'wrongRoomToday' => (int) ($summary['WrongRoom'] ?? 0),
                'absentToday' => $absent,
                'weeklyAttendanceRatePresent' => $weeklyRate
            ],
            'statusBreakdownToday' => [
                ['status' => 'Present', 'count' => (int) ($summary['OnTime'] ?? 0)],
                ['status' => 'Late', 'count' => (int) ($summary['Late'] ?? 0)],
                ['status' => 'No Schedule', 'count' => (int) ($summary['NoSchedule'] ?? 0)],
                ['status' => 'Wrong Room', 'count' => (int) ($summary['WrongRoom'] ?? 0)]
            ],
            'topExceptions7Days' => $exceptions
        ]);
    }

    public function analytics(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $from = $_GET['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to = $_GET['to'] ?? date('Y-m-d');

        $db = Database::getInstance()->getConnection();

        // 1) KPI Summary
        $totalFaculty = $this->facultyModel->count(['DepartmentID' => $departmentId]);

        $kpiStmt = $db->prepare("
            SELECT
                COUNT(*) AS totalRecords,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) AS totalPresent,
                SUM(CASE WHEN a.AttendanceStatus = 'Late' THEN 1 ELSE 0 END) AS totalLate,
                SUM(CASE WHEN a.AttendanceStatus IN ('No Schedule','Wrong Room') THEN 1 ELSE 0 END) AS totalExceptions
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            WHERE f.DepartmentID = ? AND a.Date BETWEEN ? AND ?
        ");
        $kpiStmt->execute([$departmentId, $from, $to]);
        $kpiRow = $kpiStmt->fetch();

        $schedSessionStmt = $db->prepare("
            SELECT COUNT(*) AS cnt
            FROM schedules s
            JOIN faculties f ON s.FacultyID = f.FacultyID
            WHERE f.DepartmentID = ?
        ");
        $schedSessionStmt->execute([$departmentId]);
        $totalScheduledSessions = (int) $schedSessionStmt->fetch()['cnt'];

        $totalPresent = (int) ($kpiRow['totalPresent'] ?? 0);
        $totalLate = (int) ($kpiRow['totalLate'] ?? 0);
        $totalExceptions = (int) ($kpiRow['totalExceptions'] ?? 0);
        $totalRecords = (int) ($kpiRow['totalRecords'] ?? 0);

        // Count scheduled days in date range for attendance rate
        $daysInRange = max(1, (int) ((strtotime($to) - strtotime($from)) / 86400) + 1);
        $expectedAttendances = 0;
        // Count expected attendances: for each day in range, count faculty with schedules on that day-of-week
        $expStmt = $db->prepare("
            SELECT s.DayOfWeek, COUNT(DISTINCT s.FacultyID) AS facultyCount
            FROM schedules s
            JOIN faculties f ON s.FacultyID = f.FacultyID
            WHERE f.DepartmentID = ?
            GROUP BY s.DayOfWeek
        ");
        $expStmt->execute([$departmentId]);
        $scheduledByDay = [];
        while ($row = $expStmt->fetch()) {
            $scheduledByDay[$row['DayOfWeek']] = (int) $row['facultyCount'];
        }
        // Walk through each date in range
        $currentDate = $from;
        while ($currentDate <= $to) {
            $dayName = date('l', strtotime($currentDate));
            $expectedAttendances += $scheduledByDay[$dayName] ?? 0;
            $currentDate = date('Y-m-d', strtotime($currentDate . ' +1 day'));
        }

        $attendanceRate = $expectedAttendances > 0
            ? round(($totalPresent / $expectedAttendances) * 100, 2)
            : 0.0;

        $kpis = [
            'totalFaculty' => $totalFaculty,
            'totalScheduledSessions' => $totalScheduledSessions,
            'expectedAttendances' => $expectedAttendances,
            'totalPresent' => $totalPresent,
            'totalLate' => $totalLate,
            'totalExceptions' => $totalExceptions,
            'attendanceRate' => $attendanceRate,
        ];

        // 2) Status Breakdown
        $breakdown = $this->getStatusBreakdown($departmentId, $from, $to);

        // 3) Faculty Performance Ranking
        $rankStmt = $db->prepare("
            SELECT
                f.FacultyID,
                f.FacultyName,
                COUNT(a.AttendanceID) AS totalSessions,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) AS presentCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Late' THEN 1 ELSE 0 END) AS lateCount,
                SUM(CASE WHEN a.AttendanceStatus IN ('No Schedule','Wrong Room') THEN 1 ELSE 0 END) AS exceptionCount
            FROM faculties f
            LEFT JOIN attendances a ON f.FacultyID = a.FacultyID AND a.Date BETWEEN ? AND ?
            WHERE f.DepartmentID = ?
            GROUP BY f.FacultyID, f.FacultyName
            ORDER BY presentCount DESC, lateCount ASC
        ");
        $rankStmt->execute([$from, $to, $departmentId]);
        $facultyRanking = [];
        while ($row = $rankStmt->fetch()) {
            $row['totalSessions'] = (int) $row['totalSessions'];
            $row['presentCount'] = (int) $row['presentCount'];
            $row['lateCount'] = (int) $row['lateCount'];
            $row['exceptionCount'] = (int) $row['exceptionCount'];
            $row['attendanceRate'] = $row['totalSessions'] > 0
                ? round(($row['presentCount'] / $row['totalSessions']) * 100, 2)
                : 0.0;
            $facultyRanking[] = $row;
        }
        // Sort by attendanceRate DESC
        usort($facultyRanking, function ($a, $b) {
            return $b['attendanceRate'] <=> $a['attendanceRate'];
        });

        // 4) Room Utilization
        $roomStmt = $db->prepare("
            SELECT
                r.RoomID,
                r.RoomName,
                r.Building,
                COUNT(DISTINCT s.ScheduleID) AS scheduledSessions,
                COUNT(DISTINCT a.AttendanceID) AS attendanceRecorded
            FROM rooms r
            LEFT JOIN schedules s ON r.RoomID = s.RoomID
            LEFT JOIN faculties f ON s.FacultyID = f.FacultyID AND f.DepartmentID = ?
            LEFT JOIN attendances a ON a.ScheduleID = s.ScheduleID AND a.Date BETWEEN ? AND ?
            WHERE f.FacultyID IS NOT NULL
            GROUP BY r.RoomID, r.RoomName, r.Building
            HAVING scheduledSessions > 0
            ORDER BY scheduledSessions DESC
        ");
        $roomStmt->execute([$departmentId, $from, $to]);
        $roomUtilization = [];
        while ($row = $roomStmt->fetch()) {
            $row['RoomID'] = (int) $row['RoomID'];
            $row['scheduledSessions'] = (int) $row['scheduledSessions'];
            $row['attendanceRecorded'] = (int) $row['attendanceRecorded'];
            $row['utilizationRate'] = $row['scheduledSessions'] > 0
                ? round(($row['attendanceRecorded'] / ($row['scheduledSessions'] * $daysInRange)) * 100, 2)
                : 0.0;
            $roomUtilization[] = $row;
        }

        // 5) Attendance Trend
        $trend = $this->getTrendByDay($departmentId, $from, $to);

        Response::success([
            'from' => $from,
            'to' => $to,
            'kpis' => $kpis,
            'statusBreakdown' => $breakdown,
            'facultyRanking' => $facultyRanking,
            'roomUtilization' => $roomUtilization,
            'attendanceTrend' => $trend,
        ]);
    }

    public function facultiesIndex(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $faculties = $this->facultyModel->findByDepartment($departmentId);
        Response::success($faculties);
    }

    public function createFaculty(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];
        $data = $this->getRequestData();

        $validator = new Validator($data ?? []);
        $validator->required('facultyName', 'Faculty name')
                  ->required('position', 'Position')
                  ->required('employmentStatus', 'Employment status')
                  ->required('username', 'Username')
                  ->validate();

        $username = trim((string) $data['username']);
        if ($this->userModel->usernameExists($username)) {
            Response::error('Username already exists', 400);
        }

        $tempPassword = $data['tempPassword'] ?? null;
        if ($tempPassword === null || trim((string) $tempPassword) === '') {
            $tempPassword = bin2hex(random_bytes(4));
        }

        $db = Database::getInstance()->getConnection();
        try {
            $db->beginTransaction();

            $facultyId = $this->facultyModel->generateNextFacultyId();
            $this->facultyModel->createWithId([
                'FacultyID' => $facultyId,
                'FacultyName' => $data['facultyName'],
                'DepartmentID' => $departmentId,
                'Position' => $data['position'],
                'EmploymentStatus' => $data['employmentStatus'],
                'ContactInformation' => $data['contactInformation'] ?? null
            ]);

            $userId = $this->userModel->createUserAccount([
                'Username' => $username,
                'Password' => Auth::hashPassword((string) $tempPassword),
                'Role' => 'Faculty',
                'FacultyID' => $facultyId,
                'IsActive' => 1
            ]);

            $db->commit();

            $faculty = $this->facultyModel->findByIdWithDepartment($facultyId);

            Response::success([
                'faculty' => $faculty,
                'user' => [
                    'userId' => $userId,
                    'username' => $username,
                    'role' => 'Faculty',
                    'facultyId' => $facultyId
                ],
                'credentials' => [
                    'username' => $username,
                    'tempPassword' => $tempPassword
                ]
            ], 'Faculty created successfully', 201);

        } catch (Exception $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            Response::error($e->getMessage(), 500);
        }
    }

    public function schedulesIndex(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $facultyId = $_GET['facultyId'] ?? null;

        if ($facultyId !== null && $facultyId !== '') {
            $faculty = $this->facultyModel->findById($facultyId);
            if (!$faculty || (int) $faculty['DepartmentID'] !== $departmentId) {
                Response::forbidden('Faculty does not belong to your department');
            }
        }

        $schedules = $this->scheduleModel->findByDepartment($departmentId, $facultyId);
        Response::success($schedules);
    }

    public function createSchedule(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];
        $data = $this->getRequestData();

        $validator = new Validator($data ?? []);
        $validator->required('FacultyID', 'Faculty')
                  ->required('SubjectID', 'Subject')
                  ->required('RoomID', 'Room')
                  ->required('DayOfWeek', 'Day of week')
                  ->required('StartTime', 'Start time')
                  ->required('EndTime', 'End time')
                  ->string('FacultyID', 'Faculty ID')
                  ->integer('SubjectID', 'Subject ID')
                  ->integer('RoomID', 'Room ID')
                  ->inArray('DayOfWeek', ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'], 'Day of week')
                  ->time('StartTime', 'Start time')
                  ->time('EndTime', 'End time')
                  ->validate();

        $faculty = $this->facultyModel->findById((string) $data['FacultyID']);
        if (!$faculty || (int) $faculty['DepartmentID'] !== $departmentId) {
            Response::forbidden('Faculty does not belong to your department');
        }

        $subject = $this->subjectModel->findById((int) $data['SubjectID']);
        if (!$subject || (int) $subject['DepartmentID'] !== $departmentId) {
            Response::forbidden('Subject does not belong to your department');
        }

        if (!$this->roomModel->exists((int) $data['RoomID'])) {
            Response::error('Room not found', 404);
        }

        if ($data['StartTime'] >= $data['EndTime']) {
            Response::error('End time must be after start time', 400);
        }

        $conflicts = $this->scheduleModel->checkConflicts(
            (string) $data['FacultyID'],
            (int) $data['RoomID'],
            (string) $data['DayOfWeek'],
            (string) $data['StartTime'],
            (string) $data['EndTime']
        );

        if (!empty($conflicts)) {
            Response::error('Schedule conflicts detected', 409, $conflicts);
        }

        $scheduleId = $this->scheduleModel->create([
            'FacultyID' => $data['FacultyID'],
            'SubjectID' => $data['SubjectID'],
            'RoomID' => $data['RoomID'],
            'DayOfWeek' => $data['DayOfWeek'],
            'StartTime' => $data['StartTime'],
            'EndTime' => $data['EndTime']
        ]);

        $schedule = $this->scheduleModel->findByIdWithDetails($scheduleId);
        Response::success($schedule, 'Schedule created successfully', 201);
    }

    public function updateSchedule(int $id): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $existing = $this->scheduleModel->findByIdWithDetails($id);
        if (!$existing) {
            Response::notFound('Schedule not found');
        }

        $faculty = $this->facultyModel->findById((string) $existing['FacultyID']);
        if (!$faculty || (int) $faculty['DepartmentID'] !== $departmentId) {
            Response::forbidden('Cannot modify schedules from other departments');
        }

        $data = $this->getRequestData();

        $validator = new Validator($data ?? []);
        $validator->required('FacultyID', 'Faculty')
                  ->required('SubjectID', 'Subject')
                  ->required('RoomID', 'Room')
                  ->required('DayOfWeek', 'Day of week')
                  ->required('StartTime', 'Start time')
                  ->required('EndTime', 'End time')
                  ->string('FacultyID', 'Faculty ID')
                  ->integer('SubjectID', 'Subject ID')
                  ->integer('RoomID', 'Room ID')
                  ->inArray('DayOfWeek', ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'], 'Day of week')
                  ->time('StartTime', 'Start time')
                  ->time('EndTime', 'End time')
                  ->validate();

        $faculty = $this->facultyModel->findById((string) $data['FacultyID']);
        if (!$faculty || (int) $faculty['DepartmentID'] !== $departmentId) {
            Response::forbidden('Faculty does not belong to your department');
        }

        $subject = $this->subjectModel->findById((int) $data['SubjectID']);
        if (!$subject || (int) $subject['DepartmentID'] !== $departmentId) {
            Response::forbidden('Subject does not belong to your department');
        }

        if (!$this->roomModel->exists((int) $data['RoomID'])) {
            Response::error('Room not found', 404);
        }

        if ($data['StartTime'] >= $data['EndTime']) {
            Response::error('End time must be after start time', 400);
        }

        $conflicts = $this->scheduleModel->checkConflicts(
            (string) $data['FacultyID'],
            (int) $data['RoomID'],
            (string) $data['DayOfWeek'],
            (string) $data['StartTime'],
            (string) $data['EndTime'],
            $id
        );

        if (!empty($conflicts)) {
            Response::error('Schedule conflicts detected', 409, $conflicts);
        }

        $this->scheduleModel->update($id, [
            'FacultyID' => $data['FacultyID'],
            'SubjectID' => $data['SubjectID'],
            'RoomID' => $data['RoomID'],
            'DayOfWeek' => $data['DayOfWeek'],
            'StartTime' => $data['StartTime'],
            'EndTime' => $data['EndTime']
        ]);

        $updated = $this->scheduleModel->findByIdWithDetails($id);
        Response::success($updated, 'Schedule updated successfully');
    }

    public function deleteSchedule(int $id): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $existing = $this->scheduleModel->findByIdWithDetails($id);
        if (!$existing) {
            Response::notFound('Schedule not found');
        }

        $faculty = $this->facultyModel->findById((string) $existing['FacultyID']);
        if (!$faculty || (int) $faculty['DepartmentID'] !== $departmentId) {
            Response::forbidden('Cannot delete schedules from other departments');
        }

        $this->scheduleModel->delete($id);
        Response::success(null, 'Schedule deleted successfully');
    }

    private function countAttendancesByStatus(int $departmentId, string $from, string $to, string $status): int {
        $db = Database::getInstance()->getConnection();
        $stmt = $db->prepare("
            SELECT COUNT(*) AS cnt
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
            WHERE f.DepartmentID = ?
              AND a.Date BETWEEN ? AND ?
              AND a.AttendanceStatus = ?
        ");
        $stmt->execute([$departmentId, $from, $to, $status]);
        $row = $stmt->fetch();
        return (int) ($row['cnt'] ?? 0);
    }

    private function getStatusBreakdown(int $departmentId, string $from, string $to, $facultyId = null, $subjectId = null, $roomId = null): array {
        $db = Database::getInstance()->getConnection();
        $sql = "
            SELECT a.AttendanceStatus AS status, COUNT(*) AS count
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
            WHERE f.DepartmentID = ?
              AND a.Date BETWEEN ? AND ?
        ";
        $params = [$departmentId, $from, $to];

        if ($facultyId !== null && $facultyId !== '') {
            $sql .= " AND a.FacultyID = ?";
            $params[] = $facultyId;
        }
        if ($subjectId !== null && $subjectId !== '') {
            $sql .= " AND s.SubjectID = ?";
            $params[] = (int) $subjectId;
        }
        if ($roomId !== null && $roomId !== '') {
            $sql .= " AND s.RoomID = ?";
            $params[] = (int) $roomId;
        }

        $sql .= " GROUP BY a.AttendanceStatus ORDER BY count DESC";

        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$row) {
            $row['count'] = (int) $row['count'];
        }
        return $rows;
    }

    private function getTrendByDay(int $departmentId, string $from, string $to, $facultyId = null, $subjectId = null, $roomId = null): array {
        $db = Database::getInstance()->getConnection();
        $sql = "
            SELECT a.Date AS date,
                   SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) AS present,
                   SUM(CASE WHEN a.AttendanceStatus = 'Late' THEN 1 ELSE 0 END) AS late,
                   SUM(CASE WHEN a.AttendanceStatus = 'No Schedule' THEN 1 ELSE 0 END) AS noSchedule,
                   SUM(CASE WHEN a.AttendanceStatus = 'Wrong Room' THEN 1 ELSE 0 END) AS wrongRoom
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
            WHERE f.DepartmentID = ?
              AND a.Date BETWEEN ? AND ?
        ";
        $params = [$departmentId, $from, $to];

        if ($facultyId !== null && $facultyId !== '') {
            $sql .= " AND a.FacultyID = ?";
            $params[] = $facultyId;
        }
        if ($subjectId !== null && $subjectId !== '') {
            $sql .= " AND s.SubjectID = ?";
            $params[] = (int) $subjectId;
        }
        if ($roomId !== null && $roomId !== '') {
            $sql .= " AND s.RoomID = ?";
            $params[] = (int) $roomId;
        }

        $sql .= " GROUP BY a.Date ORDER BY a.Date";

        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$row) {
            $row['present'] = (int) $row['present'];
            $row['late'] = (int) $row['late'];
            $row['noSchedule'] = (int) $row['noSchedule'];
            $row['wrongRoom'] = (int) $row['wrongRoom'];
        }
        return $rows;
    }

    private function getTopExceptions(int $departmentId, string $from, string $to, int $limit = 5, $facultyId = null, $subjectId = null, $roomId = null): array {
        $db = Database::getInstance()->getConnection();
        $sql = "
            SELECT a.AttendanceStatus AS status, COUNT(*) AS count
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
            WHERE f.DepartmentID = ?
              AND a.Date BETWEEN ? AND ?
              AND a.AttendanceStatus != 'Present'
        ";
        $params = [$departmentId, $from, $to];

        if ($facultyId !== null && $facultyId !== '') {
            $sql .= " AND a.FacultyID = ?";
            $params[] = $facultyId;
        }
        if ($subjectId !== null && $subjectId !== '') {
            $sql .= " AND s.SubjectID = ?";
            $params[] = (int) $subjectId;
        }
        if ($roomId !== null && $roomId !== '') {
            $sql .= " AND s.RoomID = ?";
            $params[] = (int) $roomId;
        }

        $sql .= " GROUP BY a.AttendanceStatus ORDER BY count DESC LIMIT " . (int) $limit;

        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }
}
