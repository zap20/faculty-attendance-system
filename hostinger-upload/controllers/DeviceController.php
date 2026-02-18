<?php
/**
 * Device Controller
 * CRUD operations for attendance devices
 */

class DeviceController {
    private $deviceModel;
    private $roomModel;

    public function __construct() {
        $this->deviceModel = new DeviceModel();
        $this->roomModel = new RoomModel();
    }

    /**
     * GET /api/devices
     */
    public function index(): void {
        Auth::requireAuth();
        
        $roomId = $_GET['roomId'] ?? null;
        
        if ($roomId) {
            $devices = $this->deviceModel->findByRoom((int) $roomId);
        } else {
            $devices = $this->deviceModel->findAllWithRoom();
        }

        Response::success($devices);
    }

    /**
     * GET /api/devices/{id}
     */
    public function show(int $id): void {
        Auth::requireAuth();
        
        $device = $this->deviceModel->findByIdWithRoom($id);
        if (!$device) {
            Response::notFound('Device not found');
        }

        Response::success($device);
    }

    /**
     * POST /api/devices
     */
    public function store(): void {
        Auth::requireRole(['Admin']);
        
        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('DeviceType', 'Device type')
                  ->required('Location', 'Location')
                  ->maxLength('DeviceType', 50, 'Device type')
                  ->maxLength('Location', 100, 'Location')
                  ->validate();

        // Verify room exists if provided
        if (!empty($data['RoomID']) && !$this->roomModel->exists($data['RoomID'])) {
            Response::error('Room not found', 404);
        }

        $deviceId = $this->deviceModel->create([
            'DeviceType' => $data['DeviceType'],
            'Location' => $data['Location'],
            'RoomID' => $data['RoomID'] ?? null,
            'Status' => $data['Status'] ?? 'Active'
        ]);

        $device = $this->deviceModel->findByIdWithRoom($deviceId);
        Response::success($device, 'Device created successfully', 201);
    }

    /**
     * PUT /api/devices/{id}
     */
    public function update(int $id): void {
        Auth::requireRole(['Admin']);
        
        $device = $this->deviceModel->findById($id);
        if (!$device) {
            Response::notFound('Device not found');
        }

        $data = json_decode(file_get_contents('php://input'), true);

        $validator = new Validator($data ?? []);
        $validator->required('DeviceType', 'Device type')
                  ->required('Location', 'Location')
                  ->required('Status', 'Status')
                  ->maxLength('DeviceType', 50, 'Device type')
                  ->maxLength('Location', 100, 'Location')
                  ->inArray('Status', ['Active', 'Inactive'], 'Status')
                  ->validate();

        // Verify room exists if provided
        if (!empty($data['RoomID']) && !$this->roomModel->exists($data['RoomID'])) {
            Response::error('Room not found', 404);
        }

        $this->deviceModel->update($id, [
            'DeviceType' => $data['DeviceType'],
            'Location' => $data['Location'],
            'RoomID' => $data['RoomID'] ?? null,
            'Status' => $data['Status']
        ]);

        $updatedDevice = $this->deviceModel->findByIdWithRoom($id);
        Response::success($updatedDevice, 'Device updated successfully');
    }

    /**
     * DELETE /api/devices/{id}
     */
    public function destroy(int $id): void {
        Auth::requireRole(['Admin']);
        
        $device = $this->deviceModel->findById($id);
        if (!$device) {
            Response::notFound('Device not found');
        }

        $this->deviceModel->delete($id);
        Response::success(null, 'Device deleted successfully');
    }
}
