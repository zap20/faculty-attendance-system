<?php
/**
 * User Model
 * Handles USERACCOUNTS table operations
 */

class UserModel extends BaseModel {
    protected $table = 'useraccounts';
    protected $primaryKey = 'UserID';

    public function findByUsername(string $username): ?array {
        try {
            $stmt = $this->db->prepare("
                SELECT u.*, f.FacultyName,
                       COALESCE(f.DepartmentID, deptHead.DepartmentID) AS DepartmentID
                FROM useraccounts u
                LEFT JOIN faculties f ON u.FacultyID = f.FacultyID
                LEFT JOIN departments deptHead ON deptHead.DepartmentHeadUserID = u.UserID
                WHERE u.Username = ?
            ");
            $stmt->execute([$username]);
            $result = $stmt->fetch();
        } catch (PDOException $e) {
            $stmt = $this->db->prepare("
                SELECT u.*, f.FacultyName, f.DepartmentID
                FROM useraccounts u
                LEFT JOIN faculties f ON u.FacultyID = f.FacultyID
                WHERE u.Username = ?
            ");
            $stmt->execute([$username]);
            $result = $stmt->fetch();
        }

        return $result ?: null;
    }

    public function findByIdWithFaculty(int $userId): ?array {
        try {
            $stmt = $this->db->prepare("
                SELECT u.UserID, u.Username, u.Role, u.FacultyID, u.IsActive,
                       f.FacultyName,
                       COALESCE(f.DepartmentID, deptHead.DepartmentID) AS DepartmentID,
                       COALESCE(d.DepartmentName, deptHead.DepartmentName) AS DepartmentName
                FROM useraccounts u
                LEFT JOIN faculties f ON u.FacultyID = f.FacultyID
                LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
                LEFT JOIN departments deptHead ON deptHead.DepartmentHeadUserID = u.UserID
                WHERE u.UserID = ?
            ");
            $stmt->execute([$userId]);
            $result = $stmt->fetch();
        } catch (PDOException $e) {
            $stmt = $this->db->prepare("
                SELECT u.UserID, u.Username, u.Role, u.FacultyID, u.IsActive,
                       f.FacultyName, f.DepartmentID, d.DepartmentName
                FROM useraccounts u
                LEFT JOIN faculties f ON u.FacultyID = f.FacultyID
                LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
                WHERE u.UserID = ?
            ");
            $stmt->execute([$userId]);
            $result = $stmt->fetch();
        }

        return $result ?: null;
    }

    public function createUserAccount(array $data): int {
        $columns = implode(', ', array_keys($data));
        $placeholders = implode(', ', array_fill(0, count($data), '?'));

        $sql = "INSERT INTO {$this->table} ($columns) VALUES ($placeholders)";
        $stmt = $this->db->prepare($sql);
        $stmt->execute(array_values($data));

        return (int) $this->db->lastInsertId();
    }

    public function getAllWithFaculty(): array {
        $stmt = $this->db->prepare("
            SELECT u.UserID, u.Username, u.Role, u.FacultyID, u.IsActive, u.CreatedAt,
                   f.FacultyName, d.DepartmentName
            FROM useraccounts u
            LEFT JOIN faculties f ON u.FacultyID = f.FacultyID
            LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
            ORDER BY u.CreatedAt DESC
        ");
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function usernameExists(string $username, ?int $excludeId = null): bool {
        $sql = "SELECT 1 FROM useraccounts WHERE Username = ?";
        $params = [$username];
        
        if ($excludeId) {
            $sql .= " AND UserID != ?";
            $params[] = $excludeId;
        }
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetch() !== false;
    }
}
