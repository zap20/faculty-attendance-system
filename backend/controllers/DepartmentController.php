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
                  ->validate();

        $departmentId = $this->departmentModel->create([
            'DepartmentName' => $data['DepartmentName'],
            'DepartmentHead' => $data['DepartmentHead'] ?? null,
            'DepartmentDean' => $data['DepartmentDean'] ?? null
        ]);

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
                  ->validate();

        $this->departmentModel->update($id, [
            'DepartmentName' => $data['DepartmentName'],
            'DepartmentHead' => $data['DepartmentHead'] ?? null,
            'DepartmentDean' => $data['DepartmentDean'] ?? null
        ]);

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
