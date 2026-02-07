<?php
/**
 * Auth Controller
 * Handles authentication endpoints
 */

class AuthController {
    private $userModel;

    public function __construct() {
        $this->userModel = new UserModel();
    }

    /**
     * POST /api/auth/login
     * Login and get token
     */
    public function login(): void {
        $data = json_decode(file_get_contents('php://input'), true);
        
        $validator = new Validator($data ?? []);
        $validator->required('username', 'Username')
                  ->required('password', 'Password')
                  ->validate();

        $user = $this->userModel->findByUsername($data['username']);

        if (!$user || !Auth::verifyPassword($data['password'], $user['Password'])) {
            Response::error('Invalid username or password', 401);
        }

        if (!$user['IsActive']) {
            Response::error('Account is deactivated', 401);
        }

        $token = Auth::createToken($user['UserID']);

        Response::success([
            'token' => $token,
            'user' => [
                'userId' => $user['UserID'],
                'username' => $user['Username'],
                'role' => $user['Role'],
                'facultyId' => $user['FacultyID'],
                'facultyName' => $user['FacultyName'] ?? null,
                'departmentId' => $user['DepartmentID'] ?? null
            ]
        ], 'Login successful');
    }

    /**
     * POST /api/auth/logout
     * Logout and invalidate token
     */
    public function logout(): void {
        $token = Auth::getBearerToken();
        
        if ($token) {
            Auth::logout($token);
        }

        Response::success(null, 'Logged out successfully');
    }

    /**
     * GET /api/me
     * Get current user profile
     */
    public function me(): void {
        $user = Auth::requireAuth();
        
        $fullUser = $this->userModel->findByIdWithFaculty($user['UserID']);

        Response::success([
            'userId' => $fullUser['UserID'],
            'username' => $fullUser['Username'],
            'role' => $fullUser['Role'],
            'facultyId' => $fullUser['FacultyID'],
            'facultyName' => $fullUser['FacultyName'] ?? null,
            'departmentId' => $fullUser['DepartmentID'] ?? null,
            'departmentName' => $fullUser['DepartmentName'] ?? null,
            'isActive' => (bool) $fullUser['IsActive']
        ]);
    }

    /**
     * PUT /api/auth/password
     * Change password
     */
    public function changePassword(): void {
        $user = Auth::requireAuth();
        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('currentPassword', 'Current password')
                  ->required('newPassword', 'New password')
                  ->minLength('newPassword', 6, 'New password')
                  ->validate();

        $fullUser = $this->userModel->findById($user['UserID']);

        if (!Auth::verifyPassword($data['currentPassword'], $fullUser['Password'])) {
            Response::error('Current password is incorrect', 400);
        }

        $this->userModel->update($user['UserID'], [
            'Password' => Auth::hashPassword($data['newPassword'])
        ]);

        Response::success(null, 'Password changed successfully');
    }
}
