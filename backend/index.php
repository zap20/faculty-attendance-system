
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');
/**
 * API Router
 * Faculty Attendance and Monitoring System
 * 
 * Main entry point for all API requests
 */

require_once __DIR__ . '/../config/config.php';

// Get request method and URI
$method = $_SERVER['REQUEST_METHOD'];
$requestUri = $_SERVER['REQUEST_URI'];

// Debug endpoint
if (strpos($requestUri, 'debug') !== false) {
    // Compute segments the same way the router does
    $debugUri = parse_url($requestUri, PHP_URL_PATH);
    $debugScriptName = $_SERVER['SCRIPT_NAME'];
    $debugScriptDir = dirname($debugScriptName);

    if (strpos($debugUri, $debugScriptName) === 0) {
        $debugUri = substr($debugUri, strlen($debugScriptName));
    } elseif (strpos($debugUri, $debugScriptDir) === 0) {
        $debugUri = substr($debugUri, strlen($debugScriptDir));
    }

    $debugUri = trim($debugUri, '/');
    $debugSegments = ($debugUri !== '') ? explode('/', $debugUri) : [];
    if (($debugSegments[0] ?? null) === 'api') {
        $debugSegments = array_slice($debugSegments, 1);
    }
    if (($debugSegments[0] ?? null) === 'index.php') {
        $debugSegments = array_slice($debugSegments, 1);
    }

    header('Content-Type: application/json');
    echo json_encode([
        'METHOD' => $method,
        'REQUEST_URI' => $requestUri,
        'SCRIPT_NAME' => $_SERVER['SCRIPT_NAME'],
        'PHP_SELF' => $_SERVER['PHP_SELF'] ?? 'not set',
        'SCRIPT_FILENAME' => $_SERVER['SCRIPT_FILENAME'] ?? null,
        'DOCUMENT_ROOT' => $_SERVER['DOCUMENT_ROOT'] ?? null,
        'INDEX_PHP_FILE' => __FILE__,
        'PARSED_PATH' => $debugUri,
        'SEGMENTS' => $debugSegments
    ]);
    exit;
}

// Remove query string
$uri = parse_url($requestUri, PHP_URL_PATH);

// Remove the full script path including index.php
$scriptName = $_SERVER['SCRIPT_NAME'];
$scriptDir = dirname($scriptName);

// If URI contains the full script path (direct access), remove it
if (strpos($uri, $scriptName) === 0) {
    $uri = substr($uri, strlen($scriptName));
}
// Otherwise just remove the directory path
elseif (strpos($uri, $scriptDir) === 0) {
    $uri = substr($uri, strlen($scriptDir));
}

$uri = trim($uri, '/');

// Split URI into segments
$segments = ($uri !== '') ? explode('/', $uri) : [];

// Normalize segments for environments where SCRIPT_NAME stripping does not remove
// '/api' or 'index.php' properly (e.g. PHP built-in server path-info variations).
if (($segments[0] ?? null) === 'api') {
    $segments = array_slice($segments, 1);
}
if (($segments[0] ?? null) === 'index.php') {
    $segments = array_slice($segments, 1);
}

// Route the request
try {
    // Root endpoint - API info
    if (empty($segments) || $segments[0] === '' || !isset($segments[0])) {
        Response::success(['message' => 'Faculty Attendance API', 'version' => '1.0.0']);
        exit;
    }
    
    // Auth routes
    elseif ($segments[0] === 'auth') {
        $controller = new AuthController();
        
        if ($method === 'POST' && ($segments[1] ?? '') === 'login') {
            $controller->login();
        } elseif ($method === 'POST' && ($segments[1] ?? '') === 'logout') {
            $controller->logout();
        } elseif ($method === 'PUT' && ($segments[1] ?? '') === 'password') {
            $controller->changePassword();
        } else {
            Response::notFound('Auth endpoint not found');
        }
    }

    // DepartmentHead routes
    elseif ($segments[0] === 'department-head') {
        $controller = new DepartmentHeadController();
        $resource = $segments[1] ?? null;
        $action = $segments[2] ?? null;
        $id = $segments[2] ?? null;

        if ($method === 'GET' && $resource === 'dashboard' && $action === 'summary') {
            $controller->dashboardSummary();
        } elseif ($method === 'GET' && $resource === 'analytics') {
            $controller->analytics();
        } elseif ($resource === 'faculties' && $method === 'GET') {
            $controller->facultiesIndex();
        } elseif ($resource === 'faculties' && $method === 'POST') {
            $controller->createFaculty();
        } elseif ($resource === 'schedules' && $method === 'GET') {
            $controller->schedulesIndex();
        } elseif ($resource === 'schedules' && $method === 'POST') {
            $controller->createSchedule();
        } elseif ($resource === 'schedules' && $method === 'PUT' && $id) {
            $controller->updateSchedule((int) $id);
        } elseif ($resource === 'schedules' && $method === 'DELETE' && $id) {
            $controller->deleteSchedule((int) $id);
        } else {
            Response::notFound('DepartmentHead endpoint not found');
        }
    }
    
    // Me route (current user profile)
    elseif ($segments[0] === 'me' && $method === 'GET') {
        $controller = new AuthController();
        $controller->me();
    }
    
    // Faculties routes
    elseif ($segments[0] === 'faculties') {
        $controller = new FacultyController();
        $id = $segments[1] ?? null;
        
        if ($method === 'GET' && $id === 'my-department') {
            $controller->myDepartment();
        } elseif ($method === 'GET' && !$id) {
            $controller->index();
        } elseif ($method === 'GET' && $id) {
            $controller->show((string) $id);
        } elseif ($method === 'POST') {
            $controller->store();
        } elseif ($method === 'PUT' && $id) {
            $controller->update((string) $id);
        } elseif ($method === 'DELETE' && $id) {
            $controller->destroy((string) $id);
        } else {
            Response::notFound('Faculty endpoint not found');
        }
    }
    
    // Departments routes
    elseif ($segments[0] === 'departments') {
        $controller = new DepartmentController();
        $id = $segments[1] ?? null;
        
        if ($method === 'GET' && !$id) {
            $controller->index();
        } elseif ($method === 'GET' && $id) {
            $controller->show((int) $id);
        } elseif ($method === 'POST') {
            $controller->store();
        } elseif ($method === 'PUT' && $id) {
            $controller->update((int) $id);
        } elseif ($method === 'DELETE' && $id) {
            $controller->destroy((int) $id);
        } else {
            Response::notFound('Department endpoint not found');
        }
    }
    
    // Subjects routes
    elseif ($segments[0] === 'subjects') {
        $controller = new SubjectController();
        $id = $segments[1] ?? null;
        
        if ($method === 'GET' && !$id) {
            $controller->index();
        } elseif ($method === 'GET' && $id) {
            $controller->show((int) $id);
        } elseif ($method === 'POST') {
            $controller->store();
        } elseif ($method === 'PUT' && $id) {
            $controller->update((int) $id);
        } elseif ($method === 'DELETE' && $id) {
            $controller->destroy((int) $id);
        } else {
            Response::notFound('Subject endpoint not found');
        }
    }
    
    // Rooms routes
    elseif ($segments[0] === 'rooms') {
        $controller = new RoomController();
        $id = $segments[1] ?? null;
        
        if ($method === 'GET' && !$id) {
            $controller->index();
        } elseif ($method === 'GET' && $id) {
            $controller->show((int) $id);
        } elseif ($method === 'POST') {
            $controller->store();
        } elseif ($method === 'PUT' && $id) {
            $controller->update((int) $id);
        } elseif ($method === 'DELETE' && $id) {
            $controller->destroy((int) $id);
        } else {
            Response::notFound('Room endpoint not found');
        }
    }
    
    // Schedules routes
    elseif ($segments[0] === 'schedules') {
        $controller = new ScheduleController();
        $id = $segments[1] ?? null;
        
        if ($method === 'GET' && $id === 'today') {
            $controller->today();
        } elseif ($method === 'GET' && !$id) {
            $controller->index();
        } elseif ($method === 'GET' && $id) {
            $controller->show((int) $id);
        } elseif ($method === 'POST') {
            $controller->store();
        } elseif ($method === 'PUT' && $id) {
            $controller->update((int) $id);
        } elseif ($method === 'DELETE' && $id) {
            $controller->destroy((int) $id);
        } else {
            Response::notFound('Schedule endpoint not found');
        }
    }
    
    // Devices routes
    elseif ($segments[0] === 'devices') {
        $controller = new DeviceController();
        $id = $segments[1] ?? null;
        
        if ($method === 'GET' && !$id) {
            $controller->index();
        } elseif ($method === 'GET' && $id) {
            $controller->show((int) $id);
        } elseif ($method === 'POST') {
            $controller->store();
        } elseif ($method === 'PUT' && $id) {
            $controller->update((int) $id);
        } elseif ($method === 'DELETE' && $id) {
            $controller->destroy((int) $id);
        } else {
            Response::notFound('Device endpoint not found');
        }
    }
    
    // Attendance routes
    elseif ($segments[0] === 'attendance') {
        $controller = new AttendanceController();
        $action = $segments[1] ?? null;
        
        if ($method === 'GET' && !$action) {
            $controller->index();
        } elseif ($method === 'GET' && $action === 'today') {
            $controller->today();
        } elseif ($method === 'GET' && $action === 'history') {
            $controller->history();
        } elseif ($method === 'POST' && $action === 'auto-absent') {
            $controller->autoAbsent();
        } elseif ($method === 'POST' && $action === 'timein') {
            $controller->timeIn();
        } elseif ($method === 'POST' && $action === 'timeout') {
            $controller->timeOut();
        } elseif ($method === 'POST' && $action === 'qr') {
            $controller->recordByQR();
        } elseif ($method === 'PUT' && $action === 'update-status') {
            $controller->updateStatus();
        } else {
            Response::notFound('Attendance endpoint not found');
        }
    }
    
    // Reports routes
    elseif ($segments[0] === 'reports') {
        $controller = new ReportController();
        $action = $segments[1] ?? null;
        
        if ($method === 'GET' && $action === 'summary') {
            $controller->summary();
        } elseif ($method === 'GET' && $action === 'daily') {
            $controller->daily();
        } elseif ($method === 'GET' && $action === 'date-range') {
            $controller->dateRange();
        } elseif ($method === 'GET' && $action === 'faculty-performance') {
            $controller->facultyPerformance();
        } elseif ($method === 'GET' && $action === 'room-utilization') {
            $controller->roomUtilization();
        } elseif ($method === 'GET' && $action === 'exceptions') {
            $controller->exceptions();
        } elseif ($method === 'GET' && $action === 'export-csv') {
            $controller->exportCsv();
        } elseif ($method === 'GET' && $action === 'department') {
            $controller->department();
        } elseif ($method === 'GET' && $action === 'dashboard') {
            $controller->dashboard();
        } else {
            Response::notFound('Report endpoint not found');
        }
    }
    
    // Sync routes (offline-first mobile support)
    elseif ($segments[0] === 'sync') {
        $controller = new SyncController();
        $action = $segments[1] ?? null;
        
        if ($method === 'POST' && $action === 'push') {
            $controller->push();
        } elseif ($method === 'GET' && $action === 'pull') {
            $controller->pull();
        } elseif ($method === 'GET' && $action === 'last-updated') {
            $controller->lastUpdated();
        } elseif ($method === 'GET' && $action === 'status') {
            $controller->status();
        } else {
            Response::notFound('Sync endpoint not found');
        }
    }
    
    // Faculty Dashboard routes
    elseif ($segments[0] === 'faculty') {
        $controller = new FacultyDashboardController();
        $action = $segments[1] ?? null;

        if ($method === 'GET' && $action === 'dashboard-summary') {
            $controller->dashboardSummary();
        } elseif ($method === 'GET' && $action === 'schedule') {
            $controller->schedule();
        } elseif ($method === 'GET' && $action === 'attendance') {
            $controller->attendance();
        } elseif ($method === 'GET' && $action === 'analytics-summary') {
            $controller->analyticsSummary();
        } elseif ($method === 'GET' && $action === 'attendance-trend') {
            $controller->attendanceTrend();
        } elseif ($method === 'GET' && $action === 'status-breakdown') {
            $controller->statusBreakdown();
        } else {
            Response::notFound('Faculty endpoint not found');
        }
    }

    // Admin Analytics routes
    elseif ($segments[0] === 'admin-analytics') {
        $controller = new AdminAnalyticsController();
        $action = $segments[1] ?? null;

        if ($method === 'GET' && $action === 'summary') {
            $controller->summary();
        } elseif ($method === 'GET' && $action === 'department-comparison') {
            $controller->departmentComparison();
        } elseif ($method === 'GET' && $action === 'department-ranking') {
            $controller->departmentRanking();
        } elseif ($method === 'GET' && $action === 'attendance-trend') {
            $controller->attendanceTrend();
        } elseif ($method === 'GET' && $action === 'exception-heatmap') {
            $controller->exceptionHeatmap();
        } elseif ($method === 'GET' && $action === 'room-utilization') {
            $controller->roomUtilization();
        } elseif ($method === 'GET' && $action === 'faculty-performance') {
            $controller->facultyPerformance();
        } else {
            Response::notFound('Admin analytics endpoint not found');
        }
    }

    // Health check
    elseif ($segments[0] === 'health' && $method === 'GET') {
        Response::success([
            'status' => 'ok',
            'timestamp' => date('Y-m-d H:i:s'),
            'version' => '1.0.0'
        ]);
    }
    
    // Not found
    else {
        Response::notFound('Endpoint not found');
    }

} catch (PDOException $e) {
    Response::error('Database error: ' . $e->getMessage(), 500);
} catch (Exception $e) {
    Response::error($e->getMessage(), 500);
}
