<?php
/**
 * Authentication Helper
 * Token-based authentication using database tokens
 */

class Auth {
    private static $currentUser = null;

    /**
     * Generate a secure token
     */
    public static function generateToken(): string {
        return bin2hex(random_bytes(32));
    }

    /**
     * Create and store a new token for user
     */
    public static function createToken(int $userId): string {
        $db = Database::getInstance()->getConnection();
        $token = self::generateToken();
        $expiresAt = date('Y-m-d H:i:s', strtotime('+' . TOKEN_EXPIRY_HOURS . ' hours'));

        // Delete old tokens for this user
        $stmt = $db->prepare("DELETE FROM AUTH_TOKENS WHERE UserID = ?");
        $stmt->execute([$userId]);

        // Insert new token
        $stmt = $db->prepare("INSERT INTO AUTH_TOKENS (UserID, Token, ExpiresAt) VALUES (?, ?, ?)");
        $stmt->execute([$userId, $token, $expiresAt]);

        return $token;
    }

    /**
     * Validate token and return user data
     */
    public static function validateToken(string $token): ?array {
        $db = Database::getInstance()->getConnection();
        
        $stmt = $db->prepare("
            SELECT u.UserID, u.Username, u.Role, u.FacultyID, u.IsActive,
                   f.FacultyName, f.DepartmentID
            FROM AUTH_TOKENS t
            JOIN USERACCOUNTS u ON t.UserID = u.UserID
            LEFT JOIN FACULTIES f ON u.FacultyID = f.FacultyID
            WHERE t.Token = ? AND t.ExpiresAt > NOW() AND u.IsActive = 1
        ");
        $stmt->execute([$token]);
        $user = $stmt->fetch();

        if ($user) {
            self::$currentUser = $user;
            return $user;
        }

        return null;
    }

    /**
     * Get token from Authorization header
     */
    public static function getBearerToken(): ?string {
        $headers = getallheaders();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $matches[1];
        }
        
        return null;
    }

    /**
     * Require authentication - exits if not authenticated
     */
    public static function requireAuth(): array {
        $token = self::getBearerToken();
        
        if (!$token) {
            Response::unauthorized('No token provided');
        }

        $user = self::validateToken($token);
        
        if (!$user) {
            Response::unauthorized('Invalid or expired token');
        }

        return $user;
    }

    /**
     * Require specific roles
     */
    public static function requireRole(array $allowedRoles): array {
        $user = self::requireAuth();
        
        if (!in_array($user['Role'], $allowedRoles)) {
            Response::forbidden('Insufficient permissions');
        }

        return $user;
    }

    /**
     * Get current authenticated user
     */
    public static function getCurrentUser(): ?array {
        return self::$currentUser;
    }

    /**
     * Hash password
     */
    public static function hashPassword(string $password): string {
        return password_hash($password, PASSWORD_DEFAULT);
    }

    /**
     * Verify password
     */
    public static function verifyPassword(string $password, string $hash): bool {
        return password_verify($password, $hash);
    }

    /**
     * Logout - delete token
     */
    public static function logout(string $token): bool {
        $db = Database::getInstance()->getConnection();
        $stmt = $db->prepare("DELETE FROM AUTH_TOKENS WHERE Token = ?");
        return $stmt->execute([$token]);
    }
}
