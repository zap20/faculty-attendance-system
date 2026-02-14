<?php
/**
 * Device Model
 * Handles ATTENDANCEDEVICES table operations
 */

class DeviceModel extends BaseModel {
    protected $table = 'attendancedevices';
    protected $primaryKey = 'DeviceID';

    public function findAllWithRoom(): array {
        $stmt = $this->db->prepare("
            SELECT d.*, r.RoomName, r.Building
            FROM attendancedevices d
            LEFT JOIN rooms r ON d.RoomID = r.RoomID
            ORDER BY d.Location
        ");
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function findByIdWithRoom(int $deviceId): ?array {
        $stmt = $this->db->prepare("
            SELECT d.*, r.RoomName, r.Building
            FROM attendancedevices d
            LEFT JOIN rooms r ON d.RoomID = r.RoomID
            WHERE d.DeviceID = ?
        ");
        $stmt->execute([$deviceId]);
        $result = $stmt->fetch();
        return $result ?: null;
    }

    public function findByRoom(int $roomId): array {
        $stmt = $this->db->prepare("
            SELECT d.*, r.RoomName, r.Building
            FROM attendancedevices d
            LEFT JOIN rooms r ON d.RoomID = r.RoomID
            WHERE d.RoomID = ?
        ");
        $stmt->execute([$roomId]);
        return $stmt->fetchAll();
    }

    public function findActiveByRoom(int $roomId): array {
        $stmt = $this->db->prepare("
            SELECT d.*, r.RoomName, r.Building
            FROM attendancedevices d
            LEFT JOIN rooms r ON d.RoomID = r.RoomID
            WHERE d.RoomID = ? AND d.Status = 'Active'
        ");
        $stmt->execute([$roomId]);
        return $stmt->fetchAll();
    }

    public function isActive(int $deviceId): bool {
        $stmt = $this->db->prepare("SELECT Status FROM attendancedevices WHERE DeviceID = ?");
        $stmt->execute([$deviceId]);
        $result = $stmt->fetch();
        return $result && $result['Status'] === 'Active';
    }
}
