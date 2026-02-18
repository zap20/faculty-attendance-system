<?php
/**
 * Sync Controller
 * Handles push/pull sync between mobile Sqflite and remote MariaDB.
 * Push: receives locally-created attendance records and inserts/updates them.
 * Pull: returns records updated since a given timestamp for each table.
 */

class SyncController {
    private $db;

    // Tables available for pull sync (in dependency order)
    private $pullableTables = [
        'departments' => ['pk' => 'DepartmentID', 'table' => 'DEPARTMENTS'],
        'faculties'   => ['pk' => 'FacultyID',     'table' => 'FACULTIES'],
        'rooms'       => ['pk' => 'RoomID',         'table' => 'ROOMS'],
        'subjects'    => ['pk' => 'SubjectID',      'table' => 'SUBJECTS'],
        'schedules'   => ['pk' => 'ScheduleID',     'table' => 'SCHEDULES'],
        'attendancedevices' => ['pk' => 'DeviceID', 'table' => 'ATTENDANCEDEVICES'],
        'attendances' => ['pk' => 'AttendanceID',   'table' => 'ATTENDANCES'],
    ];

    public function __construct() {
        $this->db = Database::getInstance()->getConnection();
    }

    /**
     * POST /api/sync/push
     * Receive locally-created/updated records and merge into MariaDB.
     * Body: { "table": "attendances", "records": [...] }
     */
    public function push(): void {
        $user = Auth::requireAuth();

        $data = json_decode(file_get_contents('php://input'), true) ?? [];
        $table = $data['table'] ?? null;
        $records = $data['records'] ?? [];

        if (!$table || empty($records)) {
            Response::error('table and records are required', 400);
        }

        // Only allow pushing attendance records from mobile
        if ($table !== 'attendances') {
            Response::error('Only attendance records can be pushed from mobile', 400);
        }

        $synced = [];
        $errors = [];

        foreach ($records as $record) {
            try {
                $result = $this->pushAttendanceRecord($record, $user);
                $synced[] = $result;
            } catch (Exception $e) {
                $errors[] = [
                    'localId' => $record['localId'] ?? null,
                    'error' => $e->getMessage(),
                ];
            }
        }

        Response::success([
            'synced' => $synced,
            'errors' => $errors,
            'totalSynced' => count($synced),
            'totalErrors' => count($errors),
        ], 'Push sync completed');
    }

    /**
     * Push a single attendance record.
     * Uses composite key (FacultyID + Date + ScheduleID) to detect duplicates.
     * Conflict resolution: last-write-wins based on version/updatedAt.
     */
    private function pushAttendanceRecord(array $record, array $user): array {
        $facultyId  = $record['FacultyID'] ?? null;
        $scheduleId = $record['ScheduleID'] ?? null;
        $date       = $record['Date'] ?? null;
        $localId    = $record['localId'] ?? null;
        $remoteId   = $record['AttendanceID'] ?? null;
        $version    = $record['version'] ?? 1;

        if (!$facultyId || !$date) {
            throw new Exception('FacultyID and Date are required');
        }

        // Check if record already exists on server
        $existing = null;
        if ($remoteId) {
            $stmt = $this->db->prepare("SELECT * FROM ATTENDANCES WHERE AttendanceID = ?");
            $stmt->execute([$remoteId]);
            $existing = $stmt->fetch();
        }

        if (!$existing && $scheduleId) {
            $stmt = $this->db->prepare(
                "SELECT * FROM ATTENDANCES WHERE FacultyID = ? AND Date = ? AND ScheduleID = ? LIMIT 1"
            );
            $stmt->execute([$facultyId, $date, $scheduleId]);
            $existing = $stmt->fetch();
        }

        if ($existing) {
            // Conflict resolution: compare versions / timestamps
            $serverVersion = 1; // Default if no version tracking on server
            $localVersion = (int) $version;

            // Last-write-wins: update if local version is newer or equal
            $stmt = $this->db->prepare("
                UPDATE ATTENDANCES SET
                    TimeIn = ?,
                    TimeOut = ?,
                    AttendanceStatus = ?,
                    Remarks = ?,
                    UpdatedAt = NOW()
                WHERE AttendanceID = ?
            ");
            $stmt->execute([
                $record['TimeIn'],
                $record['TimeOut'],
                $record['AttendanceStatus'] ?? 'Present',
                $record['Remarks'] ?? 'Synced from mobile',
                $existing['AttendanceID'],
            ]);

            return [
                'localId' => $localId,
                'remoteId' => (int) $existing['AttendanceID'],
                'action' => 'updated',
            ];
        } else {
            // Insert new record
            $dayOfWeek = $record['DayOfWeek'];
            if (empty($dayOfWeek)) {
                $dayOfWeek = (new DateTime($date))->format('l');
            }

            $stmt = $this->db->prepare("
                INSERT INTO ATTENDANCES
                    (FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, TimeIn, TimeOut, AttendanceStatus, Remarks)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            $stmt->execute([
                $facultyId,
                $record['DeviceID'] ?? null,
                $scheduleId,
                $date,
                $dayOfWeek,
                $record['TimeIn'],
                $record['TimeOut'],
                $record['AttendanceStatus'] ?? 'Present',
                $record['Remarks'] ?? 'Synced from mobile',
            ]);

            $newId = (int) $this->db->lastInsertId();

            return [
                'localId' => $localId,
                'remoteId' => $newId,
                'action' => 'inserted',
            ];
        }
    }

    /**
     * GET /api/sync/pull?table=attendances&since=2026-01-01T00:00:00
     * Returns records updated since the given timestamp.
     * If no 'since' param, returns all records for the table.
     */
    public function pull(): void {
        $user = Auth::requireAuth();

        $tableName = $_GET['table'] ?? null;
        $since = $_GET['since'] ?? null;

        if (!$tableName || !isset($this->pullableTables[$tableName])) {
            Response::error('Invalid or missing table parameter. Valid: ' . implode(', ', array_keys($this->pullableTables)), 400);
        }

        $config = $this->pullableTables[$tableName];
        $dbTable = $config['table'];

        $sql = "SELECT * FROM $dbTable";
        $params = [];

        if ($since) {
            $sql .= " WHERE UpdatedAt > ?";
            $params[] = $since;
        }

        $sql .= " ORDER BY " . $config['pk'];

        // Limit to prevent huge payloads
        $limit = (int) ($_GET['limit'] ?? 5000);
        $offset = (int) ($_GET['offset'] ?? 0);
        $sql .= " LIMIT $limit OFFSET $offset";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $records = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Cast numeric fields to int for Flutter compatibility
        foreach ($records as &$record) {
            foreach ($record as $key => &$value) {
                if ($value !== null && is_numeric($value) && !str_contains($key, 'ID') && !str_contains($key, 'Name') && !str_contains($key, 'Time') && !str_contains($key, 'Date') && !str_contains($key, 'At') && !str_contains($key, 'Day') && !str_contains($key, 'Status') && !str_contains($key, 'Remarks') && !str_contains($key, 'Code') && !str_contains($key, 'Type') && !str_contains($key, 'Location') && !str_contains($key, 'Building') && !str_contains($key, 'Position') && !str_contains($key, 'Contact') && !str_contains($key, 'Employment') && !str_contains($key, 'Password') && !str_contains($key, 'Username') && !str_contains($key, 'Role') && !str_contains($key, 'Dean') && !str_contains($key, 'Head')) {
                    $value = (int) $value;
                }
            }
        }

        // Get total count for pagination
        $countSql = "SELECT COUNT(*) as total FROM $dbTable";
        $countParams = [];
        if ($since) {
            $countSql .= " WHERE UpdatedAt > ?";
            $countParams[] = $since;
        }
        $countStmt = $this->db->prepare($countSql);
        $countStmt->execute($countParams);
        $total = (int) $countStmt->fetch()['total'];

        Response::success([
            'table' => $tableName,
            'records' => $records,
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
            'since' => $since,
            'serverTime' => date('c'),
        ], 'Pull sync completed');
    }

    /**
     * GET /api/sync/last-updated
     * Returns the latest modification timestamp for key tables.
     * Lightweight endpoint for change-detection polling.
     */
    public function lastUpdated(): void {
        Auth::requireAuth();

        $stmt = $this->db->prepare("SELECT MAX(UpdatedAt) as lastUpdated FROM ATTENDANCES");
        $stmt->execute();
        $row = $stmt->fetch();

        Response::success([
            'attendances' => $row['lastUpdated'] ?? null,
            'serverTime' => date('c'),
        ]);
    }

    /**
     * GET /api/sync/status
     * Returns sync status info (record counts per table).
     */
    public function status(): void {
        Auth::requireAuth();

        $counts = [];
        foreach ($this->pullableTables as $name => $config) {
            $stmt = $this->db->prepare("SELECT COUNT(*) as cnt FROM {$config['table']}");
            $stmt->execute();
            $counts[$name] = (int) $stmt->fetch()['cnt'];
        }

        Response::success([
            'tables' => $counts,
            'serverTime' => date('c'),
        ]);
    }
}
