<?php
/**
 * Subject Model
 * Handles SUBJECTS table operations
 */

class SubjectModel extends BaseModel {
    protected $table = 'subjects';
    protected $primaryKey = 'SubjectID';

    public function findAllWithDepartment(): array {
        $stmt = $this->db->prepare("
            SELECT s.*, d.DepartmentName
            FROM subjects s
            LEFT JOIN departments d ON s.DepartmentID = d.DepartmentID
            ORDER BY s.CourseCode
        ");
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function findByIdWithDepartment(int $subjectId): ?array {
        $stmt = $this->db->prepare("
            SELECT s.*, d.DepartmentName
            FROM subjects s
            LEFT JOIN departments d ON s.DepartmentID = d.DepartmentID
            WHERE s.SubjectID = ?
        ");
        $stmt->execute([$subjectId]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    public function findByDepartment(int $departmentId): array {
        $stmt = $this->db->prepare("
            SELECT s.*, d.DepartmentName
            FROM subjects s
            LEFT JOIN departments d ON s.DepartmentID = d.DepartmentID
            WHERE s.DepartmentID = ?
            ORDER BY s.CourseCode
        ");
        $stmt->execute([$departmentId]);
        return $stmt->fetchAll();
    }

    public function courseCodeExists(string $courseCode, int $excludeId = null): bool {
        $sql = "SELECT 1 FROM subjects WHERE CourseCode = ?";
        $params = [$courseCode];
        
        if ($excludeId) {
            $sql .= " AND SubjectID != ?";
            $params[] = $excludeId;
        }
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetch() !== false;
    }
}
