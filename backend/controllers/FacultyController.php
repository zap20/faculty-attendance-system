<?php
/**
 * Faculty Controller
 * CRUD operations for faculties
 */

class FacultyController {
    private $facultyModel;
    private $departmentModel;

    public function __construct() {
        $this->facultyModel = new FacultyModel();
        $this->departmentModel = new DepartmentModel();
    }

    /**
     * GET /api/faculties
     */
    public function index(): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead']);
        
        $user = Auth::getCurrentUser();
        
        // DepartmentHead can only see their department's faculty
        if ($user['Role'] === 'DepartmentHead' && $user['DepartmentID']) {
            $faculties = $this->facultyModel->findByDepartment($user['DepartmentID']);
        } else {
            $faculties = $this->facultyModel->findAllWithDepartment();
        }

        Response::success($faculties);
    }

    /**
     * GET /api/faculties/{id}
     */
    public function show(int $id): void {
        Auth::requireRole(['Admin', 'AttendanceOfficer', 'DepartmentHead', 'Faculty']);
        
        $user = Auth::getCurrentUser();
        $faculty = $this->facultyModel->findByIdWithDepartment($id);

        if (!$faculty) {
            Response::notFound('Faculty not found');
        }

        // Faculty can only view themselves, DepartmentHead can view their department
        if ($user['Role'] === 'Faculty' && $user['FacultyID'] != $id) {
            Response::forbidden('Cannot view other faculty profiles');
        }
        if ($user['Role'] === 'DepartmentHead' && $user['DepartmentID'] != $faculty['DepartmentID']) {
            Response::forbidden('Cannot view faculty from other departments');
        }

        Response::success($faculty);
    }

    /**
     * POST /api/faculties
     */
    public function store(): void {
        Auth::requireRole(['Admin']);
        
        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('FacultyName', 'Faculty name')
                  ->required('DepartmentID', 'Department')
                  ->required('Position', 'Position')
                  ->required('EmploymentStatus', 'Employment status')
                  ->integer('DepartmentID', 'Department ID')
                  ->validate();

        // Verify department exists
        if (!$this->departmentModel->exists($data['DepartmentID'])) {
            Response::error('Department not found', 404);
        }

        $facultyId = $this->facultyModel->create([
            'FacultyName' => $data['FacultyName'],
            'DepartmentID' => $data['DepartmentID'],
            'Position' => $data['Position'],
            'EmploymentStatus' => $data['EmploymentStatus'],
            'ContactInformation' => $data['ContactInformation'] ?? null
        ]);

        $faculty = $this->facultyModel->findByIdWithDepartment($facultyId);
        Response::success($faculty, 'Faculty created successfully', 201);
    }

    /**
     * PUT /api/faculties/{id}
     */
    public function update(int $id): void {
        Auth::requireRole(['Admin']);
        
        $faculty = $this->facultyModel->findById($id);
        if (!$faculty) {
            Response::notFound('Faculty not found');
        }

        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('FacultyName', 'Faculty name')
                  ->required('DepartmentID', 'Department')
                  ->required('Position', 'Position')
                  ->required('EmploymentStatus', 'Employment status')
                  ->integer('DepartmentID', 'Department ID')
                  ->validate();

        // Verify department exists
        if (!$this->departmentModel->exists($data['DepartmentID'])) {
            Response::error('Department not found', 404);
        }

        $this->facultyModel->update($id, [
            'FacultyName' => $data['FacultyName'],
            'DepartmentID' => $data['DepartmentID'],
            'Position' => $data['Position'],
            'EmploymentStatus' => $data['EmploymentStatus'],
            'ContactInformation' => $data['ContactInformation'] ?? null
        ]);

        $updatedFaculty = $this->facultyModel->findByIdWithDepartment($id);
        Response::success($updatedFaculty, 'Faculty updated successfully');
    }

    /**
     * DELETE /api/faculties/{id}
     */
    public function destroy(int $id): void {
        Auth::requireRole(['Admin']);
        
        $faculty = $this->facultyModel->findById($id);
        if (!$faculty) {
            Response::notFound('Faculty not found');
        }

        // Check if faculty has user account
        if ($this->facultyModel->hasUserAccount($id)) {
            Response::error('Cannot delete faculty with associated user account', 400);
        }

        $this->facultyModel->delete($id);
        Response::success(null, 'Faculty deleted successfully');
    }
}
