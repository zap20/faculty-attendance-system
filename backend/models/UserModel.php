<?php
/**
 * User Model
 * Handles USERACCOUNTS table operations
 */

class UserModel extends BaseModel {
    protected $table = 'USERACCOUNTS';
    protected $primaryKey = 'UserID';

    public function findByUsername(string $username): ?array {
        $stmt = $this->db->prepare("
            SELECT u.*, f.FacultyName, f.DepartmentID
            FROM USERACCOUNTS u
            LEFT JOIN FACULTIES f ON u.FacultyID = f.FacultyID
            WHERE u.Username = ?
        ");
        $stmt->execute([$username]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    public function findByIdWithFaculty(int $userId): ?array {
        $stmt = $this->db->prepare("
            SELECT u.UserID, u.Username, u.Role, u.FacultyID, u.IsActive,
                   f.FacultyName, f.DepartmentID, d.DepartmentName
            FROM USERACCOUNTS u
            LEFT JOIN FACULTIES f ON u.FacultyID = f.FacultyID
            LEFT JOIN DEPARTMENTS d ON f.DepartmentID = d.DepartmentID
            WHERE u.UserID = ?
        ");
        $stmt->execute([$userId]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    public function getAllWithFaculty(): array {
        $stmt = $this->db->prepare("
            SELECT u.UserID, u.Username, u.Role, u.FacultyID, u.IsActive, u.CreatedAt,
                   f.FacultyName, d.DepartmentName
            FROM USERACCOUNTS u
            LEFT JOIN FACULTIES f ON u.FacultyID = f.FacultyID
            LEFT JOIN DEPARTMENTS d ON f.DepartmentID = d.DepartmentID
            ORDER BY u.CreatedAt DESC
        ");
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function usernameExists(string $username, int $excludeId = null): bool {
        $sql = "SELECT 1 FROM USERACCOUNTS WHERE Username = ?";
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
