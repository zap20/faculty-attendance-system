<?php
/**
 * Department Model
 * Handles DEPARTMENTS table operations
 */

class DepartmentModel extends BaseModel {
    protected $table = 'DEPARTMENTS';
    protected $primaryKey = 'DepartmentID';

    public function findAllWithStats(): array {
        $stmt = $this->db->prepare("
            SELECT d.*, 
                   COUNT(DISTINCT f.FacultyID) as FacultyCount,
                   COUNT(DISTINCT s.SubjectID) as SubjectCount
            FROM DEPARTMENTS d
            LEFT JOIN FACULTIES f ON d.DepartmentID = f.DepartmentID
            LEFT JOIN SUBJECTS s ON d.DepartmentID = s.DepartmentID
            GROUP BY d.DepartmentID
            ORDER BY d.DepartmentName
        ");
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function hasFaculties(int $departmentId): bool {
        $stmt = $this->db->prepare("SELECT 1 FROM FACULTIES WHERE DepartmentID = ? LIMIT 1");
        $stmt->execute([$departmentId]);
        return $stmt->fetch() !== false;
    }

    public function hasSubjects(int $departmentId): bool {
        $stmt = $this->db->prepare("SELECT 1 FROM SUBJECTS WHERE DepartmentID = ? LIMIT 1");
        $stmt->execute([$departmentId]);
        return $stmt->fetch() !== false;
    }
}
