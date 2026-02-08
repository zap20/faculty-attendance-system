<?php
require_once 'config/config.php';
$db = Database::getInstance()->getConnection();

echo "DEPARTMENTS table structure:\n";
$stmt = $db->query('DESCRIBE DEPARTMENTS');
while ($row = $stmt->fetch()) {
    echo $row['Field'] . ' | ' . $row['Type'] . ' | ' . $row['Null'] . ' | ' . $row['Key'] . PHP_EOL;
}

echo "\nCurrent DEPARTMENTS rows:\n";
$stmt = $db->query('SELECT * FROM DEPARTMENTS');
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo json_encode($row, JSON_PRETTY_PRINT) . PHP_EOL;
}

echo "\nUSERACCOUNTS with Role = DepartmentHead:\n";
$stmt = $db->prepare('SELECT UserID, Username, Role FROM USERACCOUNTS WHERE Role = ?');
$stmt->execute(['DepartmentHead']);
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo json_encode($row, JSON_PRETTY_PRINT) . PHP_EOL;
}
