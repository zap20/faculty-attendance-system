<?php
/**
 * Faculty Model
 * Handles FACULTIES table operations
 */

class FacultyModel extends BaseModel {
    protected $table = 'FACULTIES';
    protected $primaryKey = 'FacultyID';

    public function findAllWithDepartment(): array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM FACULTIES f
            LEFT JOIN DEPARTMENTS d ON f.DepartmentID = d.DepartmentID
            ORDER BY f.FacultyName
        ");
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function findByIdWithDepartment($facultyId): ?array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM FACULTIES f
            LEFT JOIN DEPARTMENTS d ON f.DepartmentID = d.DepartmentID
            WHERE f.FacultyID = ?
        ");
        $stmt->execute([$facultyId]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    public function findByDepartment(int $departmentId): array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM FACULTIES f
            LEFT JOIN DEPARTMENTS d ON f.DepartmentID = d.DepartmentID
            WHERE f.DepartmentID = ?
            ORDER BY f.FacultyName
        ");
        $stmt->execute([$departmentId]);
        return $stmt->fetchAll();
    }

    public function hasUserAccount($facultyId): bool {
        $stmt = $this->db->prepare("SELECT 1 FROM USERACCOUNTS WHERE FacultyID = ?");
        $stmt->execute([$facultyId]);
        return $stmt->fetch() !== false;
    }

    public function findById($facultyId): ?array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM FACULTIES f
            LEFT JOIN DEPARTMENTS d ON f.DepartmentID = d.DepartmentID
            WHERE f.FacultyID = ?
        ");
        $stmt->execute([$facultyId]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    public function findByEmployeeNumber($identifier): ?array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM FACULTIES f
            LEFT JOIN DEPARTMENTS d ON f.DepartmentID = d.DepartmentID
            WHERE f.ContactInformation = ? OR f.FacultyName LIKE ? OR f.FacultyID = ?
            LIMIT 1
        ");
        $stmt->execute([$identifier, '%' . $identifier . '%', $identifier]);
        $result = $stmt->fetch();
        return $result ?: null;
    }
}
