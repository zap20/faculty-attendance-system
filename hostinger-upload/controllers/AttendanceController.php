<?php
/**
 * Attendance Controller
 * Handles attendance time in/out with real-time verification
 */

class AttendanceController {
    private $attendanceModel;
    private $scheduleModel;
    private $deviceModel;
    private $facultyModel;

    public function __construct() {
        $this->attendanceModel = new AttendanceModel();
        $this->scheduleModel = new ScheduleModel();
        $this->deviceModel = new DeviceModel();
        $this->facultyModel = new FacultyModel();
    }

    /**
     * GET /api/attendance
     * Get attendance records with filters
     */
    public function index(): void {
        $user = Auth::requireAuth();
        
        $filters = [
            'from' => $_GET['from'] ?? null,
            'to' => $_GET['to'] ?? null,
            'departmentId' => $_GET['departmentId'] ?? null,
            'status' => $_GET['status'] ?? null
        ];

        // Faculty can only see their own attendance
        if ($user['Role'] === 'Faculty') {
            $filters['facultyId'] = $user['FacultyID'];
        } elseif ($user['Role'] === 'DepartmentHead' && $user['DepartmentID']) {
            // DepartmentHead can only see their department
            $filters['departmentId'] = $user['DepartmentID'];
        } elseif (!empty($_GET['facultyId'])) {
            $filters['facultyId'] = $_GET['facultyId'];
        }

        $attendances = $this->attendanceModel->findAllWithDetails($filters);
        Response::success($attendances);
    }

    /**
     * GET /api/attendance/today
     * Get today's attendance for current faculty
     */
    public function today(): void {
        $user = Auth::requireAuth();
        
        if (!$user['FacultyID']) {
            Response::error('No faculty profile associated with this account', 400);
        }

        $today = date('Y-m-d');
        $attendances = $this->attendanceModel->findByFacultyAndDate($user['FacultyID'], $today);

        Response::success([
            'date' => $today,
            'attendances' => $attendances
        ]);
    }

    /**
     * POST /api/attendance/timein
     * Record time in with real-time verification
     * 
     * Verification Logic:
     * 1. Validate token and get FacultyID
     * 2. Get current day and time
     * 3. Find matching schedule (FacultyID + DayOfWeek + time within range)
     * 4. If no schedule: status = "No Schedule"
     * 5. If schedule exists:
     *    - Check device is Active
     *    - Check device RoomID matches schedule RoomID
     *    - If mismatch: status = "Wrong Room"
     *    - If time > StartTime + grace period: status = "Late"
     *    - Else: status = "Present"
     */
    public function timeIn(): void {
        $user = Auth::requireAuth();
        
        if (!$user['FacultyID']) {
            Response::error('No faculty profile associated with this account', 400);
        }

        $data = json_decode(file_get_contents('php://input'), true);
        
        $validator = new Validator($data ?? []);
        $validator->required('deviceId', 'Device ID')
                  ->integer('deviceId', 'Device ID')
                  ->validate();

        $deviceId = (int) $data['deviceId'];
        $facultyId = $user['FacultyID'];
        $today = date('Y-m-d');
        $currentTime = date('H:i:s');
        
        // Calculate day of week based on current date (same as QR scanner fix)
        $dateTime = new DateTime($today);
        $dayOfWeek = $dateTime->format('l'); // Monday, Tuesday, etc.

        // Check if already has open attendance (not timed out)
        $openAttendance = $this->attendanceModel->findOpenAttendance($facultyId, $today);
        if ($openAttendance) {
            Response::error('You already have an open attendance record. Please time out first.', 400);
        }

        // Get device info
        $device = $this->deviceModel->findByIdWithRoom($deviceId);
        if (!$device) {
            Response::error('Device not found', 404);
        }

        // Check device status
        if ($device['Status'] !== 'Active') {
            Response::error('Device is inactive', 400);
        }

        // Find matching schedule for current time
        $schedule = $this->scheduleModel->findCurrentSchedule($facultyId, $dayOfWeek, $currentTime);

        $status = '';
        $remarks = '';
        $scheduleId = null;

        if (!$schedule) {
            // No matching schedule found - do not insert attendance, just return warning
            Response::success([
                'action' => 'no_schedule',
                'inserted' => false,
                'message' => 'You don\'t have a schedule for this time or today'
            ], 'No schedule');
            return;
        }

        $scheduleId = $schedule['ScheduleID'];
        
        // Check if already recorded attendance for this schedule
        if ($this->attendanceModel->hasAttendanceForSchedule($facultyId, $scheduleId, $today)) {
            Response::error('Attendance already recorded for this schedule', 400);
        }

        // Check if device room matches schedule room
        if ($device['RoomID'] != $schedule['RoomID']) {
            $status = 'Wrong Room';
            $remarks = 'Expected: ' . $schedule['RoomName'] . ' (' . $schedule['Building'] . '), ' .
                      'Actual: ' . ($device['RoomName'] ?? $device['Location']);
        } else {
            // Check if late (current time > StartTime + grace period)
            $startTime = strtotime($schedule['StartTime']);
            $graceTime = $startTime + (GRACE_PERIOD_MINUTES * 60);
            $now = strtotime($currentTime);

            if ($now > $graceTime) {
                $status = 'Late';
                $lateMinutes = round(($now - $startTime) / 60);
                $remarks = 'Arrived ' . $lateMinutes . ' minutes after scheduled start time';
            } else {
                $status = 'Present';
                $remarks = 'On time for ' . $schedule['SubjectName'] . ' (' . $schedule['CourseCode'] . ')';
            }
        }

        // Create attendance record
        $attendanceId = $this->attendanceModel->create([
            'FacultyID' => $facultyId,
            'DeviceID' => $deviceId,
            'ScheduleID' => $scheduleId,
            'Date' => $today,
            'DayOfWeek' => $dayOfWeek, // Add DayOfWeek field
            'TimeIn' => $currentTime,
            'TimeOut' => null,
            'AttendanceStatus' => $status,
            'Remarks' => $remarks
        ]);

        $attendance = $this->attendanceModel->findById($attendanceId);

        Response::success([
            'attendance' => $attendance,
            'schedule' => $schedule,
            'device' => $device
        ], 'Time in recorded successfully');
    }

    /**
     * POST /api/attendance/timeout
     * Record time out
     */
    public function timeOut(): void {
        $user = Auth::requireAuth();
        
        if (!$user['FacultyID']) {
            Response::error('No faculty profile associated with this account', 400);
        }

        $data = json_decode(file_get_contents('php://input'), true);
        
        $validator = new Validator($data ?? []);
        $validator->required('deviceId', 'Device ID')
                  ->integer('deviceId', 'Device ID')
                  ->validate();

        $deviceId = (int) $data['deviceId'];
        $facultyId = $user['FacultyID'];
        $today = date('Y-m-d');
        $currentTime = date('H:i:s');

        // Get device info
        $device = $this->deviceModel->findByIdWithRoom($deviceId);
        if (!$device) {
            Response::error('Device not found', 404);
        }

        // Check device status
        if ($device['Status'] !== 'Active') {
            Response::error('Device is inactive', 400);
        }

        // Find open attendance record
        $openAttendance = $this->attendanceModel->findOpenAttendance($facultyId, $today);
        if (!$openAttendance) {
            Response::error('No open attendance record found. Please time in first.', 400);
        }

        // Update with time out
        $this->attendanceModel->update($openAttendance['AttendanceID'], [
            'TimeOut' => $currentTime
        ]);

        $attendance = $this->attendanceModel->findById($openAttendance['AttendanceID']);

        Response::success([
            'attendance' => $attendance,
            'device' => $device
        ], 'Time out recorded successfully');
    }

    /**
     * GET /api/attendance/history
     * Get attendance history for current faculty
     */
    public function history(): void {
        $user = Auth::requireAuth();
        
        if (!$user['FacultyID']) {
            Response::error('No faculty profile associated with this account', 400);
        }

        $from = $_GET['from'] ?? date('Y-m-01'); // Default to first of month
        $to = $_GET['to'] ?? date('Y-m-d');

        $attendances = $this->attendanceModel->findAllWithDetails([
            'facultyId' => $user['FacultyID'],
            'from' => $from,
            'to' => $to
        ]);

        Response::success([
            'from' => $from,
            'to' => $to,
            'attendances' => $attendances
        ]);
    }

    public function autoAbsent(): void {
        $user = Auth::requireAuth();

        if (!in_array($user['Role'], ['Admin', 'AttendanceOfficer'])) {
            Response::error('Unauthorized', 403);
        }

        $data = json_decode(file_get_contents('php://input'), true) ?? [];

        $date = $data['date'] ?? date('Y-m-d');
        $today = date('Y-m-d');

        if ($date > $today) {
            Response::error('Date cannot be in the future', 400);
        }

        try {
            $dayOfWeek = (new DateTime($date))->format('l');
        } catch (Exception $e) {
            Response::error('Invalid date format', 400);
        }

        $isToday = ($date === $today);
        $cutoffTime = date('H:i:s');
        if (!empty($data['cutoff_time'])) {
            try {
                $cutoffTime = (new DateTime($data['cutoff_time']))->format('H:i:s');
            } catch (Exception $e) {
                Response::error('Invalid cutoff_time format', 400);
            }
        }

        $db = Database::getInstance()->getConnection();

        $sql = "
            INSERT INTO attendances (FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, TimeIn, TimeOut, AttendanceStatus, Remarks)
            SELECT 
                s.FacultyID,
                NULL,
                s.ScheduleID,
                ?,
                ?,
                NULL,
                NULL,
                'Absent',
                'Auto-marked absent'
            FROM schedules s
            WHERE s.DayOfWeek = ?
        ";

        $params = [$date, $dayOfWeek, $dayOfWeek];

        if ($isToday) {
            $sql .= " AND s.EndTime < ? ";
            $params[] = $cutoffTime;
        }

        $sql .= "
            AND NOT EXISTS (
                SELECT 1
                FROM ATTENDANCES a
                WHERE a.FacultyID = s.FacultyID
                  AND a.ScheduleID = s.ScheduleID
                  AND a.Date = ?
                LIMIT 1
            )
        ";
        $params[] = $date;

        $stmt = $db->prepare($sql);
        $stmt->execute($params);

        Response::success([
            'date' => $date,
            'day_of_week' => $dayOfWeek,
            'cutoff_time' => $isToday ? $cutoffTime : null,
            'inserted' => $stmt->rowCount(),
        ]);
    }

    /**
     * PUT /api/attendance/update-status
     * Officer can update attendance status (Absent, Early Out, etc.)
     */
    public function updateStatus(): void {
        $user = Auth::requireAuth();
        if (!in_array($user['Role'], ['Admin', 'AttendanceOfficer'])) {
            Response::error('Unauthorized', 403);
        }

        $data = json_decode(file_get_contents('php://input'), true) ?? [];

        $scheduleId = $data['scheduleId'] ?? null;
        $facultyId = $data['facultyId'] ?? null;
        $date = $data['date'] ?? null;
        $action = $data['action'] ?? null; // 'absent' | 'early_out' | 'update_status'
        $remarks = $data['remarks'] ?? null;
        $newStatus = $data['status'] ?? null;

        if (!$facultyId || !$date || !$action) {
            Response::error('facultyId, date, and action are required', 400);
        }

        $db = Database::getInstance()->getConnection();

        if ($action === 'absent') {
            // Mark as absent: create a new attendance record with no TimeIn/TimeOut
            if (!$scheduleId) {
                Response::error('scheduleId is required to mark absent', 400);
            }

            // Check if attendance already exists for this schedule+date
            if ($this->attendanceModel->hasAttendanceForSchedule($facultyId, $scheduleId, $date)) {
                // Update existing record to Absent
                $stmt = $db->prepare("UPDATE attendances SET AttendanceStatus = 'Absent', TimeIn = NULL, TimeOut = NULL, Remarks = ? WHERE FacultyID = ? AND ScheduleID = ? AND Date = ?");
                $stmt->execute([$remarks ?? 'Marked absent by officer', $facultyId, $scheduleId, $date]);
            } else {
                // Insert new absent record
                $dayOfWeek = (new \DateTime($date))->format('l');
                $this->attendanceModel->create([
                    'FacultyID' => $facultyId,
                    'DeviceID' => null,
                    'ScheduleID' => $scheduleId,
                    'Date' => $date,
                    'DayOfWeek' => $dayOfWeek,
                    'TimeIn' => null,
                    'TimeOut' => null,
                    'AttendanceStatus' => 'Absent',
                    'Remarks' => $remarks ?? 'Marked absent by officer',
                ]);
            }

            Response::success(['action' => 'absent', 'facultyId' => $facultyId, 'scheduleId' => $scheduleId, 'date' => $date], 'Marked as absent');

        } elseif ($action === 'early_out') {
            // Set early out: update TimeOut to current time or provided time
            $timeOut = $data['timeOut'] ?? date('H:i:s');

            $stmt = $db->prepare("UPDATE attendances SET TimeOut = ?, Remarks = CONCAT(IFNULL(Remarks,''), ' | Early out by officer') WHERE FacultyID = ? AND Date = ? AND ScheduleID = ? AND TimeIn IS NOT NULL");
            $params = [$timeOut, $facultyId, $date, $scheduleId];

            if (!$scheduleId) {
                // If no scheduleId, update the latest open attendance for that date
                $stmt = $db->prepare("UPDATE attendances SET TimeOut = ?, Remarks = CONCAT(IFNULL(Remarks,''), ' | Early out by officer') WHERE FacultyID = ? AND Date = ? AND TimeIn IS NOT NULL AND TimeOut IS NULL ORDER BY TimeIn DESC LIMIT 1");
                $params = [$timeOut, $facultyId, $date];
            }

            $stmt->execute($params);

            if ($stmt->rowCount() === 0) {
                Response::error('No open attendance record found to set early out', 404);
            }

            Response::success(['action' => 'early_out', 'facultyId' => $facultyId, 'date' => $date, 'timeOut' => $timeOut], 'Early out recorded');

        } elseif ($action === 'update_status') {
            if (!$newStatus) {
                Response::error('status is required for update_status action', 400);
            }

            $sql = "UPDATE attendances SET AttendanceStatus = ?";
            $params = [$newStatus];
            if ($remarks !== null) {
                $sql .= ", Remarks = ?";
                $params[] = $remarks;
            }
            $sql .= " WHERE FacultyID = ? AND Date = ?";
            $params[] = $facultyId;
            $params[] = $date;
            if ($scheduleId) {
                $sql .= " AND ScheduleID = ?";
                $params[] = $scheduleId;
            }

            $stmt = $db->prepare($sql);
            $stmt->execute($params);

            Response::success(['action' => 'update_status', 'status' => $newStatus], 'Status updated');
        } else {
            Response::error('Invalid action. Use: absent, early_out, update_status', 400);
        }
    }

    /**
     * POST /api/attendance/qr
     * Record attendance by QR code (for Attendance Officers)
     * QR code contains faculty ID or a unique identifier
     */
    public function recordByQR(): void {
        $user = Auth::requireAuth();
        
        // Only Admin and AttendanceOfficer can use this endpoint
        if (!in_array($user['Role'], ['Admin', 'AttendanceOfficer'])) {
            Response::error('Unauthorized. Only Attendance Officers can use QR scanning.', 403);
        }

        $data = json_decode(file_get_contents('php://input'), true);
        
        $validator = new Validator($data ?? []);
        $validator->required('qr_code', 'QR Code')
                  ->validate();

        $qrCode = trim($data['qr_code']);
        
        // Use date from frontend request, not server date
        $today = !empty($data['scan_date']) ? $data['scan_date'] : date('Y-m-d');
        $currentTime = date('H:i:s');
        if (!empty($data['scan_time'])) {
            try {
                $currentTime = (new DateTime($data['scan_time']))->format('H:i:s');
            } catch (Exception $e) {
                $currentTime = date('H:i:s');
            }
        }
        
        // Get day of week from scan date (authoritative)
        $scanDate = !empty($data['scan_date']) ? $data['scan_date'] : $today;
        $dateTime = new DateTime($scanDate);
        $dayOfWeek = $dateTime->format('l');

        // SAFETY CHECK: Ensure DayOfWeek is never empty
        if (empty($dayOfWeek)) {
            $dayOfWeek = 'Monday';
        }

        // QR code can be faculty ID or faculty employee number
        $faculty = null;
        $faculty = $this->facultyModel->findById($qrCode);
        if (!$faculty) {
            // Try to find by employee number or email
            $faculty = $this->facultyModel->findByEmployeeNumber($qrCode);
        }

        if (!$faculty) {
            Response::error('Faculty not found for QR code: ' . $qrCode, 404);
        }

        $facultyId = $faculty['FacultyID'];

        // Check if already has open attendance
        $openAttendance = $this->attendanceModel->findOpenAttendance($facultyId, $today);
        
        if ($openAttendance) {
            // If open attendance exists, record time out
            $this->attendanceModel->update($openAttendance['AttendanceID'], [
                'TimeOut' => $currentTime
            ]);

            $attendance = $this->attendanceModel->findById($openAttendance['AttendanceID']);

            Response::success([
                'action' => 'timeout',
                'inserted' => true,
                'attendance' => $attendance,
                'faculty_name' => $faculty['FacultyName'],
                'time_out' => $currentTime,
                'day_of_week' => $dayOfWeek,
                'message' => 'Time out recorded for ' . $faculty['FacultyName']
            ], 'Time out recorded successfully');
            return;
        }

        // No open attendance, record time in
        $schedule = $this->scheduleModel->findCurrentSchedule($facultyId, $dayOfWeek, $currentTime);

        if (!$schedule) {
            Response::success([
                'action' => 'no_schedule',
                'inserted' => false,
                'attendance' => null,
                'faculty_name' => $faculty['FacultyName'],
                'day_of_week' => $dayOfWeek,
                'scan_time' => $currentTime,
                'message' => 'No schedule for ' . $dayOfWeek . ' at ' . $currentTime
            ], 'No schedule found');
            return;
        }

        $status = 'Present';
        $remarks = 'Recorded via QR scan by ' . $user['Username'];
        $scheduleId = $schedule['ScheduleID'];

        // Check if already has attendance for this schedule
        if ($this->attendanceModel->hasAttendanceForSchedule($facultyId, $scheduleId, $today)) {
            Response::error('Attendance already recorded for this schedule today', 400);
        }

        // Check if late
        $startTime = strtotime($schedule['StartTime']);
        $graceTime = $startTime + (GRACE_PERIOD_MINUTES * 60);
        $now = strtotime($currentTime);

        if ($now > $graceTime) {
            $status = 'Late';
            $lateMinutes = round(($now - $startTime) / 60);
            $remarks = 'Arrived ' . $lateMinutes . ' minutes late. ' . $remarks;
        } else {
            $remarks = 'On time for ' . ($schedule['SubjectName'] ?? 'class') . '. ' . $remarks;
        }

        // Create attendance record with DayOfWeek - CLEAN SQL
        try {
            $db = Database::getInstance()->getConnection();
            
            $sql = "INSERT INTO ATTENDANCES (FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, TimeIn, TimeOut, AttendanceStatus, Remarks) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
            $sql = "INSERT INTO attendances (FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, TimeIn, TimeOut, AttendanceStatus, Remarks) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
            
            $stmt = $db->prepare($sql);
            $stmt->execute([
                $facultyId,
                null,
                $scheduleId,
                $today,
                $dayOfWeek, // Now correctly calculated and stored
                $currentTime,
                null,
                $status,
                $remarks
            ]);
            
            $attendanceId = (int) $db->lastInsertId();
            $attendance = $this->attendanceModel->findById($attendanceId);
            
        } catch (Exception $e) {
            error_log("SQL insertion failed: " . $e->getMessage());
            // Fallback to BaseModel if raw SQL fails
            $attendanceData = [
                'FacultyID' => $facultyId,
                'DeviceID' => null,
                'ScheduleID' => $scheduleId,
                'Date' => $today,
                'DayOfWeek' => $dayOfWeek,
                'TimeIn' => $currentTime,
                'TimeOut' => null,
                'AttendanceStatus' => $status,
                'Remarks' => $remarks
            ];
            
            $attendanceId = $this->attendanceModel->create($attendanceData);
            $attendance = $this->attendanceModel->findById($attendanceId);
        }

        Response::success([
            'action' => 'timein',
            'inserted' => true,
            'attendance' => $attendance,
            'faculty_name' => $faculty['FacultyName'],
            'time_in' => $currentTime,
            'day_of_week' => $dayOfWeek, // Use the correctly calculated day
            'status' => $status,
            'schedule' => $schedule,
            'message' => 'Time in recorded for ' . $faculty['FacultyName']
        ], 'Time in recorded successfully');
    }
}
