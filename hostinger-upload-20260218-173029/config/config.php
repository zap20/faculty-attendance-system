<?php
/**
 * Application Configuration
 * Faculty Attendance and Monitoring System
 */

// Error reporting (log errors but never display them in output — prevents HTML leaking into JSON responses)
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// Timezone
date_default_timezone_set('Asia/Manila');

// JWT/Token Configuration
define('TOKEN_SECRET', 'your-secret-key-change-in-production-2024');
define('TOKEN_EXPIRY_HOURS', 24);

// Attendance Configuration
define('GRACE_PERIOD_MINUTES', 10);

// CORS Headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Autoload function
spl_autoload_register(function ($class) {
    $paths = [
        __DIR__ . '/../models/',
        __DIR__ . '/../controllers/',
        __DIR__ . '/../helpers/',
    ];
    
    foreach ($paths as $path) {
        $file = $path . $class . '.php';
        if (file_exists($file)) {
            require_once $file;
            return;
        }
    }
});

require_once __DIR__ . '/database.php';
