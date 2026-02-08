<?php
/**
 * Room Controller
 * CRUD operations for rooms
 */

class RoomController {
    private $roomModel;

    public function __construct() {
        $this->roomModel = new RoomModel();
    }

    /**
     * GET /api/rooms
     */
    public function index(): void {
        Auth::requireAuth();
        
        $rooms = $this->roomModel->findAllWithDeviceCount();
        Response::success($rooms);
    }

    /**
     * GET /api/rooms/{id}
     */
    public function show(int $id): void {
        Auth::requireAuth();
        
        $room = $this->roomModel->findById($id);
        if (!$room) {
            Response::notFound('Room not found');
        }

        Response::success($room);
    }

    /**
     * POST /api/rooms
     */
    public function store(): void {
        Auth::requireRole(['Admin']);
        
        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('RoomName', 'Room name')
                  ->required('Building', 'Building')
                  ->maxLength('RoomName', 50, 'Room name')
                  ->maxLength('Building', 100, 'Building')
                  ->validate();

        $roomId = $this->roomModel->create([
            'RoomName' => $data['RoomName'],
            'Building' => $data['Building'],
            'Capacity' => $data['Capacity'] ?? null
        ]);

        $room = $this->roomModel->findById($roomId);
        Response::success($room, 'Room created successfully', 201);
    }

    /**
     * PUT /api/rooms/{id}
     */
    public function update(int $id): void {
        Auth::requireRole(['Admin']);
        
        $room = $this->roomModel->findById($id);
        if (!$room) {
            Response::notFound('Room not found');
        }

        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('RoomName', 'Room name')
                  ->required('Building', 'Building')
                  ->maxLength('RoomName', 50, 'Room name')
                  ->maxLength('Building', 100, 'Building')
                  ->validate();

        $this->roomModel->update($id, [
            'RoomName' => $data['RoomName'],
            'Building' => $data['Building'],
            'Capacity' => $data['Capacity'] ?? null
        ]);

        $updatedRoom = $this->roomModel->findById($id);
        Response::success($updatedRoom, 'Room updated successfully');
    }

    /**
     * DELETE /api/rooms/{id}
     */
    public function destroy(int $id): void {
        Auth::requireRole(['Admin']);
        
        $room = $this->roomModel->findById($id);
        if (!$room) {
            Response::notFound('Room not found');
        }

        // Check for related records
        if ($this->roomModel->hasSchedules($id)) {
            Response::error('Cannot delete room with associated schedules', 400);
        }
        if ($this->roomModel->hasDevices($id)) {
            Response::error('Cannot delete room with associated devices', 400);
        }

        $this->roomModel->delete($id);
        Response::success(null, 'Room deleted successfully');
    }
}
