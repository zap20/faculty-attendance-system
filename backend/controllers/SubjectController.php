<?php
/**
 * Subject Controller
 * CRUD operations for subjects
 */

class SubjectController {
    private $subjectModel;
    private $departmentModel;

    public function __construct() {
        $this->subjectModel = new SubjectModel();
        $this->departmentModel = new DepartmentModel();
    }

    /**
     * GET /api/subjects
     */
    public function index(): void {
        Auth::requireAuth();
        
        $departmentId = $_GET['departmentId'] ?? null;
        
        if ($departmentId) {
            $subjects = $this->subjectModel->findByDepartment((int) $departmentId);
        } else {
            $subjects = $this->subjectModel->findAllWithDepartment();
        }

        Response::success($subjects);
    }

    /**
     * GET /api/subjects/{id}
     */
    public function show(int $id): void {
        Auth::requireAuth();
        
        $subject = $this->subjectModel->findByIdWithDepartment($id);
        if (!$subject) {
            Response::notFound('Subject not found');
        }

        Response::success($subject);
    }

    /**
     * POST /api/subjects
     */
    public function store(): void {
        Auth::requireRole(['Admin']);
        
        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('SubjectName', 'Subject name')
                  ->required('CourseCode', 'Course code')
                  ->required('Units', 'Units')
                  ->required('DepartmentID', 'Department')
                  ->integer('Units', 'Units')
                  ->integer('DepartmentID', 'Department ID')
                  ->validate();

        // Verify department exists
        if (!$this->departmentModel->exists($data['DepartmentID'])) {
            Response::error('Department not found', 404);
        }

        // Check course code uniqueness
        if ($this->subjectModel->courseCodeExists($data['CourseCode'])) {
            Response::error('Course code already exists', 400);
        }

        $subjectId = $this->subjectModel->create([
            'SubjectName' => $data['SubjectName'],
            'CourseCode' => $data['CourseCode'],
            'Units' => $data['Units'],
            'DepartmentID' => $data['DepartmentID']
        ]);

        $subject = $this->subjectModel->findByIdWithDepartment($subjectId);
        Response::success($subject, 'Subject created successfully', 201);
    }

    /**
     * PUT /api/subjects/{id}
     */
    public function update(int $id): void {
        Auth::requireRole(['Admin']);
        
        $subject = $this->subjectModel->findById($id);
        if (!$subject) {
            Response::notFound('Subject not found');
        }

        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('SubjectName', 'Subject name')
                  ->required('CourseCode', 'Course code')
                  ->required('Units', 'Units')
                  ->required('DepartmentID', 'Department')
                  ->integer('Units', 'Units')
                  ->integer('DepartmentID', 'Department ID')
                  ->validate();

        // Verify department exists
        if (!$this->departmentModel->exists($data['DepartmentID'])) {
            Response::error('Department not found', 404);
        }

        // Check course code uniqueness (excluding current)
        if ($this->subjectModel->courseCodeExists($data['CourseCode'], $id)) {
            Response::error('Course code already exists', 400);
        }

        $this->subjectModel->update($id, [
            'SubjectName' => $data['SubjectName'],
            'CourseCode' => $data['CourseCode'],
            'Units' => $data['Units'],
            'DepartmentID' => $data['DepartmentID']
        ]);

        $updatedSubject = $this->subjectModel->findByIdWithDepartment($id);
        Response::success($updatedSubject, 'Subject updated successfully');
    }

    /**
     * DELETE /api/subjects/{id}
     */
    public function destroy(int $id): void {
        Auth::requireRole(['Admin']);
        
        $subject = $this->subjectModel->findById($id);
        if (!$subject) {
            Response::notFound('Subject not found');
        }

        $this->subjectModel->delete($id);
        Response::success(null, 'Subject deleted successfully');
    }
}
