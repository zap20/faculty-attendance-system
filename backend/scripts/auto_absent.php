<?php

if (php_sapi_name() !== 'cli') {
    fwrite(STDERR, "This script must be run from CLI.\n");
    exit(1);
}

date_default_timezone_set('Asia/Manila');

require_once __DIR__ . '/../config/database.php';

$opts = getopt('', ['date::', 'cutoff::', 'dry-run', 'json']);

$date = $opts['date'] ?? date('Y-m-d');
$cutoff = $opts['cutoff'] ?? date('H:i:s');
$dryRun = array_key_exists('dry-run', $opts);
$asJson = array_key_exists('json', $opts);

$today = date('Y-m-d');
if ($date > $today) {
    fwrite(STDERR, "Date cannot be in the future.\n");
    exit(1);
}

try {
    $dayOfWeek = (new DateTime($date))->format('l');
} catch (Exception $e) {
    fwrite(STDERR, "Invalid date format. Use YYYY-MM-DD.\n");
    exit(1);
}

try {
    $cutoffTime = (new DateTime($cutoff))->format('H:i:s');
} catch (Exception $e) {
    fwrite(STDERR, "Invalid cutoff time format. Use HH:MM or HH:MM:SS.\n");
    exit(1);
}

$isToday = ($date === $today);

try {
    $db = Database::getInstance()->getConnection();
} catch (Exception $e) {
    fwrite(STDERR, $e->getMessage() . "\n");
    exit(1);
}

$baseWhereSql = " WHERE s.DayOfWeek = ? ";
$params = [$dayOfWeek];

if ($isToday) {
    $baseWhereSql .= " AND s.EndTime < ? ";
    $params[] = $cutoffTime;
}

$baseWhereSql .= " AND NOT EXISTS (\n";
$baseWhereSql .= "     SELECT 1 FROM ATTENDANCES a\n";
$baseWhereSql .= "     WHERE a.FacultyID = s.FacultyID\n";
$baseWhereSql .= "       AND a.ScheduleID = s.ScheduleID\n";
$baseWhereSql .= "       AND a.Date = ?\n";
$baseWhereSql .= "     LIMIT 1\n";
$baseWhereSql .= " ) ";
$params[] = $date;

if ($dryRun) {
    $countSql = "SELECT COUNT(*) AS cnt FROM SCHEDULES s " . $baseWhereSql;
    $stmt = $db->prepare($countSql);
    $stmt->execute($params);
    $cnt = (int)($stmt->fetch()['cnt'] ?? 0);

    $result = [
        'date' => $date,
        'day_of_week' => $dayOfWeek,
        'cutoff_time' => $isToday ? $cutoffTime : null,
        'dry_run' => true,
        'would_insert' => $cnt,
    ];

    echo $asJson ? json_encode($result, JSON_PRETTY_PRINT) . "\n" : ("Would insert: {$cnt}\n");
    exit(0);
}

$insertSql = "
    INSERT INTO ATTENDANCES (FacultyID, DeviceID, ScheduleID, Date, DayOfWeek, TimeIn, TimeOut, AttendanceStatus, Remarks)
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
    FROM SCHEDULES s
";

$insertSql .= $baseWhereSql;

$insertParams = array_merge([$date, $dayOfWeek], $params);

$stmt = $db->prepare($insertSql);
$stmt->execute($insertParams);

$result = [
    'date' => $date,
    'day_of_week' => $dayOfWeek,
    'cutoff_time' => $isToday ? $cutoffTime : null,
    'inserted' => $stmt->rowCount(),
];

echo $asJson ? json_encode($result, JSON_PRETTY_PRINT) . "\n" : ("Inserted: {$result['inserted']}\n");
