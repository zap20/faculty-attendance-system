<?php
/**
 * Admin Analytics Controller
 * Provides system-wide analytics endpoints for Admin role only.
 * All queries use prepared statements and optimized GROUP BY aggregations.
 */

class AdminAnalyticsController {
    private $db;

    public function __construct() {
        $this->db = Database::getInstance()->getConnection();
    }

    /**
     * Verify the current user is Admin role
     */
    private function requireAdmin(): array {
        $user = Auth::requireAuth();
        if ($user['Role'] !== 'Admin') {
            Response::forbidden('Admin access required');
        }
        return $user;
    }

    /**
     * Parse optional date range filters from query params.
     * Defaults: from = 30 days ago, to = today
     */
    private function getDateRange(): array {
        $from = $_GET['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to   = $_GET['to']   ?? date('Y-m-d');
        return [$from, $to];
    }

    // ─────────────────────────────────────────────
    // 1) SYSTEM-WIDE KPI SUMMARY
    // ─────────────────────────────────────────────
    public function summary() {
        $this->requireAdmin();
        $start = microtime(true);
        [$from, $to] = $this->getDateRange();

        $departmentId = $_GET['department_id'] ?? null;
        $facultyId    = $_GET['faculty_id']    ?? null;
        $subjectId    = $_GET['subject_id']    ?? null;
        $roomId       = $_GET['room_id']       ?? null;

        // Total departments
        $stmt = $this->db->query("SELECT COUNT(*) as cnt FROM departments");
        $totalDepartments = (int) $stmt->fetch()['cnt'];

        // Total faculty
        $stmt = $this->db->query("SELECT COUNT(*) as cnt FROM faculties");
        $totalFaculty = (int) $stmt->fetch()['cnt'];

        // Scheduled sessions in range (count schedule × weekdays in range)
        $scheduledSql = "
            SELECT COUNT(*) as cnt
            FROM schedules s
            JOIN faculties f ON s.FacultyID = f.FacultyID
            WHERE 1=1
        ";
        $scheduledParams = [];
        if ($departmentId) { $scheduledSql .= " AND f.DepartmentID = ?"; $scheduledParams[] = $departmentId; }
        if ($facultyId)    { $scheduledSql .= " AND s.FacultyID = ?";    $scheduledParams[] = $facultyId; }
        if ($subjectId)    { $scheduledSql .= " AND s.SubjectID = ?";    $scheduledParams[] = $subjectId; }
        if ($roomId)       { $scheduledSql .= " AND s.RoomID = ?";       $scheduledParams[] = $roomId; }
        $stmt = $this->db->prepare($scheduledSql);
        $stmt->execute($scheduledParams);
        $totalSchedules = (int) $stmt->fetch()['cnt'];

        // Count weekdays in range to estimate total scheduled sessions
        $totalScheduledSessions = $this->countWeekdaysInRange($from, $to) * $totalSchedules;
        if ($totalScheduledSessions === 0) {
            // Fallback: use raw schedule count
            $totalScheduledSessions = max($totalSchedules, 1);
        }

        // Attendance aggregates in range
        $attSql = "
            SELECT
                COUNT(*)                                                          as totalRecords,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END)  as totalPresent,
                SUM(CASE WHEN a.AttendanceStatus = 'Late'    THEN 1 ELSE 0 END)  as totalLate,
                SUM(CASE WHEN a.AttendanceStatus NOT IN ('Present','Late','Absent') THEN 1 ELSE 0 END) as totalExceptions
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
            WHERE a.Date BETWEEN ? AND ?
        ";
        $attParams = [$from, $to];
        if ($departmentId) { $attSql .= " AND f.DepartmentID = ?"; $attParams[] = $departmentId; }
        if ($facultyId)    { $attSql .= " AND a.FacultyID = ?";    $attParams[] = $facultyId; }
        if ($subjectId)    { $attSql .= " AND s.SubjectID = ?";    $attParams[] = $subjectId; }
        if ($roomId)       { $attSql .= " AND s.RoomID = ?";       $attParams[] = $roomId; }

        $stmt = $this->db->prepare($attSql);
        $stmt->execute($attParams);
        $att = $stmt->fetch();

        $totalPresent    = (int) ($att['totalPresent']    ?? 0);
        $totalLate       = (int) ($att['totalLate']       ?? 0);
        $totalExceptions = (int) ($att['totalExceptions'] ?? 0);
        $totalRecords    = (int) ($att['totalRecords']    ?? 0);

        $globalAttendanceRate = $totalRecords > 0
            ? round(($totalPresent / $totalRecords) * 100, 2)
            : 0;

        // Active devices
        $stmt = $this->db->query("SELECT COUNT(*) as cnt FROM attendancedevices WHERE Status = 'Active'");
        $totalActiveDevices = (int) $stmt->fetch()['cnt'];

        $responseTime = round((microtime(true) - $start) * 1000, 2);

        Response::success([
            'totalDepartments'      => $totalDepartments,
            'totalFaculty'          => $totalFaculty,
            'totalScheduledSessions'=> $totalScheduledSessions,
            'totalPresent'          => $totalPresent,
            'totalLate'             => $totalLate,
            'totalExceptions'       => $totalExceptions,
            'globalAttendanceRate'  => $globalAttendanceRate,
            'totalActiveDevices'    => $totalActiveDevices,
            'dateRange'             => ['from' => $from, 'to' => $to],
            'responseTime'          => $responseTime,
        ]);
    }

    // ─────────────────────────────────────────────
    // 2) DEPARTMENT COMPARATIVE ANALYTICS
    // ─────────────────────────────────────────────
    public function departmentComparison() {
        $this->requireAdmin();
        $start = microtime(true);
        [$from, $to] = $this->getDateRange();

        $stmt = $this->db->prepare("
            SELECT
                d.DepartmentID,
                d.DepartmentName,
                COUNT(DISTINCT f.FacultyID) as totalFaculty,
                COUNT(a.AttendanceID) as totalSessions,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) as presentCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Late'    THEN 1 ELSE 0 END) as lateCount,
                SUM(CASE WHEN a.AttendanceStatus NOT IN ('Present','Late','Absent') THEN 1 ELSE 0 END) as exceptionCount
            FROM departments d
            LEFT JOIN faculties f ON d.DepartmentID = f.DepartmentID
            LEFT JOIN attendances a ON f.FacultyID = a.FacultyID AND a.Date BETWEEN ? AND ?
            GROUP BY d.DepartmentID, d.DepartmentName
            ORDER BY presentCount DESC
        ");
        $stmt->execute([$from, $to]);
        $rows = $stmt->fetchAll();

        $result = [];
        foreach ($rows as $r) {
            $total = (int) $r['totalSessions'];
            $present = (int) $r['presentCount'];
            $late = (int) $r['lateCount'];
            $exceptions = (int) $r['exceptionCount'];
            $result[] = [
                'DepartmentID'   => (int) $r['DepartmentID'],
                'DepartmentName' => $r['DepartmentName'],
                'totalFaculty'   => (int) $r['totalFaculty'],
                'totalSessions'  => $total,
                'attendanceRate' => $total > 0 ? round(($present / $total) * 100, 2) : 0,
                'lateRate'       => $total > 0 ? round(($late / $total) * 100, 2) : 0,
                'exceptionRate'  => $total > 0 ? round(($exceptions / $total) * 100, 2) : 0,
            ];
        }

        // Sort by attendanceRate descending
        usort($result, fn($a, $b) => $b['attendanceRate'] <=> $a['attendanceRate']);

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success(['departments' => $result, 'responseTime' => $responseTime]);
    }

    // ─────────────────────────────────────────────
    // 3) DEPARTMENT RANKING
    // ─────────────────────────────────────────────
    public function departmentRanking() {
        $this->requireAdmin();
        $start = microtime(true);
        [$from, $to] = $this->getDateRange();

        $stmt = $this->db->prepare("
            SELECT
                d.DepartmentID,
                d.DepartmentName,
                COUNT(a.AttendanceID) as totalSessions,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) as presentCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Late'    THEN 1 ELSE 0 END) as lateCount,
                SUM(CASE WHEN a.AttendanceStatus NOT IN ('Present','Late','Absent') THEN 1 ELSE 0 END) as exceptionCount
            FROM departments d
            LEFT JOIN faculties f ON d.DepartmentID = f.DepartmentID
            LEFT JOIN attendances a ON f.FacultyID = a.FacultyID AND a.Date BETWEEN ? AND ?
            GROUP BY d.DepartmentID, d.DepartmentName
        ");
        $stmt->execute([$from, $to]);
        $rows = $stmt->fetchAll();

        $result = [];
        foreach ($rows as $r) {
            $total = (int) $r['totalSessions'];
            $present = (int) $r['presentCount'];
            $late = (int) $r['lateCount'];
            $exceptions = (int) $r['exceptionCount'];
            $attendanceRate = $total > 0 ? round(($present / $total) * 100, 2) : 0;
            // Punctuality index: present on-time / (present + late) * 100
            $punctualityDenom = $present + $late;
            $punctualityIndex = $punctualityDenom > 0 ? round(($present / $punctualityDenom) * 100, 2) : 0;

            $result[] = [
                'DepartmentName'  => $r['DepartmentName'],
                'attendanceRate'  => $attendanceRate,
                'exceptionCount'  => $exceptions,
                'punctualityIndex'=> $punctualityIndex,
            ];
        }

        // Sort by attendanceRate descending
        usort($result, fn($a, $b) => $b['attendanceRate'] <=> $a['attendanceRate']);

        // Add rank
        foreach ($result as $i => &$item) {
            $item['Rank'] = $i + 1;
        }
        unset($item);

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success(['rankings' => $result, 'responseTime' => $responseTime]);
    }

    // ─────────────────────────────────────────────
    // 4) GLOBAL ATTENDANCE TREND (Time Series)
    // ─────────────────────────────────────────────
    public function attendanceTrend() {
        $this->requireAdmin();
        $start = microtime(true);
        [$from, $to] = $this->getDateRange();

        $departmentId = $_GET['department_id'] ?? null;
        $facultyId    = $_GET['faculty_id']    ?? null;

        $sql = "
            SELECT
                a.Date,
                COUNT(*)                                                          as totalRecords,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END)  as totalPresent,
                SUM(CASE WHEN a.AttendanceStatus = 'Late'    THEN 1 ELSE 0 END)  as totalLate,
                SUM(CASE WHEN a.AttendanceStatus NOT IN ('Present','Late','Absent') THEN 1 ELSE 0 END) as totalExceptions
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            WHERE a.Date BETWEEN ? AND ?
        ";
        $params = [$from, $to];
        if ($departmentId) { $sql .= " AND f.DepartmentID = ?"; $params[] = $departmentId; }
        if ($facultyId)    { $sql .= " AND a.FacultyID = ?";    $params[] = $facultyId; }
        $sql .= " GROUP BY a.Date ORDER BY a.Date";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();

        $trend = [];
        foreach ($rows as $r) {
            $total = (int) $r['totalRecords'];
            $present = (int) $r['totalPresent'];
            $trend[] = [
                'date'                 => $r['Date'],
                'totalPresent'         => $present,
                'totalLate'            => (int) $r['totalLate'],
                'totalExceptions'      => (int) $r['totalExceptions'],
                'globalAttendanceRate' => $total > 0 ? round(($present / $total) * 100, 2) : 0,
            ];
        }

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success(['trend' => $trend, 'responseTime' => $responseTime]);
    }

    // ─────────────────────────────────────────────
    // 5) EXCEPTION HEATMAP DATA
    // ─────────────────────────────────────────────
    public function exceptionHeatmap() {
        $this->requireAdmin();
        $start = microtime(true);
        [$from, $to] = $this->getDateRange();

        $stmt = $this->db->prepare("
            SELECT
                d.DepartmentName,
                a.AttendanceStatus as ExceptionType,
                COUNT(*) as Count
            FROM attendances a
            JOIN faculties f ON a.FacultyID = f.FacultyID
            JOIN departments d ON f.DepartmentID = d.DepartmentID
            WHERE a.Date BETWEEN ? AND ?
              AND a.AttendanceStatus NOT IN ('Present', 'Late', 'Absent')
            GROUP BY d.DepartmentName, a.AttendanceStatus
            ORDER BY d.DepartmentName, Count DESC
        ");
        $stmt->execute([$from, $to]);
        $rows = $stmt->fetchAll();

        $heatmap = [];
        foreach ($rows as $r) {
            $heatmap[] = [
                'DepartmentName' => $r['DepartmentName'],
                'ExceptionType'  => $r['ExceptionType'],
                'Count'          => (int) $r['Count'],
            ];
        }

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success(['heatmap' => $heatmap, 'responseTime' => $responseTime]);
    }

    // ─────────────────────────────────────────────
    // 6) ROOM UTILIZATION ACROSS DEPARTMENTS
    // ─────────────────────────────────────────────
    public function roomUtilization() {
        $this->requireAdmin();
        $start = microtime(true);
        [$from, $to] = $this->getDateRange();

        $stmt = $this->db->prepare("
            SELECT
                r.RoomID,
                r.RoomName,
                r.Building,
                d.DepartmentName,
                COUNT(DISTINCT s.ScheduleID) as scheduledSessions,
                COUNT(DISTINCT a.AttendanceID) as attendanceRecorded
            FROM rooms r
            LEFT JOIN schedules s ON r.RoomID = s.RoomID
            LEFT JOIN faculties f ON s.FacultyID = f.FacultyID
            LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
            LEFT JOIN attendances a ON s.ScheduleID = a.ScheduleID AND a.Date BETWEEN ? AND ?
            GROUP BY r.RoomID, r.RoomName, r.Building, d.DepartmentName
            ORDER BY attendanceRecorded DESC
        ");
        $stmt->execute([$from, $to]);
        $rows = $stmt->fetchAll();

        $result = [];
        foreach ($rows as $r) {
            $scheduled = (int) $r['scheduledSessions'];
            $recorded  = (int) $r['attendanceRecorded'];
            $result[] = [
                'RoomName'            => $r['RoomName'],
                'Building'            => $r['Building'],
                'DepartmentName'      => $r['DepartmentName'] ?? 'Unassigned',
                'scheduledSessions'   => $scheduled,
                'attendanceRecorded'  => $recorded,
                'utilizationRate'     => $scheduled > 0 ? round(($recorded / $scheduled) * 100, 2) : 0,
            ];
        }

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success(['rooms' => $result, 'responseTime' => $responseTime]);
    }

    // ─────────────────────────────────────────────
    // 7) FACULTY GLOBAL PERFORMANCE ANALYTICS
    // ─────────────────────────────────────────────
    public function facultyPerformance() {
        $this->requireAdmin();
        $start = microtime(true);
        [$from, $to] = $this->getDateRange();

        $departmentId = $_GET['department_id'] ?? null;

        $sql = "
            SELECT
                f.FacultyID,
                f.FacultyName,
                d.DepartmentID,
                d.DepartmentName,
                COUNT(a.AttendanceID) as totalSessions,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) as presentCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Late'    THEN 1 ELSE 0 END) as lateCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Absent'  THEN 1 ELSE 0 END) as absentCount,
                SUM(CASE WHEN a.AttendanceStatus NOT IN ('Present','Late','Absent') THEN 1 ELSE 0 END) as exceptionCount
            FROM faculties f
            JOIN departments d ON f.DepartmentID = d.DepartmentID
            LEFT JOIN attendances a ON f.FacultyID = a.FacultyID AND a.Date BETWEEN ? AND ?
            WHERE 1=1
        ";
        $params = [$from, $to];
        if ($departmentId) { $sql .= " AND f.DepartmentID = ?"; $params[] = $departmentId; }
        $sql .= " GROUP BY f.FacultyID, f.FacultyName, d.DepartmentID, d.DepartmentName ORDER BY d.DepartmentName, presentCount DESC";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();

        $result = [];
        foreach ($rows as $r) {
            $total = (int) $r['totalSessions'];
            $present = (int) $r['presentCount'];
            $result[] = [
                'FacultyID'      => $r['FacultyID'],
                'FacultyName'    => $r['FacultyName'],
                'DepartmentID'   => (int) $r['DepartmentID'],
                'DepartmentName' => $r['DepartmentName'],
                'totalSessions'  => $total,
                'attendanceRate' => $total > 0 ? round(($present / $total) * 100, 2) : 0,
                'lateCount'      => (int) $r['lateCount'],
                'absentCount'    => (int) $r['absentCount'],
                'exceptionCount' => (int) $r['exceptionCount'],
            ];
        }

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success(['faculty' => $result, 'responseTime' => $responseTime]);
    }

    // ─────────────────────────────────────────────
    // HELPER: count weekdays (Mon-Fri) in a date range
    // ─────────────────────────────────────────────
    private function countWeekdaysInRange(string $from, string $to): int {
        $start = new \DateTime($from);
        $end   = new \DateTime($to);
        $end->modify('+1 day');
        $count = 0;
        $interval = new \DateInterval('P1D');
        $period = new \DatePeriod($start, $interval, $end);
        foreach ($period as $day) {
            $dow = (int) $day->format('N');
            if ($dow <= 5) $count++;
        }
        return $count;
    }
}
