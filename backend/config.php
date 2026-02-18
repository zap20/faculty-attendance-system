<?php
$host = "localhost";
$dbname = "u710950564_attendance";
$username = "u710950564_attendanceMit";
$password = "Salapare2026Mit"; // your real password

$conn = new mysqli($host, $username, $password, $dbname);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
