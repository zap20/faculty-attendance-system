<?php
/**
 * User Controller
 * CRUD for USERACCOUNTS (Admin only) – used for creating DepartmentHead accounts
 */

class UserController {
    private $userModel;

    public function __construct() {
        $this->userModel = new UserModel();
    }

    /**
     * GET /api/users
     * Admin only: list all users (for DepartmentHead management)
     */
    public function index(): void {
        Auth::requireRole(['Admin']);

        $users = $this->userModel->getAllWithFaculty();
        Response::success($users);
    }

    /**
     * POST /api/users
     * Admin only: create a user (used for DepartmentHead creation)
     */
    public function store(): void {
        Auth::requireRole(['Admin']);

        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('username', 'Username')
                  ->required('password', 'Password')
                  ->required('role', 'Role')
                  ->minLength('username', 3, 'Username')
                  ->minLength('password', 6, 'Password')
                  ->inArray('role', ['Admin', 'AttendanceOfficer', 'DepartmentHead', 'Faculty'], 'Role')
                  ->validate();

        $username = trim($data['username']);
        if ($this->userModel->usernameExists($username)) {
            Response::error('Username already exists', 400);
        }

        $hashedPassword = Auth::hashPassword($data['password']);
        $userId = $this->userModel->create([
            'Username' => $username,
            'Password' => $hashedPassword,
            'Role' => $data['role'],
            'FacultyID' => $data['facultyId'] ?? null,
            'IsActive' => 1,
        ]);

        $user = $this->userModel->findByIdWithFaculty($userId);
        Response::success($user, 'User created successfully', 201);
    }

    /**
     * GET /api/users/{id}
     * Admin only: get a user by ID
     */
    public function show(int $id): void {
        Auth::requireRole(['Admin']);

        $user = $this->userModel->findByIdWithFaculty($id);
        if (!$user) {
            Response::notFound('User not found');
        }

        Response::success($user);
    }

    /**
     * PUT /api/users/{id}
     * Admin only: update a user
     */
    public function update(int $id): void {
        Auth::requireRole(['Admin']);

        $user = $this->userModel->findById($id);
        if (!$user) {
            Response::notFound('User not found');
        }

        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->optional('username', 'Username')
                  ->optional('role', 'Role')
                  ->optional('facultyId', 'Faculty ID')
                  ->optional('isActive', 'Active Status')
                  ->minLength('username', 3, 'Username')
                  ->inArray('role', ['Admin', 'AttendanceOfficer', 'DepartmentHead', 'Faculty'], 'Role')
                  ->boolean('isActive', 'Active Status')
                  ->validate();

        $updateData = [];

        if (isset($data['username'])) {
            $newUsername = trim($data['username']);
            if ($newUsername !== $user['Username'] && $this->userModel->usernameExists($newUsername)) {
                Response::error('Username already exists', 400);
            }
            $updateData['Username'] = $newUsername;
        }

        if (array_key_exists('role', $data)) {
            $updateData['Role'] = $data['role'];
        }

        if (array_key_exists('facultyId', $data)) {
            $updateData['FacultyID'] = $data['facultyId'] ?? null;
        }

        if (array_key_exists('isActive', $data)) {
            $updateData['IsActive'] = $data['isActive'] ? 1 : 0;
        }

        if (!empty($data['password'])) {
            $validator->required('password', 'Password')
                      ->minLength('password', 6, 'Password')
                      ->validate();
            $updateData['Password'] = Auth::hashPassword($data['password']);
        }

        if (empty($updateData)) {
            Response::error('No valid fields to update', 400);
        }

        $this->userModel->update($id, $updateData);
        $updated = $this->userModel->findByIdWithFaculty($id);
        Response::success($updated, 'User updated successfully');
    }

    /**
     * DELETE /api/users/{id}
     * Admin only: delete a user
     */
    public function destroy(int $id): void {
        Auth::requireRole(['Admin']);

        $user = $this->userModel->findById($id);
        if (!$user) {
            Response::notFound('User not found');
        }

        // Prevent self-deletion
        $currentUser = Auth::getCurrentUser();
        if ($currentUser['UserID'] == $id) {
            Response::error('You cannot delete your own account', 400);
        }

        $this->userModel->delete($id);
        Response::success(null, 'User deleted successfully');
    }
}
