<?php
/**
 * Room Model
 * Handles ROOMS table operations
 */

class RoomModel extends BaseModel {
    protected $table = 'ROOMS';
    protected $primaryKey = 'RoomID';

    public function findAllWithDeviceCount(): array {
        $stmt = $this->db->prepare("
            SELECT r.*, COUNT(d.DeviceID) as DeviceCount
            FROM ROOMS r
            LEFT JOIN ATTENDANCEDEVICES d ON r.RoomID = d.RoomID
            GROUP BY r.RoomID
            ORDER BY r.Building, r.RoomName
        ");
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function hasSchedules(int $roomId): bool {
        $stmt = $this->db->prepare("SELECT 1 FROM SCHEDULES WHERE RoomID = ? LIMIT 1");
        $stmt->execute([$roomId]);
        return $stmt->fetch() !== false;
    }

    public function hasDevices(int $roomId): bool {
        $stmt = $this->db->prepare("SELECT 1 FROM ATTENDANCEDEVICES WHERE RoomID = ? LIMIT 1");
        $stmt->execute([$roomId]);
        return $stmt->fetch() !== false;
    }
}
