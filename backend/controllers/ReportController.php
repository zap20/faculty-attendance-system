<?php
/**
 * Report Controller
 * Handles attendance reports and summaries
 */

class ReportController {
    private $attendanceModel;
    private $facultyModel;
    private $departmentModel;

    public function __construct() {
        $this->attendanceModel = new AttendanceModel();
        $this->facultyModel = new FacultyModel();
        $this->departmentModel = new DepartmentModel();
    }

    /**
     * GET /api/reports/summary
     * Get attendance summary for a specific date
     */
    public function summary(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        
        $user = Auth::getCurrentUser();
        $date = $_GET['date'] ?? date('Y-m-d');
        $departmentId = $_GET['departmentId'] ?? null;

        // DepartmentHead can only see their department
        if ($user['Role'] === 'DepartmentHead' && $user['DepartmentID']) {
            $departmentId = $user['DepartmentID'];
        }

        $summary = $this->attendanceModel->getSummary($date, $departmentId);

        // Get total faculty count for comparison
        if ($departmentId) {
            $totalFaculty = $this->facultyModel->count(['DepartmentID' => $departmentId]);
        } else {
            $totalFaculty = $this->facultyModel->count();
        }

        Response::success([
            'date' => $date,
            'departmentId' => $departmentId,
            'totalFaculty' => $totalFaculty,
            'summary' => [
                'totalPresent' => (int) ($summary['TotalPresent'] ?? 0),
                'onTime' => (int) ($summary['OnTime'] ?? 0),
                'late' => (int) ($summary['Late'] ?? 0),
                'noSchedule' => (int) ($summary['NoSchedule'] ?? 0),
                'wrongRoom' => (int) ($summary['WrongRoom'] ?? 0),
                'absent' => $totalFaculty - (int) ($summary['TotalPresent'] ?? 0)
            ]
        ]);
    }

    /**
     * GET /api/reports/department
     * Get department attendance report for date range
     */
    public function department(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        
        $user = Auth::getCurrentUser();
        $departmentId = $_GET['departmentId'] ?? null;
        $from = $_GET['from'] ?? date('Y-m-01');
        $to = $_GET['to'] ?? date('Y-m-d');

        // DepartmentHead can only see their department
        if ($user['Role'] === 'DepartmentHead' && $user['DepartmentID']) {
            $departmentId = $user['DepartmentID'];
        }

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
     * Get dashboard statistics
     */
    public function dashboard(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        
        $user = Auth::getCurrentUser();
        $today = date('Y-m-d');
        $departmentId = null;

        // DepartmentHead can only see their department
        if ($user['Role'] === 'DepartmentHead' && $user['DepartmentID']) {
            $departmentId = $user['DepartmentID'];
        }

        // Today's summary
        $todaySummary = $this->attendanceModel->getSummary($today, $departmentId);

        // Get counts
        if ($departmentId) {
            $totalFaculty = $this->facultyModel->count(['DepartmentID' => $departmentId]);
        } else {
            $totalFaculty = $this->facultyModel->count();
        }
        $totalDepartments = $this->departmentModel->count();

        // Recent attendance (last 7 days)
        $weekAgo = date('Y-m-d', strtotime('-7 days'));
        $recentAttendance = $this->attendanceModel->findAllWithDetails([
            'from' => $weekAgo,
            'to' => $today,
            'departmentId' => $departmentId
        ]);

        Response::success([
            'date' => $today,
            'stats' => [
                'totalFaculty' => $totalFaculty,
                'totalDepartments' => $totalDepartments,
                'presentToday' => (int) ($todaySummary['TotalPresent'] ?? 0),
                'lateToday' => (int) ($todaySummary['Late'] ?? 0),
                'onTimeToday' => (int) ($todaySummary['OnTime'] ?? 0)
            ],
            'recentAttendanceCount' => count($recentAttendance)
        ]);
    }
}
