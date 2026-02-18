<?php
/**
 * Schedule Controller
 * CRUD operations for schedules with conflict checking
 */

class ScheduleController {
    private $scheduleModel;
    private $facultyModel;
    private $subjectModel;
    private $roomModel;

    public function __construct() {
        $this->scheduleModel = new ScheduleModel();
        $this->facultyModel = new FacultyModel();
        $this->subjectModel = new SubjectModel();
        $this->roomModel = new RoomModel();
    }

    /**
     * GET /api/schedules
     */
    public function index(): void {
        Auth::requireAuth();
        
        $user = Auth::getCurrentUser();
        $facultyId = $_GET['facultyId'] ?? null;

        // Faculty can only see their own schedules
        if ($user['Role'] === 'Faculty') {
            $schedules = $this->scheduleModel->findByFaculty($user['FacultyID']);
        } elseif ($user['Role'] === 'DepartmentHead' && !empty($user['DepartmentID'])) {
            if ($facultyId) {
                $faculty = $this->facultyModel->findById((string) $facultyId);
                if (!$faculty || (int) $faculty['DepartmentID'] !== (int) $user['DepartmentID']) {
                    Response::forbidden('Faculty does not belong to your department');
                }
            }

            $schedules = $this->scheduleModel->findByDepartment((int) $user['DepartmentID'], $facultyId ? (string) $facultyId : null);
        } elseif ($facultyId) {
            $schedules = $this->scheduleModel->findByFaculty((string) $facultyId);
        } else {
            $schedules = $this->scheduleModel->findAllWithDetails();
        }

        Response::success($schedules);
    }

    /**
     * GET /api/schedules/{id}
     */
    public function show(int $id): void {
        Auth::requireAuth();
        
        $schedule = $this->scheduleModel->findByIdWithDetails($id);
        if (!$schedule) {
            Response::notFound('Schedule not found');
        }

        Response::success($schedule);
    }

    /**
     * GET /api/schedules/today
     * Get today's schedules for current faculty
     */
    public function today(): void {
        $user = Auth::requireAuth();
        
        if (!$user['FacultyID']) {
            Response::error('No faculty profile associated with this account', 400);
        }

        $dayOfWeek = date('l'); // Monday, Tuesday, etc.
        $schedules = $this->scheduleModel->findByFacultyAndDay($user['FacultyID'], $dayOfWeek);

        Response::success([
            'date' => date('Y-m-d'),
            'dayOfWeek' => $dayOfWeek,
            'schedules' => $schedules
        ]);
    }

    /**
     * POST /api/schedules
     */
    public function store(): void {
        $user = Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        
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

        // Verify foreign keys exist
        if (!$this->facultyModel->exists($data['FacultyID'])) {
            Response::error('Faculty not found', 404);
        }
        if (!$this->subjectModel->exists($data['SubjectID'])) {
            Response::error('Subject not found', 404);
        }
        if (!$this->roomModel->exists($data['RoomID'])) {
            Response::error('Room not found', 404);
        }

        if ($user['Role'] === 'DepartmentHead') {
            if (empty($user['DepartmentID'])) {
                Response::error('DepartmentHead account is not linked to any department', 400);
            }

            $departmentId = (int) $user['DepartmentID'];

            $faculty = $this->facultyModel->findById((string) $data['FacultyID']);
            if (!$faculty || (int) $faculty['DepartmentID'] !== $departmentId) {
                Response::forbidden('Faculty does not belong to your department');
            }

            $subject = $this->subjectModel->findById((int) $data['SubjectID']);
            if (!$subject || (int) $subject['DepartmentID'] !== $departmentId) {
                Response::forbidden('Subject does not belong to your department');
            }
        }

        // Validate time range
        if ($data['StartTime'] >= $data['EndTime']) {
            Response::error('End time must be after start time', 400);
        }

        // Check for conflicts
        $conflicts = $this->scheduleModel->checkConflicts(
            $data['FacultyID'],
            $data['RoomID'],
            $data['DayOfWeek'],
            $data['StartTime'],
            $data['EndTime']
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

    /**
     * PUT /api/schedules/{id}
     */
    public function update(int $id): void {
        $user = Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        
        $schedule = $this->scheduleModel->findById($id);
        if (!$schedule) {
            Response::notFound('Schedule not found');
        }

        if ($user['Role'] === 'DepartmentHead') {
            if (empty($user['DepartmentID'])) {
                Response::error('DepartmentHead account is not linked to any department', 400);
            }

            $departmentId = (int) $user['DepartmentID'];
            $existingFaculty = $this->facultyModel->findById((string) $schedule['FacultyID']);
            if (!$existingFaculty || (int) $existingFaculty['DepartmentID'] !== $departmentId) {
                Response::forbidden('Cannot modify schedules from other departments');
            }
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

        // Verify foreign keys exist
        if (!$this->facultyModel->exists($data['FacultyID'])) {
            Response::error('Faculty not found', 404);
        }
        if (!$this->subjectModel->exists($data['SubjectID'])) {
            Response::error('Subject not found', 404);
        }
        if (!$this->roomModel->exists($data['RoomID'])) {
            Response::error('Room not found', 404);
        }

        if ($user['Role'] === 'DepartmentHead') {
            $departmentId = (int) $user['DepartmentID'];

            $faculty = $this->facultyModel->findById((string) $data['FacultyID']);
            if (!$faculty || (int) $faculty['DepartmentID'] !== $departmentId) {
                Response::forbidden('Faculty does not belong to your department');
            }

            $subject = $this->subjectModel->findById((int) $data['SubjectID']);
            if (!$subject || (int) $subject['DepartmentID'] !== $departmentId) {
                Response::forbidden('Subject does not belong to your department');
            }
        }

        // Validate time range
        if ($data['StartTime'] >= $data['EndTime']) {
            Response::error('End time must be after start time', 400);
        }

        // Check for conflicts (excluding current schedule)
        $conflicts = $this->scheduleModel->checkConflicts(
            $data['FacultyID'],
            $data['RoomID'],
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
            'SubjectID' => $data['SubjectID'],
            'RoomID' => $data['RoomID'],
            'DayOfWeek' => $data['DayOfWeek'],
            'StartTime' => $data['StartTime'],
            'EndTime' => $data['EndTime']
        ]);

        $updatedSchedule = $this->scheduleModel->findByIdWithDetails($id);
        Response::success($updatedSchedule, 'Schedule updated successfully');
    }

    /**
     * DELETE /api/schedules/{id}
     */
    public function destroy(int $id): void {
        $user = Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        
        $schedule = $this->scheduleModel->findById($id);
        if (!$schedule) {
            Response::notFound('Schedule not found');
        }

        if ($user['Role'] === 'DepartmentHead') {
            if (empty($user['DepartmentID'])) {
                Response::error('DepartmentHead account is not linked to any department', 400);
            }

            $departmentId = (int) $user['DepartmentID'];
            $existingFaculty = $this->facultyModel->findById((string) $schedule['FacultyID']);
            if (!$existingFaculty || (int) $existingFaculty['DepartmentID'] !== $departmentId) {
                Response::forbidden('Cannot delete schedules from other departments');
            }
        }

        $this->scheduleModel->delete($id);
        Response::success(null, 'Schedule deleted successfully');
    }
}
