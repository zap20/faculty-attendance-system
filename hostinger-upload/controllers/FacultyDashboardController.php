<?php
/**
 * Faculty Dashboard Controller
 * Provides personal analytics endpoints for Faculty role only.
 * All queries filter by the authenticated user's FacultyID.
 */

class FacultyDashboardController {
    private $db;

    public function __construct() {
        $this->db = Database::getInstance()->getConnection();
    }

    /**
     * Get the authenticated faculty user's FacultyID
     */
    private function requireFaculty(): array {
        $user = Auth::requireAuth();
        if (empty($user['FacultyID'])) {
            Response::forbidden('Faculty access required');
        }
        return $user;
    }

    private function getDateRange(): array {
        $from = $_GET['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to   = $_GET['to']   ?? date('Y-m-d');
        return [$from, $to];
    }

    // ─────────────────────────────────────────────
    // 1) DASHBOARD SUMMARY
    // ─────────────────────────────────────────────
    public function dashboardSummary() {
        $user = $this->requireFaculty();
        $start = microtime(true);
        $facultyId = $user['FacultyID'];
        [$from, $to] = $this->getDateRange();

        // Attendance aggregates
        $stmt = $this->db->prepare("
            SELECT
                COUNT(*) as totalSessions,
                SUM(CASE WHEN AttendanceStatus = 'Present' THEN 1 ELSE 0 END) as totalPresent,
                SUM(CASE WHEN AttendanceStatus = 'Late'    THEN 1 ELSE 0 END) as totalLate,
                SUM(CASE WHEN AttendanceStatus = 'Absent'  THEN 1 ELSE 0 END) as totalAbsent,
                SUM(CASE WHEN AttendanceStatus NOT IN ('Present','Late','Absent') THEN 1 ELSE 0 END) as totalExceptions
            FROM attendances
            WHERE FacultyID = ? AND Date BETWEEN ? AND ?
        ");
        $stmt->execute([$facultyId, $from, $to]);
        $att = $stmt->fetch();

        $totalSessions = (int) ($att['totalSessions'] ?? 0);
        $totalPresent  = (int) ($att['totalPresent']  ?? 0);
        $totalLate     = (int) ($att['totalLate']     ?? 0);
        $totalAbsent   = (int) ($att['totalAbsent']   ?? 0);
        $totalExceptions = (int) ($att['totalExceptions'] ?? 0);

        $attendanceRate = $totalSessions > 0 ? round(($totalPresent / $totalSessions) * 100, 2) : 0;
        $punctualityDenom = $totalPresent + $totalLate;
        $punctualityIndex = $punctualityDenom > 0 ? round(($totalPresent / $punctualityDenom) * 100, 2) : 0;

        // Scheduled sessions count
        $stmt = $this->db->prepare("SELECT COUNT(*) as cnt FROM schedules WHERE FacultyID = ?");
        $stmt->execute([$facultyId]);
        $totalScheduledSessions = (int) $stmt->fetch()['cnt'];

        // Upcoming class today
        $today = date('Y-m-d');
        $dayMap = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
        $currentDay = $dayMap[date('N') - 1];
        $currentTime = date('H:i:s');

        $stmt = $this->db->prepare("
            SELECT s.*, sub.SubjectName, sub.CourseCode, r.RoomName, r.Building
            FROM schedules s
            LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
            LEFT JOIN rooms r ON s.RoomID = r.RoomID
            WHERE s.FacultyID = ? AND s.DayOfWeek = ? AND s.StartTime > ?
            ORDER BY s.StartTime ASC
            LIMIT 1
        ");
        $stmt->execute([$facultyId, $currentDay, $currentTime]);
        $upcomingClass = $stmt->fetch() ?: null;

        // Today's attendance status
        $stmt = $this->db->prepare("
            SELECT a.*, sub.SubjectName, sub.CourseCode, r.RoomName
            FROM attendances a
            LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
            LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
            LEFT JOIN rooms r ON s.RoomID = r.RoomID
            WHERE a.FacultyID = ? AND a.Date = ?
            ORDER BY a.TimeIn DESC
        ");
        $stmt->execute([$facultyId, $today]);
        $todayAttendance = $stmt->fetchAll();

        $responseTime = round((microtime(true) - $start) * 1000, 2);

        Response::success([
            'totalScheduledSessions' => $totalScheduledSessions,
            'totalSessions'          => $totalSessions,
            'totalPresent'           => $totalPresent,
            'totalLate'              => $totalLate,
            'totalAbsent'            => $totalAbsent,
            'totalExceptions'        => $totalExceptions,
            'attendanceRate'         => $attendanceRate,
            'punctualityIndex'       => $punctualityIndex,
            'upcomingClass'          => $upcomingClass,
            'todayAttendance'        => $todayAttendance,
            'dateRange'              => ['from' => $from, 'to' => $to],
            'responseTime'           => $responseTime,
        ]);
    }

    // ─────────────────────────────────────────────
    // 2) MY SCHEDULE
    // ─────────────────────────────────────────────
    public function schedule() {
        $user = $this->requireFaculty();
        $start = microtime(true);
        $facultyId = $user['FacultyID'];

        $stmt = $this->db->prepare("
            SELECT s.ScheduleID, s.DayOfWeek, s.StartTime, s.EndTime,
                   sub.SubjectName, sub.CourseCode, sub.Units,
                   r.RoomName, r.Building, r.Capacity
            FROM schedules s
            LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
            LEFT JOIN rooms r ON s.RoomID = r.RoomID
            WHERE s.FacultyID = ?
            ORDER BY FIELD(s.DayOfWeek, 'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'), s.StartTime
        ");
        $stmt->execute([$facultyId]);
        $schedules = $stmt->fetchAll();

        // Detect conflicts (overlapping times on same day)
        $conflicts = [];
        $byDay = [];
        foreach ($schedules as $s) {
            $byDay[$s['DayOfWeek']][] = $s;
        }
        foreach ($byDay as $day => $daySchedules) {
            for ($i = 0; $i < count($daySchedules); $i++) {
                for ($j = $i + 1; $j < count($daySchedules); $j++) {
                    if ($daySchedules[$i]['StartTime'] < $daySchedules[$j]['EndTime'] &&
                        $daySchedules[$j]['StartTime'] < $daySchedules[$i]['EndTime']) {
                        $conflicts[] = [
                            'day' => $day,
                            'schedule1' => $daySchedules[$i]['ScheduleID'],
                            'schedule2' => $daySchedules[$j]['ScheduleID'],
                        ];
                    }
                }
            }
        }

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success([
            'schedules' => $schedules,
            'conflicts' => $conflicts,
            'responseTime' => $responseTime,
        ]);
    }

    // ─────────────────────────────────────────────
    // 3) MY ATTENDANCE HISTORY
    // ─────────────────────────────────────────────
    public function attendance() {
        $user = $this->requireFaculty();
        $start = microtime(true);
        $facultyId = $user['FacultyID'];
        [$from, $to] = $this->getDateRange();

        $stmt = $this->db->prepare("
            SELECT a.AttendanceID, a.Date, a.TimeIn, a.TimeOut, a.AttendanceStatus, a.Remarks,
                   sub.SubjectName, sub.CourseCode,
                   r.RoomName, r.Building
            FROM attendances a
            LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
            LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
            LEFT JOIN rooms r ON s.RoomID = r.RoomID
            WHERE a.FacultyID = ? AND a.Date BETWEEN ? AND ?
            ORDER BY a.Date DESC, a.TimeIn DESC
        ");
        $stmt->execute([$facultyId, $from, $to]);
        $records = $stmt->fetchAll();

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success([
            'attendance' => $records,
            'dateRange'  => ['from' => $from, 'to' => $to],
            'responseTime' => $responseTime,
        ]);
    }

    // ─────────────────────────────────────────────
    // 4) ANALYTICS SUMMARY
    // ─────────────────────────────────────────────
    public function analyticsSummary() {
        $user = $this->requireFaculty();
        $start = microtime(true);
        $facultyId = $user['FacultyID'];
        [$from, $to] = $this->getDateRange();

        // Per-subject attendance rate
        $stmt = $this->db->prepare("
            SELECT
                sub.SubjectName,
                sub.CourseCode,
                COUNT(a.AttendanceID) as totalSessions,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) as presentCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Late'    THEN 1 ELSE 0 END) as lateCount,
                SUM(CASE WHEN a.AttendanceStatus = 'Absent'  THEN 1 ELSE 0 END) as absentCount
            FROM attendances a
            JOIN schedules s ON a.ScheduleID = s.ScheduleID
            JOIN subjects sub ON s.SubjectID = sub.SubjectID
            WHERE a.FacultyID = ? AND a.Date BETWEEN ? AND ?
            GROUP BY sub.SubjectID, sub.SubjectName, sub.CourseCode
            ORDER BY presentCount DESC
        ");
        $stmt->execute([$facultyId, $from, $to]);
        $subjectBreakdown = $stmt->fetchAll();

        $subjectStats = [];
        foreach ($subjectBreakdown as $s) {
            $total = (int) $s['totalSessions'];
            $present = (int) $s['presentCount'];
            $subjectStats[] = [
                'SubjectName'    => $s['SubjectName'],
                'CourseCode'     => $s['CourseCode'],
                'totalSessions'  => $total,
                'attendanceRate' => $total > 0 ? round(($present / $total) * 100, 2) : 0,
                'lateCount'      => (int) $s['lateCount'],
                'absentCount'    => (int) $s['absentCount'],
            ];
        }

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success([
            'subjectBreakdown' => $subjectStats,
            'responseTime'     => $responseTime,
        ]);
    }

    // ─────────────────────────────────────────────
    // 5) ATTENDANCE TREND (monthly)
    // ─────────────────────────────────────────────
    public function attendanceTrend() {
        $user = $this->requireFaculty();
        $start = microtime(true);
        $facultyId = $user['FacultyID'];
        [$from, $to] = $this->getDateRange();

        $stmt = $this->db->prepare("
            SELECT
                a.Date,
                COUNT(*) as totalRecords,
                SUM(CASE WHEN a.AttendanceStatus = 'Present' THEN 1 ELSE 0 END) as totalPresent,
                SUM(CASE WHEN a.AttendanceStatus = 'Late'    THEN 1 ELSE 0 END) as totalLate,
                SUM(CASE WHEN a.AttendanceStatus = 'Absent'  THEN 1 ELSE 0 END) as totalAbsent,
                SUM(CASE WHEN a.AttendanceStatus NOT IN ('Present','Late','Absent') THEN 1 ELSE 0 END) as totalExceptions
            FROM attendances a
            WHERE a.FacultyID = ? AND a.Date BETWEEN ? AND ?
            GROUP BY a.Date
            ORDER BY a.Date
        ");
        $stmt->execute([$facultyId, $from, $to]);
        $rows = $stmt->fetchAll();

        $trend = [];
        foreach ($rows as $r) {
            $total = (int) $r['totalRecords'];
            $present = (int) $r['totalPresent'];
            $trend[] = [
                'date'           => $r['Date'],
                'totalPresent'   => $present,
                'totalLate'      => (int) $r['totalLate'],
                'totalAbsent'    => (int) $r['totalAbsent'],
                'totalExceptions'=> (int) $r['totalExceptions'],
                'attendanceRate' => $total > 0 ? round(($present / $total) * 100, 2) : 0,
            ];
        }

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success(['trend' => $trend, 'responseTime' => $responseTime]);
    }

    // ─────────────────────────────────────────────
    // 6) STATUS BREAKDOWN
    // ─────────────────────────────────────────────
    public function statusBreakdown() {
        $user = $this->requireFaculty();
        $start = microtime(true);
        $facultyId = $user['FacultyID'];
        [$from, $to] = $this->getDateRange();

        $stmt = $this->db->prepare("
            SELECT
                AttendanceStatus,
                COUNT(*) as Count
            FROM attendances
            WHERE FacultyID = ? AND Date BETWEEN ? AND ?
            GROUP BY AttendanceStatus
            ORDER BY Count DESC
        ");
        $stmt->execute([$facultyId, $from, $to]);
        $rows = $stmt->fetchAll();

        $breakdown = [];
        foreach ($rows as $r) {
            $breakdown[] = [
                'status' => $r['AttendanceStatus'],
                'count'  => (int) $r['Count'],
            ];
        }

        $responseTime = round((microtime(true) - $start) * 1000, 2);
        Response::success(['breakdown' => $breakdown, 'responseTime' => $responseTime]);
    }
}
