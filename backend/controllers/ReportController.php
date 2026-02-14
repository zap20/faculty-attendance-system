<?php
/**
 * Report Controller
 * Comprehensive reports module with role-based access
 */

class ReportController {
    private $attendanceModel;
    private $facultyModel;
    private $departmentModel;
    private $scheduleModel;
    private $db;

    public function __construct() {
        $this->attendanceModel = new AttendanceModel();
        $this->facultyModel = new FacultyModel();
        $this->departmentModel = new DepartmentModel();
        $this->scheduleModel = new ScheduleModel();
        $this->db = Database::getInstance()->getConnection();
    }

    private function resolveDepartmentId(): ?int {
        $user = Auth::getCurrentUser();
        $departmentId = $_GET['departmentId'] ?? null;
        if ($user['Role'] === 'DepartmentHead' && !empty($user['DepartmentID'])) {
            $departmentId = $user['DepartmentID'];
        }
        return $departmentId ? (int) $departmentId : null;
    }

    /**
     * GET /api/reports/summary
     */
    public function summary(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        $date = $_GET['date'] ?? date('Y-m-d');
        $departmentId = $this->resolveDepartmentId();

        $summary = $this->attendanceModel->getSummary($date, $departmentId);
        $totalFaculty = $departmentId
            ? $this->facultyModel->count(['DepartmentID' => $departmentId])
            : $this->facultyModel->count();

        $dayOfWeek = date('l', strtotime($date));
        $scheduledToday = $this->scheduleModel->countScheduledFaculty($dayOfWeek, $departmentId);
        $totalPresent = (int) ($summary['TotalPresent'] ?? 0);
        $absent = max(0, $scheduledToday - $totalPresent);

        Response::success([
            'date' => $date,
            'departmentId' => $departmentId,
            'totalFaculty' => $totalFaculty,
            'summary' => [
                'totalPresent' => $totalPresent,
                'onTime' => (int) ($summary['OnTime'] ?? 0),
                'late' => (int) ($summary['Late'] ?? 0),
                'noSchedule' => (int) ($summary['NoSchedule'] ?? 0),
                'wrongRoom' => (int) ($summary['WrongRoom'] ?? 0),
                'absent' => $absent
            ]
        ]);
    }

    /**
     * GET /api/reports/daily
     * Daily attendance report with full details
     */
    public function daily(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        $date = $_GET['date'] ?? date('Y-m-d');
        $departmentId = $this->resolveDepartmentId();
        $facultyId = $_GET['facultyId'] ?? null;
        $status = $_GET['status'] ?? null;

        $sql = "
            SELECT
                a.AttendanceID,
                a.Date,
                f.FacultyID,
                f.FacultyName,
                dept.DepartmentName,
                sub.SubjectName,
                sub.CourseCode,
                r.RoomName,
                r.Building,
                s.StartTime AS ScheduledStart,
                s.EndTime AS ScheduledEnd,
                a.TimeIn,
                a.TimeOut,
                a.AttendanceStatus,
                a.Remarks
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            LEFT JOIN departments dept ON f.DepartmentID = dept.DepartmentID
            LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
            LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
            LEFT JOIN rooms r ON s.RoomID = r.RoomID
            WHERE a.Date = ?
        ";
        $params = [$date];

        if ($departmentId) {
            $sql .= " AND f.DepartmentID = ?";
            $params[] = $departmentId;
        }
        if ($facultyId) {
            $sql .= " AND a.FacultyID = ?";
            $params[] = $facultyId;
        }
        if ($status) {
            $sql .= " AND a.AttendanceStatus = ?";
            $params[] = $status;
        }

        $sql .= " ORDER BY f.FacultyName, a.TimeIn";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();

        Response::success([
            'reportType' => 'daily',
            'date' => $date,
            'departmentId' => $departmentId,
            'totalRecords' => count($rows),
            'records' => $rows,
        ]);
    }

    /**
     * GET /api/reports/date-range
     * Aggregated summary for a date range
     */
    public function dateRange(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        $from = $_GET['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to = $_GET['to'] ?? date('Y-m-d');
        $departmentId = $this->resolveDepartmentId();

        $sql = "
            SELECT
                COUNT(*) AS totalRecords,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) AS totalPresent,
                SUM(CASE WHEN a.AttendanceStatus = 'Late' THEN 1 ELSE 0 END) AS totalLate,
                SUM(CASE WHEN a.AttendanceStatus IN ('No Schedule','Wrong Room') THEN 1 ELSE 0 END) AS totalExceptions
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            WHERE a.Date BETWEEN ? AND ?
        ";
        $params = [$from, $to];

        if ($departmentId) {
            $sql .= " AND f.DepartmentID = ?";
            $params[] = $departmentId;
        }

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $row = $stmt->fetch();

        $totalPresent = (int) ($row['totalPresent'] ?? 0);
        $totalLate = (int) ($row['totalLate'] ?? 0);
        $totalExceptions = (int) ($row['totalExceptions'] ?? 0);
        $totalRecords = (int) ($row['totalRecords'] ?? 0);

        // Count expected attendances
        $expStmt = $this->db->prepare("
            SELECT s.DayOfWeek, COUNT(DISTINCT s.FacultyID) AS facultyCount
            FROM schedules s
            JOIN faculties f ON s.FacultyID = f.FacultyID
            WHERE 1=1" . ($departmentId ? " AND f.DepartmentID = ?" : "") . "
            GROUP BY s.DayOfWeek
        ");
        $expStmt->execute($departmentId ? [$departmentId] : []);
        $scheduledByDay = [];
        while ($r = $expStmt->fetch()) {
            $scheduledByDay[$r['DayOfWeek']] = (int) $r['facultyCount'];
        }
        $expectedAttendances = 0;
        $cur = $from;
        while ($cur <= $to) {
            $dayName = date('l', strtotime($cur));
            $expectedAttendances += $scheduledByDay[$dayName] ?? 0;
            $cur = date('Y-m-d', strtotime($cur . ' +1 day'));
        }

        $attendanceRate = $expectedAttendances > 0
            ? round(($totalPresent / $expectedAttendances) * 100, 2)
            : 0.0;

        Response::success([
            'reportType' => 'date-range',
            'from' => $from,
            'to' => $to,
            'departmentId' => $departmentId,
            'totalScheduledSessions' => $expectedAttendances,
            'totalPresent' => $totalPresent,
            'totalLate' => $totalLate,
            'totalExceptions' => $totalExceptions,
            'attendanceRate' => $attendanceRate,
        ]);
    }

    /**
     * GET /api/reports/faculty-performance
     */
    public function facultyPerformance(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        $from = $_GET['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to = $_GET['to'] ?? date('Y-m-d');
        $departmentId = $this->resolveDepartmentId();
        $facultyId = $_GET['facultyId'] ?? null;

        $sql = "
            SELECT
                f.FacultyID,
                f.FacultyName,
                dept.DepartmentName,
                COUNT(a.AttendanceID) AS totalSessions,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) AS presentCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Late' THEN 1 ELSE 0 END) AS lateCount,
                SUM(CASE WHEN a.AttendanceStatus IN ('No Schedule','Wrong Room') THEN 1 ELSE 0 END) AS exceptionCount
            FROM faculties f
            LEFT JOIN departments dept ON f.DepartmentID = dept.DepartmentID
            LEFT JOIN attendances a ON f.FacultyID = a.FacultyID AND a.Date BETWEEN ? AND ?
            WHERE 1=1
        ";
        $params = [$from, $to];

        if ($departmentId) {
            $sql .= " AND f.DepartmentID = ?";
            $params[] = $departmentId;
        }
        if ($facultyId) {
            $sql .= " AND f.FacultyID = ?";
            $params[] = $facultyId;
        }

        $sql .= " GROUP BY f.FacultyID, f.FacultyName, dept.DepartmentName ORDER BY f.FacultyName";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $rows = [];
        while ($row = $stmt->fetch()) {
            $row['totalSessions'] = (int) $row['totalSessions'];
            $row['presentCount'] = (int) $row['presentCount'];
            $row['lateCount'] = (int) $row['lateCount'];
            $row['exceptionCount'] = (int) $row['exceptionCount'];
            $row['attendanceRate'] = $row['totalSessions'] > 0
                ? round(($row['presentCount'] / $row['totalSessions']) * 100, 2)
                : 0.0;
            $rows[] = $row;
        }

        Response::success([
            'reportType' => 'faculty-performance',
            'from' => $from,
            'to' => $to,
            'departmentId' => $departmentId,
            'records' => $rows,
        ]);
    }

    /**
     * GET /api/reports/room-utilization
     */
    public function roomUtilization(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        $from = $_GET['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to = $_GET['to'] ?? date('Y-m-d');
        $departmentId = $this->resolveDepartmentId();

        $sql = "
            SELECT
                r.RoomID,
                r.RoomName,
                r.Building,
                COUNT(DISTINCT s.ScheduleID) AS scheduledSessions,
                COUNT(DISTINCT a.AttendanceID) AS validAttendanceCount
            FROM rooms r
            INNER JOIN schedules s ON r.RoomID = s.RoomID
            INNER JOIN faculties f ON s.FacultyID = f.FacultyID
            LEFT JOIN attendances a ON a.ScheduleID = s.ScheduleID AND a.Date BETWEEN ? AND ?
            WHERE 1=1
        ";
        $params = [$from, $to];

        if ($departmentId) {
            $sql .= " AND f.DepartmentID = ?";
            $params[] = $departmentId;
        }

        $sql .= " GROUP BY r.RoomID, r.RoomName, r.Building HAVING scheduledSessions > 0 ORDER BY scheduledSessions DESC";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $rows = [];
        while ($row = $stmt->fetch()) {
            $row['RoomID'] = (int) $row['RoomID'];
            $row['scheduledSessions'] = (int) $row['scheduledSessions'];
            $row['validAttendanceCount'] = (int) $row['validAttendanceCount'];
            $daysInRange = max(1, (int) ((strtotime($to) - strtotime($from)) / 86400) + 1);
            $row['utilizationRate'] = $row['scheduledSessions'] > 0
                ? round(($row['validAttendanceCount'] / ($row['scheduledSessions'] * $daysInRange)) * 100, 2)
                : 0.0;
            $rows[] = $row;
        }

        Response::success([
            'reportType' => 'room-utilization',
            'from' => $from,
            'to' => $to,
            'departmentId' => $departmentId,
            'records' => $rows,
        ]);
    }

    /**
     * GET /api/reports/exceptions
     */
    public function exceptions(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        $from = $_GET['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to = $_GET['to'] ?? date('Y-m-d');
        $departmentId = $this->resolveDepartmentId();
        $status = $_GET['status'] ?? null;

        $sql = "
            SELECT
                a.AttendanceID,
                a.Date,
                f.FacultyID,
                f.FacultyName,
                dept.DepartmentName,
                sub.SubjectName,
                r.RoomName,
                r.Building,
                a.AttendanceStatus,
                a.TimeIn,
                a.Remarks
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            LEFT JOIN departments dept ON f.DepartmentID = dept.DepartmentID
            LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
            LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
            LEFT JOIN rooms r ON s.RoomID = r.RoomID
            WHERE a.Date BETWEEN ? AND ?
              AND a.AttendanceStatus != 'Present'
        ";
        $params = [$from, $to];

        if ($departmentId) {
            $sql .= " AND f.DepartmentID = ?";
            $params[] = $departmentId;
        }
        if ($status) {
            $sql .= " AND a.AttendanceStatus = ?";
            $params[] = $status;
        }

        $sql .= " ORDER BY a.Date DESC, f.FacultyName";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();

        Response::success([
            'reportType' => 'exceptions',
            'from' => $from,
            'to' => $to,
            'departmentId' => $departmentId,
            'totalRecords' => count($rows),
            'records' => $rows,
        ]);
    }

    /**
     * GET /api/reports/export-csv?type=daily|faculty-performance|room-utilization|exceptions
     */
    public function exportCsv(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        $type = $_GET['type'] ?? 'daily';

        // Capture the report data by calling the appropriate method internally
        ob_start();
        switch ($type) {
            case 'daily': $this->daily(); break;
            case 'date-range': $this->dateRange(); break;
            case 'faculty-performance': $this->facultyPerformance(); break;
            case 'room-utilization': $this->roomUtilization(); break;
            case 'exceptions': $this->exceptions(); break;
            default:
                Response::error('Invalid report type', 400);
                return;
        }
        $json = ob_get_clean();
        $data = json_decode($json, true);
        $reportData = $data['data'] ?? [];

        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="report_' . $type . '_' . date('Y-m-d_His') . '.csv"');

        $output = fopen('php://output', 'w');

        if ($type === 'date-range') {
            fputcsv($output, ['Metric', 'Value']);
            fputcsv($output, ['From', $reportData['from'] ?? '']);
            fputcsv($output, ['To', $reportData['to'] ?? '']);
            fputcsv($output, ['Total Scheduled Sessions', $reportData['totalScheduledSessions'] ?? 0]);
            fputcsv($output, ['Total Present', $reportData['totalPresent'] ?? 0]);
            fputcsv($output, ['Total Late', $reportData['totalLate'] ?? 0]);
            fputcsv($output, ['Total Exceptions', $reportData['totalExceptions'] ?? 0]);
            fputcsv($output, ['Attendance Rate %', $reportData['attendanceRate'] ?? 0]);
        } else {
            $records = $reportData['records'] ?? [];
            if (!empty($records)) {
                fputcsv($output, array_keys($records[0]));
                foreach ($records as $record) {
                    fputcsv($output, array_values($record));
                }
            }
        }

        fclose($output);
        exit;
    }

    /**
     * GET /api/reports/department
     */
    public function department(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        $departmentId = $this->resolveDepartmentId();
        $from = $_GET['from'] ?? date('Y-m-01');
        $to = $_GET['to'] ?? date('Y-m-d');

        if (!$departmentId) {
            Response::error('Department ID is required', 400);
        }

        $department = $this->departmentModel->findById($departmentId);
        if (!$department) {
            Response::notFound('Department not found');
        }

        $report = $this->attendanceModel->getDepartmentReport($departmentId, $from, $to);

        Response::success([
            'department' => $department,
            'from' => $from,
            'to' => $to,
            'facultyReport' => $report
        ]);
    }

    /**
     * GET /api/reports/dashboard
     */
    public function dashboard(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        $today = date('Y-m-d');
        $departmentId = $this->resolveDepartmentId();

        $todaySummary = $this->attendanceModel->getSummary($today, $departmentId);
        $totalFaculty = $departmentId
            ? $this->facultyModel->count(['DepartmentID' => $departmentId])
            : $this->facultyModel->count();
        $totalDepartments = $this->departmentModel->count();

        Response::success([
            'date' => $today,
            'stats' => [
                'totalFaculty' => $totalFaculty,
                'totalDepartments' => $totalDepartments,
                'presentToday' => (int) ($todaySummary['TotalPresent'] ?? 0),
                'lateToday' => (int) ($todaySummary['Late'] ?? 0),
                'onTimeToday' => (int) ($todaySummary['OnTime'] ?? 0)
            ],
        ]);
    }
}
