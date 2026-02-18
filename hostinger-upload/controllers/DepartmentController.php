<?php
/**
 * Department Controller
 * CRUD operations for departments
 */

class DepartmentController {
    private $departmentModel;

    public function __construct() {
        $this->departmentModel = new DepartmentModel();
    }

    /**
     * GET /api/departments
     */
    public function index(): void {
        Auth::requireAuth();
        
        $departments = $this->departmentModel->findAllWithStats();
        Response::success($departments);
    }

    /**
     * GET /api/departments/{id}
     */
    public function show(int $id): void {
        Auth::requireAuth();
        
        $department = $this->departmentModel->findById($id);
        if (!$department) {
            Response::notFound('Department not found');
        }

        Response::success($department);
    }

    /**
     * POST /api/departments
     */
    public function store(): void {
        Auth::requireRole(['Admin']);
        
        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('DepartmentName', 'Department name')
                  ->maxLength('DepartmentName', 100, 'Department name')
                  ->integer('DepartmentDeanID', 'Department dean ID')
                  ->integer('DepartmentHeadUserID', 'Department head user ID')
                  ->validate();

        if (!empty($data['DepartmentDeanID'])) {
            $db = Database::getInstance()->getConnection();
            $stmt = $db->prepare('SELECT 1 FROM department_deans WHERE DepartmentDeanID = ? LIMIT 1');
            $stmt->execute([(int) $data['DepartmentDeanID']]);
            if ($stmt->fetch() === false) {
                Response::error('Department dean not found', 404);
            }
        }

        if (!empty($data['DepartmentHeadUserID'])) {
            $userModel = new UserModel();
            $headUser = $userModel->findById((int) $data['DepartmentHeadUserID']);
            if (!$headUser) {
                Response::error('Department head user not found', 404);
            }
            if (($headUser['Role'] ?? null) !== 'DepartmentHead') {
                Response::error('Selected user is not a DepartmentHead', 400);
            }
        }

        $createData = [
            'DepartmentName' => $data['DepartmentName'],
            'DepartmentDeanID' => $data['DepartmentDeanID'] ?? null
        ];

        if (!empty($data['DepartmentHeadUserID'])) {
            $createData['DepartmentHeadUserID'] = (int) $data['DepartmentHeadUserID'];
        }

        try {
            $departmentId = $this->departmentModel->create($createData);
        } catch (PDOException $e) {
            if (!empty($data['DepartmentHeadUserID'])) {
                Response::error('Database not updated for DepartmentHead linking. Please run database/add_department_head_userid.sql', 500);
            }
            Response::error('Failed to create department', 500);
        }

        $department = $this->departmentModel->findById($departmentId);
        Response::success($department, 'Department created successfully', 201);
    }

    /**
     * PUT /api/departments/{id}
     */
    public function update(int $id): void {
        Auth::requireRole(['Admin']);
        
        $department = $this->departmentModel->findById($id);
        if (!$department) {
            Response::notFound('Department not found');
        }

        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('DepartmentName', 'Department name')
                  ->maxLength('DepartmentName', 100, 'Department name')
                  ->integer('DepartmentDeanID', 'Department dean ID')
                  ->integer('DepartmentHeadUserID', 'Department head user ID')
                  ->validate();

        if (!empty($data['DepartmentDeanID'])) {
            $db = Database::getInstance()->getConnection();
            $stmt = $db->prepare('SELECT 1 FROM department_deans WHERE DepartmentDeanID = ? LIMIT 1');
            $stmt->execute([(int) $data['DepartmentDeanID']]);
            if ($stmt->fetch() === false) {
                Response::error('Department dean not found', 404);
            }
        }

        if (!empty($data['DepartmentHeadUserID'])) {
            $userModel = new UserModel();
            $headUser = $userModel->findById((int) $data['DepartmentHeadUserID']);
            if (!$headUser) {
                Response::error('Department head user not found', 404);
            }
            if (($headUser['Role'] ?? null) !== 'DepartmentHead') {
                Response::error('Selected user is not a DepartmentHead', 400);
            }
        }

        $updateData = [
            'DepartmentName' => $data['DepartmentName'],
            'DepartmentDeanID' => $data['DepartmentDeanID'] ?? null
        ];

        $hasHeadField = array_key_exists('DepartmentHeadUserID', $data ?? []);
        if ($hasHeadField) {
            $updateData['DepartmentHeadUserID'] = !empty($data['DepartmentHeadUserID'])
                ? (int) $data['DepartmentHeadUserID']
                : null;
        }

        try {
            $this->departmentModel->update($id, $updateData);
        } catch (PDOException $e) {
            if ($hasHeadField) {
                Response::error('Database not updated for DepartmentHead linking. Please run database/add_department_head_userid.sql', 500);
            }
            Response::error('Failed to update department', 500);
        }

        $updatedDepartment = $this->departmentModel->findById($id);
        Response::success($updatedDepartment, 'Department updated successfully');
    }

    /**
     * DELETE /api/departments/{id}
     */
    public function destroy(int $id): void {
        Auth::requireRole(['Admin']);
        
        $department = $this->departmentModel->findById($id);
        if (!$department) {
            Response::notFound('Department not found');
        }

        // Check for related records
        if ($this->departmentModel->hasFaculties($id)) {
            Response::error('Cannot delete department with associated faculties', 400);
        }
        if ($this->departmentModel->hasSubjects($id)) {
            Response::error('Cannot delete department with associated subjects', 400);
        }

        $this->departmentModel->delete($id);
        Response::success(null, 'Department deleted successfully');
    }
}
