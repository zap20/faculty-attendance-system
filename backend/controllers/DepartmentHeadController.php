<?php
/**
 * Department Head Controller
 * Department-scoped management and analytics
 */

class DepartmentHeadController {
    private $attendanceModel;
    private $facultyModel;
    private $scheduleModel;
    private $subjectModel;
    private $roomModel;
    private $userModel;
    private $departmentModel;

    public function __construct() {
        $this->attendanceModel = new AttendanceModel();
        $this->facultyModel = new FacultyModel();
        $this->scheduleModel = new ScheduleModel();
        $this->subjectModel = new SubjectModel();
        $this->roomModel = new RoomModel();
        $this->userModel = new UserModel();
        $this->departmentModel = new DepartmentModel();
    }

    private function requireDepartmentHead(): array {
        $user = Auth::requireRole(['DepartmentHead']);

        if (empty($user['DepartmentID'])) {
            Response::error('DepartmentHead account is not linked to any department', 400);
        }

        return $user;
    }

    /**
     * GET /api/department-head/dashboard/summary?date=YYYY-MM-DD
     */
    public function dashboardSummary(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $date = $_GET['date'] ?? date('Y-m-d');

        // Basic validation
        $d = DateTime::createFromFormat('Y-m-d', $date);
        if (!$d || $d->format('Y-m-d') !== $date) {
            Response::error('Invalid date format. Use YYYY-MM-DD', 400);
        }

        $totalFaculty = $this->facultyModel->count(['DepartmentID' => $departmentId]);
        $summary = $this->attendanceModel->getSummary($date, $departmentId);

        $weekFrom = date('Y-m-d', strtotime($date . ' -6 days'));
        $weekTo = $date;
        $weeklyRate = $this->attendanceModel->getAttendanceRate($departmentId, $weekFrom, $weekTo, $totalFaculty);
        $topExceptions = $this->attendanceModel->getTopExceptions($departmentId, $weekFrom, $weekTo, 5);

        Response::success([
            'date' => $date,
            'departmentId' => $departmentId,
            'totalFaculty' => (int) $totalFaculty,
            'attendanceToday' => [
                'present' => (int) ($summary['TotalPresent'] ?? 0),
                'onTime' => (int) ($summary['OnTime'] ?? 0),
                'late' => (int) ($summary['Late'] ?? 0),
                'noSchedule' => (int) ($summary['NoSchedule'] ?? 0),
                'wrongRoom' => (int) ($summary['WrongRoom'] ?? 0),
                'absent' => (int) $totalFaculty - (int) ($summary['TotalPresent'] ?? 0)
            ],
            'weeklyAttendanceRate' => $weeklyRate,
            'topExceptions' => $topExceptions,
        ]);
    }

    /**
     * GET /api/department-head/analytics?from=YYYY-MM-DD&to=YYYY-MM-DD&facultyId=&subjectId=&roomId=
     */
    public function analytics(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $from = $_GET['from'] ?? date('Y-m-d', strtotime('-6 days'));
        $to = $_GET['to'] ?? date('Y-m-d');

        $fromD = DateTime::createFromFormat('Y-m-d', $from);
        $toD = DateTime::createFromFormat('Y-m-d', $to);
        if (!$fromD || $fromD->format('Y-m-d') !== $from || !$toD || $toD->format('Y-m-d') !== $to) {
            Response::error('Invalid date range. Use from/to as YYYY-MM-DD', 400);
        }
        if ($from > $to) {
            Response::error('from must be before or equal to to', 400);
        }

        $filters = [
            'facultyId' => $_GET['facultyId'] ?? null,
            'subjectId' => $_GET['subjectId'] ?? null,
            'roomId' => $_GET['roomId'] ?? null,
        ];

        // Enforce faculty belongs to the same department if provided
        if (!empty($filters['facultyId'])) {
            $faculty = $this->facultyModel->findById($filters['facultyId']);
            if (!$faculty) {
                Response::notFound('Faculty not found');
            }
            if ((int) $faculty['DepartmentID'] !== $departmentId) {
                Response::forbidden('Cannot access faculty from other departments');
            }
        }

        $totalFaculty = $this->facultyModel->count(['DepartmentID' => $departmentId]);

        $breakdown = $this->attendanceModel->getStatusBreakdown($departmentId, $from, $to, $filters);
        $trend = $this->attendanceModel->getTrendByDay($departmentId, $from, $to, $filters);
        $topExceptions = $this->attendanceModel->getTopExceptions($departmentId, $from, $to, 5, $filters);
        $rate = $this->attendanceModel->getAttendanceRate($departmentId, $from, $to, $totalFaculty);

        Response::success([
            'departmentId' => $departmentId,
            'from' => $from,
            'to' => $to,
            'filters' => $filters,
            'kpis' => [
                'totalFaculty' => (int) $totalFaculty,
                'attendanceRate' => $rate,
            ],
            'charts' => [
                'statusBreakdown' => $breakdown,
                'trendByDay' => $trend,
            ],
            'topExceptions' => $topExceptions,
        ]);
    }

    /**
     * POST /api/department-head/faculties
     * Body: {facultyName, position, employmentStatus, contactInformation, username, tempPassword}
     */
    public function createFacultyWithAccount(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('facultyName', 'Faculty name')
                  ->required('position', 'Position')
                  ->required('employmentStatus', 'Employment status')
                  ->required('username', 'Username')
                  ->required('tempPassword', 'Temporary password')
                  ->minLength('tempPassword', 6, 'Temporary password')
                  ->validate();

        $username = trim($data['username']);
        if ($this->userModel->usernameExists($username)) {
            Response::error('Username already exists', 400);
        }

        $db = Database::getInstance()->getConnection();
        $db->beginTransaction();

        try {
            $facultyId = $this->facultyModel->generateNextFacultyId();
            $this->facultyModel->createWithId([
                'FacultyID' => $facultyId,
                'FacultyName' => $data['facultyName'],
                'DepartmentID' => $departmentId,
                'Position' => $data['position'],
                'EmploymentStatus' => $data['employmentStatus'],
                'ContactInformation' => $data['contactInformation'] ?? null
            ]);

            $userId = $this->userModel->create([
                'Username' => $username,
                'Password' => Auth::hashPassword($data['tempPassword']),
                'Role' => 'Faculty',
                'FacultyID' => $facultyId,
                'IsActive' => 1
            ]);

            $db->commit();

            $faculty = $this->facultyModel->findByIdWithDepartment($facultyId);

            Response::success([
                'faculty' => $faculty,
                'userAccount' => [
                    'userId' => (int) $userId,
                    'username' => $username,
                    'role' => 'Faculty',
                    'facultyId' => $facultyId,
                ],
                'credentials' => [
                    'username' => $username,
                    'tempPassword' => $data['tempPassword'],
                ],
            ], 'Faculty account created', 201);

        } catch (Exception $e) {
            $db->rollBack();
            Response::error('Failed to create faculty account: ' . $e->getMessage(), 500);
        }
    }

    /**
     * GET /api/department-head/schedules?from=YYYY-MM-DD&to=YYYY-MM-DD&facultyId=...
     */
    public function schedulesIndex(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $from = $_GET['from'] ?? null;
        $to = $_GET['to'] ?? null;
        $facultyId = $_GET['facultyId'] ?? null;

        $days = null;
        if (!empty($from) && !empty($to)) {
            $fromD = DateTime::createFromFormat('Y-m-d', $from);
            $toD = DateTime::createFromFormat('Y-m-d', $to);
            if (!$fromD || $fromD->format('Y-m-d') !== $from || !$toD || $toD->format('Y-m-d') !== $to) {
                Response::error('Invalid date range. Use from/to as YYYY-MM-DD', 400);
            }

            $days = [];
            $cursor = new DateTime($from);
            $end = new DateTime($to);
            while ($cursor <= $end) {
                $days[] = $cursor->format('l');
                $cursor->modify('+1 day');
            }
            $days = array_values(array_unique($days));
        }

        if (!empty($facultyId)) {
            $faculty = $this->facultyModel->findById($facultyId);
            if (!$faculty) {
                Response::notFound('Faculty not found');
            }
            if ((int) $faculty['DepartmentID'] !== $departmentId) {
                Response::forbidden('Cannot view schedules for faculty from other departments');
            }
        }

        $schedules = $this->scheduleModel->findByDepartment($departmentId, $facultyId, $days);
        Response::success($schedules);
    }

    /**
     * POST /api/department-head/schedules
     */
    public function schedulesStore(): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $data = json_decode(file_get_contents('php://input'), true);

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

        $faculty = $this->facultyModel->findById($data['FacultyID']);
        if (!$faculty) {
            Response::notFound('Faculty not found');
        }
        if ((int) $faculty['DepartmentID'] !== $departmentId) {
            Response::forbidden('Cannot create schedules for faculty from other departments');
        }

        $subject = $this->subjectModel->findById((int) $data['SubjectID']);
        if (!$subject) {
            Response::notFound('Subject not found');
        }
        if ((int) $subject['DepartmentID'] !== $departmentId) {
            Response::forbidden('Cannot use a subject from another department');
        }

        if (!$this->roomModel->exists((int) $data['RoomID'])) {
            Response::notFound('Room not found');
        }

        if ($data['StartTime'] >= $data['EndTime']) {
            Response::error('End time must be after start time', 400);
        }

        $conflicts = $this->scheduleModel->checkConflicts(
            $data['FacultyID'],
            (int) $data['RoomID'],
            $data['DayOfWeek'],
            $data['StartTime'],
            $data['EndTime']
        );

        if (!empty($conflicts)) {
            Response::error('Schedule conflicts detected', 409, $conflicts);
        }

        $scheduleId = $this->scheduleModel->create([
            'FacultyID' => $data['FacultyID'],
            'SubjectID' => (int) $data['SubjectID'],
            'RoomID' => (int) $data['RoomID'],
            'DayOfWeek' => $data['DayOfWeek'],
            'StartTime' => $data['StartTime'],
            'EndTime' => $data['EndTime']
        ]);

        $schedule = $this->scheduleModel->findByIdWithDetails($scheduleId);
        Response::success($schedule, 'Schedule created successfully', 201);
    }

    /**
     * PUT /api/department-head/schedules/{id}
     */
    public function schedulesUpdate(int $id): void {
        $user = $this->requireDepartmentHead();
        $departmentId = (int) $user['DepartmentID'];

        $schedule = $this->scheduleModel->findByIdWithDetails($id);
        if (!$schedule) {
            Response::notFound('Schedule not found');
        }

        $scheduleFaculty = $this->facultyModel->findById($schedule['FacultyID']);
        if (!$scheduleFaculty || (int) $scheduleFaculty['DepartmentID'] !== $departmentId) {
            Response::forbidden('Cannot edit schedule from another department');
        }

        $data = json_decode(file_get_contents('php://input'), true);

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

        $faculty = $this->facultyModel->findById($data['FacultyID']);
        if (!$faculty) {
            Response::notFound('Faculty not found');
        }
        if ((int) $faculty['DepartmentID'] !== $departmentId) {
            Response::forbidden('Cannot assign schedule to faculty from other departments');
        }

        $subject = $this->subjectModel->findById((int) $data['SubjectID']);
        if (!$subject) {
            Response::notFound('Subject not found');
        }
        if ((int) $subject['DepartmentID'] !== $departmentId) {
            Response::forbidden('Cannot use a subject from another department');
        }

        if (!$this->roomModel->exists((int) $data['RoomID'])) {
            Response::notFound('Room not found');
        }

        if ($data['StartTime'] >= $data['EndTime']) {
            Response::error('End time must be after start time', 400);
        }

        $conflicts = $this->scheduleModel->checkConflicts(
            $data['FacultyID'],
            (int) $data['RoomID'],
            $data['DayOfWeek'],
            $data['StartTime'],
            $data['EndTime'],
            $id
        );

        if (!empty($conflicts)) {
            Response::error('Schedule conflicts detected', 409, $conflicts);
        }

        $this->scheduleModel->update($id, [
            'FacultyID' => $data['FacultyID'],
            'SubjectID' => (int) $data['SubjectID'],
            'RoomID' => (int) $data['RoomID'],
            'DayOfWeek' => $data['DayOfWeek'],
            'StartTime' => $data['StartTime'],
            'EndTime' => $data['EndTime']
        ]);

        $updated = $this->scheduleModel->findByIdWithDetails($id);
        Response::success($updated, 'Schedule updated successfully');
    }
}
