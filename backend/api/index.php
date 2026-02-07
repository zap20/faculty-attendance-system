<?php
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
    header('Content-Type: application/json');
    echo json_encode([
        'REQUEST_URI' => $requestUri,
        'SCRIPT_NAME' => $_SERVER['SCRIPT_NAME'],
        'PHP_SELF' => $_SERVER['PHP_SELF'] ?? 'not set'
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
    
    // Me route (current user profile)
    elseif ($segments[0] === 'me' && $method === 'GET') {
        $controller = new AuthController();
        $controller->me();
    }
    
    // Faculties routes
    elseif ($segments[0] === 'faculties') {
        $controller = new FacultyController();
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
        } elseif ($method === 'GET' && $action === 'department') {
            $controller->department();
        } elseif ($method === 'GET' && $action === 'dashboard') {
            $controller->dashboard();
        } else {
            Response::notFound('Report endpoint not found');
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
