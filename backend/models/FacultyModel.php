<?php
/**
 * Faculty Model
 * Handles FACULTIES table operations
 */

class FacultyModel extends BaseModel {
    protected $table = 'faculties';
    protected $primaryKey = 'FacultyID';

    public function generateNextFacultyId(?int $year = null): string {
        $year = $year ?? (int) date('Y');
        $prefix = $year . '-';

        $stmt = $this->db->prepare("SELECT MAX(FacultyID) as MaxId FROM {$this->table} WHERE FacultyID LIKE ?");
        $stmt->execute([$prefix . '%']);
        $row = $stmt->fetch();
        $maxId = $row['MaxId'] ?? null;

        $nextSeq = 1;
        if ($maxId) {
            $parts = explode('-', $maxId);
            if (count($parts) === 2 && ctype_digit($parts[1])) {
                $nextSeq = (int) $parts[1] + 1;
            }
        }

        return sprintf('%d-%03d', $year, $nextSeq);
    }

    public function createWithId(array $data): string {
        if (empty($data['FacultyID'])) {
            throw new Exception('FacultyID is required');
        }

        $columns = implode(', ', array_keys($data));
        $placeholders = implode(', ', array_fill(0, count($data), '?'));

        $sql = "INSERT INTO {$this->table} ($columns) VALUES ($placeholders)";
        $stmt = $this->db->prepare($sql);
        $stmt->execute(array_values($data));

        return (string) $data['FacultyID'];
    }

    public function findAllWithDepartment(): array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM faculties f
            LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
            ORDER BY f.FacultyName
        ");
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function findByIdWithDepartment($facultyId): ?array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM faculties f
            LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
            WHERE f.FacultyID = ?
        ");
        $stmt->execute([$facultyId]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    public function findByDepartment(int $departmentId): array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM faculties f
            LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
            WHERE f.DepartmentID = ?
            ORDER BY f.FacultyName
        ");
        $stmt->execute([$departmentId]);
        return $stmt->fetchAll();
    }

    public function hasUserAccount($facultyId): bool {
        $stmt = $this->db->prepare("SELECT 1 FROM useraccounts WHERE FacultyID = ?");
        $stmt->execute([$facultyId]);
        return $stmt->fetch() !== false;
    }

    public function findById($facultyId): ?array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM faculties f
            LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
            WHERE f.FacultyID = ?
        ");
        $stmt->execute([$facultyId]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    public function findByEmployeeNumber($identifier): ?array {
        $stmt = $this->db->prepare("
            SELECT f.*, d.DepartmentName
            FROM faculties f
            LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
            WHERE f.ContactInformation = ? OR f.FacultyName LIKE ? OR f.FacultyID = ?
            LIMIT 1
        ");
        $stmt->execute([$identifier, '%' . $identifier . '%', $identifier]);
        $result = $stmt->fetch();
        return $result ?: null;
    }
}
