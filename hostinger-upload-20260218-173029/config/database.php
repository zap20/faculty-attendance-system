<?php
/**
 * Database Configuration
 * Faculty Attendance and Monitoring System
 * 
 * Environment detection: checks for HOSTINGER_ENV constant or .env file
 * to determine if running on Hostinger or locally.
 */

// Detect environment
$isHostinger = file_exists(__DIR__ . '/../.env.hostinger');

if ($isHostinger) {
    // Hostinger production credentials
    // UPDATE THESE after creating your Hostinger database
    define('DB_HOST', 'localhost');
    define('DB_NAME', 'u710950564_attendance');
    define('DB_USER', 'u710950564_attendanceMit');
    define('DB_PASS', 'Salapare2026Mit');
} else {
    // Local development credentials
    define('DB_HOST', 'localhost');
    define('DB_NAME', 'faculty_attendance_db');
    define('DB_USER', 'root');
    define('DB_PASS', '');
}
define('DB_CHARSET', 'utf8mb4');



class Database {
    private static $instance = null;
    private $connection;

    private function __construct() {
        try {
            $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=" . DB_CHARSET;
            $options = [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ];
            $this->connection = new PDO($dsn, DB_USER, DB_PASS, $options);
        } catch (PDOException $e) {
            throw new Exception("Database connection failed: " . $e->getMessage());
        }
    }

    public static function getInstance(): Database {
        if (self::$instance === null) {
            self::$instance = new Database();
        }
        return self::$instance;
    }

    public function getConnection(): PDO {
        return $this->connection;
    }

    // Prevent cloning
    private function __clone() {}

    // Prevent unserialization
    public function __wakeup() {
        throw new Exception("Cannot unserialize singleton");
    }
}
