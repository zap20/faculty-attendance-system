import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/offline/repository_provider.dart';
import '../../models/attendance_model.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/sync_status_widget.dart';
import '../shared/reports_screen.dart';
import '../../widgets/auto_refresh_mixin.dart';

class OfficerDashboardScreen extends StatefulWidget {
  const OfficerDashboardScreen({super.key});

  @override
  State<OfficerDashboardScreen> createState() => _OfficerDashboardScreenState();
}

class _OfficerDashboardScreenState extends State<OfficerDashboardScreen> {
  String _currentScreen = 'officer_scanner';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (!kIsWeb) const SyncStatusWidget(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                user?.username ?? 'Officer',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: AppDrawer(
        currentScreen: _currentScreen,
        onItemSelected: _handleDrawerSelection,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentScreen) {
      case 'officer_scanner':
        return const QRScannerView();
      case 'officer_today':
        return const TodayAttendanceView();
      case 'officer_reports':
        return const ReportsScreen();
      default:
        return const QRScannerView();
    }
  }

  void _handleDrawerSelection(String selection) {
    if (selection == 'logout') {
      context.read<AuthProvider>().logout();
      return;
    }
    
    Navigator.pop(context); // Close drawer
    setState(() {
      _currentScreen = selection;
    });
  }

  String _getScreenTitle() {
    switch (_currentScreen) {
      case 'officer_scanner':
        return 'QR Scanner';
      case 'officer_today':
        return 'Today\'s Attendance';
      case 'officer_reports':
        return 'Reports';
      case 'profile':
        return 'Profile';
      case 'settings':
        return 'Settings';
      default:
        return 'QR Scanner';
    }
  }
}

class QRScannerView extends StatefulWidget {
  const QRScannerView({super.key});

  @override
  State<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  String? _lastScannedCode;
  Map<String, dynamic>? _lastResult;
  bool _scannerActive = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _processQRCode(String code) async {
    if (_isProcessing || code == _lastScannedCode) return;
    
    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    try {
      // Get current day of week for display
      final now = DateTime.now();
      final dayMap = {
        1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 
        5: 'Friday', 6: 'Saturday', 7: 'Sunday'
      };
      final currentDayOfWeek = dayMap[now.weekday] ?? '';
      final currentDate = now.toIso8601String().split('T')[0];
      
      // Use offline-first repository for QR attendance
      final repo = RepositoryProvider();
      final result = await repo.smartExecute(
        (r) => r.recordByQR(qrCode: code),
        operationName: 'QRAttendance',
      );

      final bool inserted = result['success'] == true;
      
      setState(() {
        _lastResult = {
          'success': inserted,
          'message': result['message'] ?? 'Attendance recorded successfully',
          'data': result['data'],
          'scan_info': {
            'day_of_week': currentDayOfWeek,
            'date': currentDate,
            'time': now.toIso8601String(),
          },
        };
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Attendance recorded!'),
            backgroundColor: inserted ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastResult = {
          'success': false,
          'message': e.toString(),
        };
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _lastScannedCode = null);
        }
      });
    }
  }

  void _onManualEntry() {
    showDialog(
      context: context,
      builder: (context) => _ManualEntryDialog(
        onSubmit: (code) => _processQRCode(code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebScanner();
    }
    return _buildMobileScanner();
  }

  Widget _buildWebScanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 120,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              const Text(
                'QR Scanner',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera scanning is available on mobile devices.\nUse manual entry for web or scan with a mobile device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _onManualEntry,
                icon: const Icon(Icons.keyboard),
                label: const Text('Manual Entry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 48),
              if (_lastResult != null) _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileScanner() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              if (_scannerActive)
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _processQRCode(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                )
              else
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      'Scanner Paused',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      heroTag: 'flash',
                      onPressed: () => _controller?.toggleTorch(),
                      child: const Icon(Icons.flash_on),
                    ),
                    FloatingActionButton(
                      heroTag: 'pause',
                      onPressed: () {
                        setState(() => _scannerActive = !_scannerActive);
                        if (_scannerActive) {
                          _controller?.start();
                        } else {
                          _controller?.stop();
                        }
                      },
                      child: Icon(_scannerActive ? Icons.pause : Icons.play_arrow),
                    ),
                    FloatingActionButton(
                      heroTag: 'switch',
                      onPressed: () => _controller?.switchCamera(),
                      child: const Icon(Icons.cameraswitch),
                    ),
                    FloatingActionButton(
                      heroTag: 'manual',
                      onPressed: _onManualEntry,
                      child: const Icon(Icons.keyboard),
                    ),
                  ],
                ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: _lastResult != null
                ? _buildResultCard()
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Scan a faculty QR code to record attendance',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    final success = _lastResult!['success'] as bool;
    final message = _lastResult!['message'] as String;
    final data = _lastResult!['data'] as Map<String, dynamic>?;
    final scanInfo = _lastResult!['scan_info'] as Map<String, dynamic>?;

    final bool isNoSchedule = data != null && data['action'] == 'no_schedule';

    return Card(
      color: isNoSchedule
          ? Colors.orange[50]
          : (success ? Colors.green[50] : Colors.red[50]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isNoSchedule
                      ? Icons.warning
                      : (success ? Icons.check_circle : Icons.error),
                  color: isNoSchedule
                      ? Colors.orange
                      : (success ? Colors.green : Colors.red),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNoSchedule ? 'Warning' : (success ? 'Success' : 'Error'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isNoSchedule ? Colors.orange[800] : (success ? Colors.green[800] : Colors.red[800]),
                        ),
                      ),
                      // Display DayOfWeek prominently here
                      if (data != null && data['day_of_week'] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isNoSchedule
                                ? Colors.orange[100]
                                : (success ? Colors.green[100] : Colors.red[100]),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isNoSchedule
                                  ? Colors.orange[300]!
                                  : (success ? Colors.green[300]! : Colors.red[300]!),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event,
                                size: 14,
                                color: isNoSchedule
                                    ? Colors.orange[700]
                                    : (success ? Colors.green[700] : Colors.red[700]),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${data['day_of_week']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isNoSchedule
                                      ? Colors.orange[700]
                                      : (success ? Colors.green[700] : Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Always show day from scanInfo if data doesn't have day_of_week
                      if (data == null || data['day_of_week'] == null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isNoSchedule
                                ? Colors.orange[100]
                                : (success ? Colors.green[100] : Colors.red[100]),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isNoSchedule
                                  ? Colors.orange[300]!
                                  : (success ? Colors.green[300]! : Colors.red[300]!),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event,
                                size: 14,
                                color: isNoSchedule
                                    ? Colors.orange[700]
                                    : (success ? Colors.green[700] : Colors.red[700]),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                scanInfo?['day_of_week'] ?? 'Unknown Day',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isNoSchedule
                                      ? Colors.orange[700]
                                      : (success ? Colors.green[700] : Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: 14)),
            
            // Show scan information (day, date, time)
            if (scanInfo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scanned on ${scanInfo['day_of_week']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        Text(
                          '${scanInfo['date']} at ${DateTime.parse(scanInfo['time']).toIso8601String().split('T')[1].substring(0, 5)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            if (data != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              if (data['faculty_name'] != null)
                Text('Faculty: ${data['faculty_name']}', style: const TextStyle(fontWeight: FontWeight.w500)),
              if (data['subject_name'] != null)
                Text('Subject: ${data['subject_name']}'),
              if (data['time_in'] != null)
                Text('Time In: ${data['time_in']}'),
              if (data['time_out'] != null)
                Text('Time Out: ${data['time_out']}'),
              if (data['status'] != null)
                Text('Status: ${data['status']}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManualEntryDialog extends StatefulWidget {
  final Function(String) onSubmit;

  const _ManualEntryDialog({required this.onSubmit});

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual Entry'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Faculty ID or QR Code',
          hintText: 'Enter faculty ID',
        ),
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  void _submit() {
    if (_controller.text.isNotEmpty) {
      Navigator.pop(context);
      widget.onSubmit(_controller.text);
    }
  }
}

class TodayAttendanceView extends StatefulWidget {
  const TodayAttendanceView({super.key});

  @override
  State<TodayAttendanceView> createState() => _TodayAttendanceViewState();
}

class _TodayAttendanceViewState extends State<TodayAttendanceView> with AutoRefreshMixin {
  Map<String, List<AttendanceModel>> _weeklyAttendance = {};
  final Map<int, TransformationController> _zoomControllers = {};
  String? _selectedRoom;
  String? _selectedBuilding;
  
  @override
  void initState() {
    super.initState();
    _loadWeeklyAttendance();
    startAutoRefresh(_loadWeeklyAttendance);
  }

  @override
  void dispose() {
    stopAutoRefresh();
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    _zoomControllers.clear();
    super.dispose();
  }

  void _applyZoom(int roomId, double factor) {
    final controller = _zoomControllers[roomId];
    if (controller == null) return;

    final currentScale = controller.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(0.6, 3.0);
    final delta = nextScale / currentScale;
    controller.value = controller.value.clone()..scale(delta);
  }

  Future<void> _loadWeeklyAttendance() async {
    final now = DateTime.now();
    final startOfWeek = _getStartOfWeek(now);
    
    final Map<String, List<AttendanceModel>> weeklyAttendance = {};
    
    // Fetch attendance for each day of the current week
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      
      try {
        final repo = RepositoryProvider();
        final attendances = await repo.smartExecute(
          (r) => r.getAttendanceHistory(from: dateStr, to: dateStr),
          operationName: 'WeeklyAttendance',
        );
        weeklyAttendance[dateStr] = attendances;
      } catch (e) {
        weeklyAttendance[dateStr] = [];
      }
    }
    
    setState(() {
      _weeklyAttendance = weeklyAttendance;
    });
  }

  DateTime _getStartOfWeek(DateTime date) {
    // Assuming week starts on Monday
    final dayOfWeek = date.weekday;
    return date.subtract(Duration(days: dayOfWeek - 1));
  }

  AttendanceModel? _getAttendanceForSchedule(String facultyId, String date, String courseCode, String expectedDayOfWeek, int? scheduleId) {
    final attendances = _weeklyAttendance[date] ?? [];
    
    try {
      final matched = attendances.firstWhere(
        (attendance) {
          // Prioritize ScheduleID matching since it's the primary key
          if (scheduleId != null && attendance.scheduleId == scheduleId) {
            final facultyMatch = attendance.facultyId == facultyId;
            final dayMatch = attendance.dayOfWeek == expectedDayOfWeek;
            return facultyMatch && dayMatch;
          }
          
          // Fallback to CourseCode matching if ScheduleID is not available
          if (scheduleId == null) {
            final facultyMatch = attendance.facultyId == facultyId;
            final courseMatch = attendance.courseCode == courseCode;
            final dayMatch = attendance.dayOfWeek == expectedDayOfWeek;
            return facultyMatch && courseMatch && dayMatch;
          }
          
          return false;
        },
      );
      
      return matched;
    } catch (e) {
      return null; // No attendance found
    }
  }

  String _getDayOfWeekFromDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final dayMap = {
        1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 
        5: 'Friday', 6: 'Saturday', 7: 'Sunday'
      };
      return dayMap[date.weekday] ?? '';
    } catch (e) {
      return '';
    }
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return 'N/A';
    
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {
      return time;
    }
    return time;
  }

  Future<List<dynamic>> _safeLoadSchedulesAndRooms() async {
    try {
      return await Future.wait([
        DataService.getSchedules(),
        DataService.getRooms(),
      ]);
    } catch (e) {
      debugPrint('[OfficerDashboard] Failed to load schedules/rooms: $e');
      return [<dynamic>[], <dynamic>[]];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _safeLoadSchedulesAndRooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => (context as Element).markNeedsBuild(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final schedules = snapshot.data![0] as List;
        final rooms = snapshot.data![1] as List;
        final today = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
        final isMobile = !kIsWeb && MediaQuery.of(context).size.width < 600;
        final headerPadding = EdgeInsets.all(isMobile ? 12 : 16);

        // Extract unique buildings and room names for filters
        final buildings = <String>{};
        final roomNames = <String>{};
        for (var room in rooms) {
          if (room.building != null && room.building.toString().isNotEmpty) {
            buildings.add(room.building.toString());
          }
          if (room.roomName != null && room.roomName.toString().isNotEmpty) {
            roomNames.add(room.roomName.toString());
          }
        }

        // Group schedules by room
        final Map<int, Map<String, dynamic>> schedulesByRoom = {};
        for (var room in rooms) {
          // Apply building filter
          if (_selectedBuilding != null && room.building.toString() != _selectedBuilding) continue;
          // Apply room filter
          if (_selectedRoom != null && room.roomName.toString() != _selectedRoom) continue;

          schedulesByRoom[room.roomId] = {
            'room': room,
            'Monday': <dynamic>[],
            'Tuesday': <dynamic>[],
            'Wednesday': <dynamic>[],
            'Thursday': <dynamic>[],
            'Friday': <dynamic>[],
            'Saturday': <dynamic>[],
          };
        }
        
        for (var schedule in schedules) {
          if (schedulesByRoom.containsKey(schedule.roomId)) {
            final day = schedule.dayOfWeek;
            if (schedulesByRoom[schedule.roomId]!.containsKey(day)) {
              schedulesByRoom[schedule.roomId]![day]!.add(schedule);
            }
          }
        }

        // Sort schedules by start time within each day
        for (var roomData in schedulesByRoom.values) {
          for (var day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']) {
            final dayList = roomData[day] as List<dynamic>;
            dayList.sort((a, b) => a.startTime.compareTo(b.startTime));
          }
        }

        return Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: headerPadding,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                children: [
                  Text(today, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Weekly Schedule View — Tap a schedule to edit',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            // Filter bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 18),
                  const SizedBox(width: 8),
                  // Building filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedBuilding,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Building',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Buildings')),
                        ...buildings.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() {
                        _selectedBuilding = v;
                        _selectedRoom = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Room filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRoom,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Rooms')),
                        ...rooms
                            .where((r) => _selectedBuilding == null || r.building.toString() == _selectedBuilding)
                            .map((r) => DropdownMenuItem(value: r.roomName.toString(), child: Text(r.roomName.toString(), overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _selectedRoom = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedBuilding != null || _selectedRoom != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear filters',
                      onPressed: () => setState(() {
                        _selectedBuilding = null;
                        _selectedRoom = null;
                      }),
                    ),
                ],
              ),
            ),
            Expanded(
              child: schedules.isEmpty
                  ? _buildEmptyState()
                  : _buildScheduleView(context, schedulesByRoom),
            ),
          ],
        );
      },
    );
  }

  Widget _buildZoomableScheduleGrid(BuildContext context, int roomId, Map<String, dynamic> roomData) {
    final isMobile = !kIsWeb && MediaQuery.of(context).size.width < 600;
    final initialScale = isMobile ? 0.85 : 1.0;
    final viewportWidth = MediaQuery.of(context).size.width;
    const dayCount = 6;
    const timeColWidth = 60.0;
    const gapWidth = 4.0;
    final minTableWidth = timeColWidth + gapWidth + (dayCount * 200.0);
    final tableWidth = math.max(viewportWidth, minTableWidth);

    const cellHeight = 30.0;
    const rowGap = 2.0;
    final timeSlots = _generateTimeSlots();
    final gridHeight = (timeSlots.length * (cellHeight + rowGap)) - rowGap;
    const headerHeightEstimate = 44.0;
    final viewerHeight = gridHeight + headerHeightEstimate;
    final controller = _zoomControllers.putIfAbsent(
      roomId,
      () => TransformationController(Matrix4.identity()..scale(initialScale)),
    );

    return SizedBox(
      width: double.infinity,
      height: viewerHeight,
      child: ClipRect(
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: controller,
              constrained: false,
              alignment: Alignment.topLeft,
              panEnabled: true,
              scaleEnabled: true,
              minScale: 0.6,
              maxScale: 3.0,
              boundaryMargin: const EdgeInsets.all(120),
              child: SizedBox(
                width: tableWidth,
                child: _buildTimeGridSchedule(roomData),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.white.withOpacity(0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: () => _applyZoom(roomId, 1.2),
                      icon: const Icon(Icons.add),
                      tooltip: 'Zoom in',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.white.withOpacity(0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: () => _applyZoom(roomId, 1 / 1.2),
                      icon: const Icon(Icons.remove),
                      tooltip: 'Zoom out',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No schedules found'),
        ],
      ),
    );
  }

  Widget _buildScheduleView(BuildContext context, Map<int, Map<String, dynamic>> schedulesByRoom) {
    final isMobile = !kIsWeb && MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room cards with time-based schedule layout
          ...schedulesByRoom.entries.map((entry) {
            final roomData = entry.value;
            final room = roomData['room'];
            final hasSchedules = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
                .any((day) => (roomData[day] as List<dynamic>).isNotEmpty);
            
            if (!hasSchedules) return const SizedBox.shrink();
            
            return Card(
              margin: EdgeInsets.only(bottom: isMobile ? 10 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.room, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${room?.roomName ?? "Unknown"} - ${room?.building ?? ""}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Capacity: ${room?.capacity ?? "-"}',
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(Icons.room, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${room?.roomName ?? "Unknown"} - ${room?.building ?? ""}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('Capacity: ${room?.capacity ?? "-"}'),
                            ],
                          ),
                  ),
                  // Time-based schedule grid
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 8 : 16),
                    child: _buildZoomableScheduleGrid(context, entry.key, roomData),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeGridSchedule(Map<String, dynamic> roomData) {
    final timeSlots = _generateTimeSlots();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    // Pre-process schedules to identify merged cells
    final Map<String, Map<String, dynamic>> mergedSchedules = {};
    
    for (final day in days) {
      mergedSchedules[day] = {};
      final daySchedules = roomData[day] as List<dynamic>;
      
      for (final schedule in daySchedules) {
        String startTime, endTime, subjectName, facultyName, courseCode, roomName;
        
        if (schedule is Map<String, dynamic>) {
          startTime = schedule['StartTime'] ?? schedule['startTime'] ?? schedule['start_time'] ?? '';
          endTime = schedule['EndTime'] ?? schedule['endTime'] ?? schedule['end_time'] ?? '';
          subjectName = schedule['SubjectName'] ?? schedule['subjectName'] ?? schedule['subject_name'] ?? '';
          facultyName = schedule['FacultyName'] ?? schedule['facultyName'] ?? schedule['faculty_name'] ?? '';
          courseCode = schedule['CourseCode'] ?? schedule['courseCode'] ?? schedule['course_code'] ?? '';
          roomName = schedule['RoomName'] ?? schedule['roomName'] ?? schedule['room_name'] ?? '';
        } else {
          startTime = schedule.startTime ?? '';
          endTime = schedule.endTime ?? '';
          subjectName = schedule.subjectName ?? '';
          facultyName = schedule.facultyName ?? '';
          courseCode = schedule.courseCode ?? '';
          roomName = schedule.roomName ?? '';
        }
        
        // Create unique key for merging
        final key = '$subjectName-$facultyName-$startTime-$endTime';
        final dayMap = mergedSchedules[day]!;
        if (!dayMap.containsKey(key)) {
          dayMap[key] = {
            'schedule': schedule,
            'startTime': startTime,
            'endTime': endTime,
            'subjectName': subjectName,
            'facultyName': facultyName,
            'courseCode': courseCode,
            'roomName': roomName, // Add roomName to the data
          };
        }
      }
    }
    
    return Column(
      children: [
        // Header row with day columns only (no time column header)
        Row(
          children: [
            // Empty space for time column
            const SizedBox(width: 60),
            const SizedBox(width: 4),
            // Day column headers
            ...days.map((day) => Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  day.substring(0, 3), // Mon, Tue, etc.
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )),
          ],
        ),
        const SizedBox(height: 4),
        // Build continuous grid based on actual schedules
        _buildMainContent(mergedSchedules, timeSlots, days),
      ],
    );
  }

  Widget _buildMainContent(Map<String, Map<String, dynamic>> mergedSchedules, List<String> timeSlots, List<String> days) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Time table
        SizedBox(
          width: 60,
          child: _buildTimeTable(timeSlots, mergedSchedules, days),
        ),
        const SizedBox(width: 4),
        // Right side: Schedule table
        Expanded(
          child: _buildScheduleTable(mergedSchedules, timeSlots, days),
        ),
      ],
    );
  }

  Widget _buildTimeTable(List<String> timeSlots, Map<String, Map<String, dynamic>> mergedSchedules, List<String> days) {
    return Column(
      children: timeSlots.asMap().entries.map((entry) {
        final index = entry.key;
        final timeSlot = entry.value;
        return _buildTimeCell(
          timeSlot,
          height: 30,
          addBottomGap: index != timeSlots.length - 1,
        );
      }).toList(),
    );
  }

  Widget _buildTimeCell(String timeSlot, {required double height, bool addBottomGap = true}) {
    return Container(
      margin: EdgeInsets.only(bottom: addBottomGap ? 2 : 0),
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          timeSlot,
          style: TextStyle(
            fontSize: 8,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildScheduleTable(Map<String, Map<String, dynamic>> mergedSchedules, List<String> timeSlots, List<String> days) {
    const cellHeight = 30.0;
    const rowGap = 2.0;
    final gridHeight = (timeSlots.length * (cellHeight + rowGap)) - rowGap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = constraints.maxWidth / days.length;

        final scheduleBlocks = <Widget>[];
        for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
          final day = days[dayIndex];
          final daySchedules = mergedSchedules[day] ?? {};

          for (final entry in daySchedules.entries) {
            final scheduleData = entry.value;
            final startTime = scheduleData['startTime'] as String;
            final endTime = scheduleData['endTime'] as String;

            final startMinutes = _parseHour(startTime) * 60 + _parseMinute(startTime);
            final endMinutes = _parseHour(endTime) * 60 + _parseMinute(endTime);
            final baseMinutes = 7 * 60;

            int startIndex = ((startMinutes - baseMinutes) / 30).floor();
            int endIndex = ((endMinutes - baseMinutes) / 30).ceil();
            if (endIndex <= startIndex) endIndex = startIndex + 1;
            startIndex = startIndex.clamp(0, timeSlots.length - 1);
            endIndex = endIndex.clamp(1, timeSlots.length);

            final span = endIndex - startIndex;
            final top = startIndex * (cellHeight + rowGap);
            final height = (span * cellHeight) + ((span - 1) * rowGap);

            scheduleBlocks.add(Positioned(
              top: top,
              left: dayIndex * dayWidth,
              width: dayWidth,
              height: height,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: _buildScheduleBlock(scheduleData, day),
              ),
            ));
          }
        }

        return SizedBox(
          height: gridHeight,
          child: Stack(
            children: [
              Column(
                children: List.generate(timeSlots.length, (index) {
                  final isLast = index == timeSlots.length - 1;
                  return Container(
                    margin: EdgeInsets.only(bottom: isLast ? 0 : rowGap),
                    height: cellHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...days.map((_) => Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 2),
                                height: cellHeight,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade200, width: 0.5),
                                ),
                              ),
                            )),
                      ],
                    ),
                  );
                }),
              ),
              ...scheduleBlocks,
            ],
          ),
        );
      },
    );
  }

  void _showEditAttendanceDialog(Map<String, dynamic> scheduleData, String dayOfWeek) {
    final schedule = scheduleData['schedule'];
    String facultyId = '';
    String facultyName = scheduleData['facultyName'] as String? ?? '';
    String courseCode = scheduleData['courseCode'] as String? ?? '';
    String subjectName = scheduleData['subjectName'] as String? ?? '';
    int? scheduleId;

    if (schedule is Map<String, dynamic>) {
      facultyId = schedule['FacultyID']?.toString() ?? schedule['facultyId']?.toString() ?? '';
      scheduleId = schedule['ScheduleID'] ?? schedule['scheduleId'];
    } else if (schedule != null) {
      facultyId = schedule.facultyId?.toString() ?? '';
      scheduleId = schedule.scheduleId;
    }

    final now = DateTime.now();
    final startOfWeek = _getStartOfWeek(now);
    final dayMap = {'Monday': 0, 'Tuesday': 1, 'Wednesday': 2, 'Thursday': 3, 'Friday': 4, 'Saturday': 5, 'Sunday': 6};
    final dayOffset = dayMap[dayOfWeek] ?? 0;
    final targetDate = startOfWeek.add(Duration(days: dayOffset));
    final dateStr = targetDate.toIso8601String().split('T')[0];

    final attendance = _getAttendanceForSchedule(facultyId, dateStr, courseCode, dayOfWeek, scheduleId);
    final hasTimeIn = attendance?.timeIn != null;
    final hasTimeOut = attendance?.timeOut != null;

    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Attendance'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Faculty: $facultyName', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Subject: $subjectName ($courseCode)'),
              Text('Day: $dayOfWeek'),
              Text('Date: $dateStr'),
              Text('Time: ${scheduleData['startTime']} - ${scheduleData['endTime']}'),
              const SizedBox(height: 8),
              if (attendance != null) ...[
                Text('Status: ${attendance.attendanceStatus}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                Text('Time In: ${_formatTime(attendance.timeIn)}'),
                Text('Time Out: ${_formatTime(attendance.timeOut)}'),
              ] else
                const Text('No attendance record yet', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          // Mark Absent
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.person_off, size: 16),
            label: const Text('Mark Absent'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateAttendanceStatus(
                action: 'absent',
                facultyId: facultyId,
                date: dateStr,
                scheduleId: scheduleId,
                remarks: remarksController.text.isNotEmpty ? remarksController.text : null,
              );
            },
          ),
          // Early Out (only if has TimeIn and no TimeOut)
          if (hasTimeIn && !hasTimeOut)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              icon: const Icon(Icons.exit_to_app, size: 16),
              label: const Text('Early Out'),
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateAttendanceStatus(
                  action: 'early_out',
                  facultyId: facultyId,
                  date: dateStr,
                  scheduleId: scheduleId,
                  remarks: remarksController.text.isNotEmpty ? remarksController.text : null,
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _updateAttendanceStatus({
    required String action,
    required String facultyId,
    required String date,
    int? scheduleId,
    String? remarks,
  }) async {
    try {
      final body = <String, dynamic>{
        'action': action,
        'facultyId': facultyId,
        'date': date,
      };
      if (scheduleId != null) body['scheduleId'] = scheduleId;
      if (remarks != null) body['remarks'] = remarks;

      final repo = RepositoryProvider();
      await repo.smartExecute(
        (r) => r.updateAttendanceStatus(
          action: action,
          facultyId: facultyId,
          date: date,
          scheduleId: scheduleId,
          remarks: remarks,
        ),
        operationName: 'UpdateStatus',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'absent' ? 'Marked as absent' : 'Early out recorded'),
          backgroundColor: Colors.green,
        ),
      );
      // Reload attendance data
      _loadWeeklyAttendance();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildScheduleBlock(Map<String, dynamic> scheduleData, String dayOfWeek) {
    final startTime = scheduleData['startTime'] as String;
    final endTime = scheduleData['endTime'] as String;
    final scheduleStartMinutes = _parseHour(startTime) * 60 + _parseMinute(startTime);
    final scheduleEndMinutes = _parseHour(endTime) * 60 + _parseMinute(endTime);

    return GestureDetector(
      onTap: () => _showEditAttendanceDialog(scheduleData, dayOfWeek),
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.blue.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (scheduleData['courseCode'] as String).length > 8
                        ? '${(scheduleData['courseCode'] as String).substring(0, 8)}...'
                        : scheduleData['courseCode'] as String,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$startTime - $endTime',
                    style: TextStyle(
                      fontSize: 6,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    scheduleData['facultyName'] as String,
                    style: TextStyle(
                      fontSize: 6,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final schedule = scheduleData['schedule'];
                      String facultyId = '';
                      String courseCode = scheduleData['courseCode'] as String;
                      int? scheduleId;

                      if (schedule is Map<String, dynamic>) {
                        facultyId = schedule['FacultyID']?.toString() ?? schedule['facultyId']?.toString() ?? '';
                        scheduleId = schedule['ScheduleID'] ?? schedule['scheduleId'];
                      } else {
                        facultyId = schedule?.facultyId?.toString() ?? '';
                        scheduleId = schedule?.scheduleId;
                      }

                      final now = DateTime.now();
                      final startOfWeek = _getStartOfWeek(now);
                      final dayMap = {
                        'Monday': 0,
                        'Tuesday': 1,
                        'Wednesday': 2,
                        'Thursday': 3,
                        'Friday': 4,
                        'Saturday': 5,
                        'Sunday': 6,
                      };
                      final dayOffset = dayMap[dayOfWeek] ?? 0;
                      final targetDate = startOfWeek.add(Duration(days: dayOffset));
                      final dateStr = targetDate.toIso8601String().split('T')[0];

                      final attendance = _getAttendanceForSchedule(facultyId, dateStr, courseCode, dayOfWeek, scheduleId);

                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              _formatTime(attendance?.timeIn),
                              style: TextStyle(
                                fontSize: 5,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Text(
                              _formatTime(attendance?.timeOut),
                              style: TextStyle(
                                fontSize: 5,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final schedule = scheduleData['schedule'];
                      String facultyId = '';
                      String courseCode = scheduleData['courseCode'] as String;
                      int? scheduleId;

                      if (schedule is Map<String, dynamic>) {
                        facultyId = schedule['FacultyID']?.toString() ?? schedule['facultyId']?.toString() ?? '';
                        scheduleId = schedule['ScheduleID'] ?? schedule['scheduleId'];
                      } else {
                        facultyId = schedule?.facultyId?.toString() ?? '';
                        scheduleId = schedule?.scheduleId;
                      }

                      final now = DateTime.now();
                      final startOfWeek = _getStartOfWeek(now);
                      final dayMap = {
                        'Monday': 0,
                        'Tuesday': 1,
                        'Wednesday': 2,
                        'Thursday': 3,
                        'Friday': 4,
                        'Saturday': 5,
                        'Sunday': 6,
                      };
                      final dayOffset = dayMap[dayOfWeek] ?? 0;
                      final targetDate = startOfWeek.add(Duration(days: dayOffset));
                      final dateStr = targetDate.toIso8601String().split('T')[0];
                      final todayStr = now.toIso8601String().split('T')[0];
                      final isToday = dateStr == todayStr;
                      final startOfToday = DateTime(now.year, now.month, now.day);

                      final attendance = _getAttendanceForSchedule(facultyId, dateStr, courseCode, dayOfWeek, scheduleId);

                      int? timeInMinutes;
                      if (attendance?.timeIn != null) {
                        timeInMinutes = _parseHour(attendance!.timeIn!) * 60 + _parseMinute(attendance.timeIn!);
                      }
                      int? timeOutMinutes;
                      if (attendance?.timeOut != null) {
                        timeOutMinutes = _parseHour(attendance!.timeOut!) * 60 + _parseMinute(attendance.timeOut!);
                      }

                      final hasTimeIn = attendance != null && timeInMinutes != null;
                      final timeInMin = timeInMinutes ?? -1;
                      final isLate = hasTimeIn && timeInMin >= (scheduleStartMinutes + 30);
                      final isPresent = hasTimeIn && !isLate;

                      final hasAnyScan = attendance != null && (attendance.timeIn != null || attendance.timeOut != null);
                      final nowMinutes = now.hour * 60 + now.minute;
                      final dayPassed = targetDate.isBefore(startOfToday);
                      final scheduleEndedToday = isToday && nowMinutes > scheduleEndMinutes;
                      final isAbsent = !hasAnyScan && (dayPassed || scheduleEndedToday);

                      bool isEarlyOut = false;
                      bool showEarlyNA = false;
                      if (isAbsent) {
                        isEarlyOut = false;
                        showEarlyNA = true;
                      } else if (attendance != null) {
                        if (timeOutMinutes != null) {
                          isEarlyOut = timeOutMinutes <= (scheduleEndMinutes - 30);
                          showEarlyNA = !isEarlyOut;
                        } else {
                          if (isToday) {
                            if (nowMinutes > scheduleEndMinutes) {
                              isEarlyOut = hasTimeIn;
                              showEarlyNA = false;
                            } else {
                              isEarlyOut = false;
                              showEarlyNA = true;
                            }
                          } else {
                            isEarlyOut = false;
                            showEarlyNA = true;
                          }
                        }
                      } else {
                        showEarlyNA = true;
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAbsent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Text(
                                'ABSENT',
                                style: TextStyle(
                                  fontSize: 5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            )
                          else if (isLate)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Text(
                                'LATE',
                                style: TextStyle(
                                  fontSize: 5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            )
                          else if (isPresent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Text(
                                'PRESENT',
                                style: TextStyle(
                                  fontSize: 5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Text(
                                'N/A',
                                style: TextStyle(
                                  fontSize: 5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          if (isEarlyOut)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Text(
                                'EARLY',
                                style: TextStyle(
                                  fontSize: 5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            )
                          else if (showEarlyNA)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Text(
                                'N/A',
                                style: TextStyle(
                                  fontSize: 5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildContinuousCell(Map<String, dynamic> daySchedules, String timeSlot, int timeSlotIndex, String dayOfWeek, List<String> timeSlots, int rowHeightMinutes) {
    // Find if this time slot should be merged (skip if it's part of a merged cell that started earlier)
    for (final entry in daySchedules.entries) {
      final scheduleData = entry.value;
      final startTime = scheduleData['startTime'] as String;
      final endTime = scheduleData['endTime'] as String;
      
      final startHour = _parseHour(startTime);
      final startMinute = _parseMinute(startTime);
      final endHour = _parseHour(endTime);
      final endMinute = _parseMinute(endTime);
      
      // Convert to total minutes for easier comparison
      final startTotalMinutes = startHour * 60 + startMinute;
      final endTotalMinutes = endHour * 60 + endMinute;
      
      // Check if this time slot is the start of a merged schedule
      final slotHour = _parseHour(timeSlot);
      final slotMinute = _parseMinute(timeSlot);
      final slotTotalMinutes = slotHour * 60 + slotMinute;
      
      if (slotTotalMinutes == startTotalMinutes) {
        // This is the start of the schedule - consume exact space
        final durationMinutes = endTotalMinutes - startTotalMinutes;

        return SizedBox(
          height: rowHeightMinutes.toDouble(),
          child: Container(
            margin: const EdgeInsets.only(right: 2),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: durationMinutes.toDouble(),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue.shade50,
                      Colors.blue.shade100,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.blue.shade300,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (scheduleData['courseCode'] as String).length > 8
                                  ? '${(scheduleData['courseCode'] as String).substring(0, 8)}...'
                                  : scheduleData['courseCode'] as String,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '$startTime - $endTime',
                              style: TextStyle(
                                fontSize: 6,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              scheduleData['facultyName'] as String,
                              style: TextStyle(
                                fontSize: 6,
                                color: Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Builder(
                              builder: (context) {
                                final schedule = scheduleData['schedule'];
                                String facultyId = '';
                                String courseCode = scheduleData['courseCode'] as String;
                                int? scheduleId;

                                if (schedule is Map<String, dynamic>) {
                                  facultyId = schedule['FacultyID']?.toString() ?? schedule['facultyId']?.toString() ?? '';
                                  scheduleId = schedule['ScheduleID'] ?? schedule['scheduleId'];
                                } else {
                                  facultyId = schedule?.facultyId?.toString() ?? '';
                                  scheduleId = schedule?.scheduleId;
                                }

                                final now = DateTime.now();
                                final startOfWeek = _getStartOfWeek(now);
                                final dayMap = {
                                  'Monday': 0,
                                  'Tuesday': 1,
                                  'Wednesday': 2,
                                  'Thursday': 3,
                                  'Friday': 4,
                                  'Saturday': 5,
                                  'Sunday': 6,
                                };
                                final dayOffset = dayMap[dayOfWeek] ?? 0;
                                final targetDate = startOfWeek.add(Duration(days: dayOffset));
                                final dateStr = targetDate.toIso8601String().split('T')[0];

                                final attendance = _getAttendanceForSchedule(facultyId, dateStr, courseCode, dayOfWeek, scheduleId);

                                return Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: Colors.green.shade300),
                                      ),
                                      child: Text(
                                        _formatTime(attendance?.timeIn),
                                        style: TextStyle(
                                          fontSize: 5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: Colors.red.shade300),
                                      ),
                                      child: Text(
                                        _formatTime(attendance?.timeOut),
                                        style: TextStyle(
                                          fontSize: 5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade700,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Builder(
                              builder: (context) {
                                final scheduleStartMinutes = _parseHour(startTime) * 60 + _parseMinute(startTime);
                                final scheduleEndMinutes = _parseHour(endTime) * 60 + _parseMinute(endTime);

                                final schedule = scheduleData['schedule'];
                                String facultyId = '';
                                String courseCode = scheduleData['courseCode'] as String;
                                int? scheduleId;

                                if (schedule is Map<String, dynamic>) {
                                  facultyId = schedule['FacultyID']?.toString() ?? schedule['facultyId']?.toString() ?? '';
                                  scheduleId = schedule['ScheduleID'] ?? schedule['scheduleId'];
                                } else {
                                  facultyId = schedule?.facultyId?.toString() ?? '';
                                  scheduleId = schedule?.scheduleId;
                                }

                                final now = DateTime.now();
                                final startOfWeek = _getStartOfWeek(now);
                                final dayMap = {
                                  'Monday': 0,
                                  'Tuesday': 1,
                                  'Wednesday': 2,
                                  'Thursday': 3,
                                  'Friday': 4,
                                  'Saturday': 5,
                                  'Sunday': 6,
                                };
                                final dayOffset = dayMap[dayOfWeek] ?? 0;
                                final targetDate = startOfWeek.add(Duration(days: dayOffset));
                                final dateStr = targetDate.toIso8601String().split('T')[0];
                                final todayStr = now.toIso8601String().split('T')[0];
                                final isToday = dateStr == todayStr;
                                final startOfToday = DateTime(now.year, now.month, now.day);

                                final attendance = _getAttendanceForSchedule(facultyId, dateStr, courseCode, dayOfWeek, scheduleId);

                                int? timeInMinutes;
                                if (attendance?.timeIn != null) {
                                  timeInMinutes = _parseHour(attendance!.timeIn!) * 60 + _parseMinute(attendance.timeIn!);
                                }
                                int? timeOutMinutes;
                                if (attendance?.timeOut != null) {
                                  timeOutMinutes = _parseHour(attendance!.timeOut!) * 60 + _parseMinute(attendance.timeOut!);
                                }

                                final hasTimeIn = attendance != null && timeInMinutes != null;
                                final isLate = hasTimeIn && timeInMinutes! >= (scheduleStartMinutes + 30);
                                final isPresent = hasTimeIn && !isLate;

                                final hasAnyScan = attendance != null && (attendance.timeIn != null || attendance.timeOut != null);
                                final nowMinutes = now.hour * 60 + now.minute;
                                final dayPassed = targetDate.isBefore(startOfToday);
                                final scheduleEndedToday = isToday && nowMinutes > scheduleEndMinutes;
                                final isAbsent = !hasAnyScan && (dayPassed || scheduleEndedToday);

                                bool isEarlyOut = false;
                                bool showEarlyNA = false;
                                if (isAbsent) {
                                  isEarlyOut = false;
                                  showEarlyNA = true;
                                } else if (attendance != null) {
                                  if (timeOutMinutes != null) {
                                    isEarlyOut = timeOutMinutes <= (scheduleEndMinutes - 30);
                                    showEarlyNA = !isEarlyOut;
                                  } else {
                                    if (isToday) {
                                      if (nowMinutes > scheduleEndMinutes) {
                                        isEarlyOut = hasTimeIn;
                                        showEarlyNA = false;
                                      } else {
                                        isEarlyOut = false;
                                        showEarlyNA = true;
                                      }
                                    } else {
                                      isEarlyOut = false;
                                      showEarlyNA = true;
                                    }
                                  }
                                } else {
                                  showEarlyNA = true;
                                }

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isAbsent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: Colors.red.shade300),
                                        ),
                                        child: Text(
                                          'ABSENT',
                                          style: TextStyle(
                                            fontSize: 5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      )
                                    else if (isLate)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: Colors.orange.shade300),
                                        ),
                                        child: Text(
                                          'LATE',
                                          style: TextStyle(
                                            fontSize: 5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      )
                                    else if (isPresent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: Colors.green.shade300),
                                        ),
                                        child: Text(
                                          'PRESENT',
                                          style: TextStyle(
                                            fontSize: 5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: Colors.grey.shade400),
                                        ),
                                        child: Text(
                                          'N/A',
                                          style: TextStyle(
                                            fontSize: 5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    if (isEarlyOut)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: Colors.red.shade300),
                                        ),
                                        child: Text(
                                          'EARLY',
                                          style: TextStyle(
                                            fontSize: 5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      )
                                    else if (showEarlyNA)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: Colors.grey.shade400),
                                        ),
                                        child: Text(
                                          'N/A',
                                          style: TextStyle(
                                            fontSize: 5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (slotTotalMinutes > startTotalMinutes && slotTotalMinutes < endTotalMinutes) {
        // This time slot is part of a merged cell that started earlier - skip it completely
        return const SizedBox.shrink();
      }
    }
    
    // Empty cell - minimal height (30 minutes = 30px)
    return Container(
      margin: const EdgeInsets.only(right: 2),
      height: rowHeightMinutes.toDouble(),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
    );
  }

  int _parseMinute(String time) {
    try {
      final parts = time.split(':');
      if (parts.length > 1) {
        // For format like "7:00 AM", the minutes are in parts[1] before the space
        // For format like "7AM:30", the minutes are in parts[1]
        String minuteStr = parts[1];
        
        // Remove any non-digit characters (like " AM" from "00 AM")
        minuteStr = minuteStr.replaceAll(RegExp(r'[^0-9]'), '');
        
        return int.tryParse(minuteStr) ?? 0;
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }

  Widget _buildCompactScheduleCard(dynamic schedule) {
    // Extract data from either Map or ScheduleModel
    String facultyName, subjectName, courseCode, dayOfWeek;
    
    if (schedule is Map<String, dynamic>) {
      facultyName = schedule['FacultyName'] ?? schedule['facultyName'] ?? schedule['faculty_name'] ?? 'Unknown Faculty';
      subjectName = schedule['SubjectName'] ?? schedule['subjectName'] ?? schedule['subject_name'] ?? 'Unknown Subject';
      courseCode = schedule['CourseCode'] ?? schedule['courseCode'] ?? schedule['course_code'] ?? '';
      dayOfWeek = schedule['DayOfWeek'] ?? schedule['dayOfWeek'] ?? schedule['day_of_week'] ?? 'Unknown Day';
    } else {
      // Assume it's a ScheduleModel object
      facultyName = schedule.facultyName ?? 'Unknown Faculty';
      subjectName = schedule.subjectName ?? 'Unknown Subject';
      courseCode = schedule.courseCode ?? '';
      dayOfWeek = schedule.dayOfWeek ?? 'Unknown Day';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Day and time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$dayOfWeek',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Subject name
          Text(
            subjectName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (courseCode.isNotEmpty)
            Text(
              courseCode,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          const SizedBox(height: 2),
          // Faculty name
          Row(
            children: [
              Icon(Icons.person, color: Colors.grey[600], size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  facultyName,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _generateTimeSlots() {
    final slots = <String>[];
    for (int hour = 7; hour <= 21; hour++) { // 7 AM to 9 PM
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      // Add both :00 and :30 for each hour in proper format "7:00 AM"
      slots.add('${displayHour.toString().padLeft(2, '0')}:00 $period');
      if (hour < 21) { // Don't add :30 for 9 PM
        slots.add('${displayHour.toString().padLeft(2, '0')}:30 $period');
      }
    }
    return slots;
  }

  List<dynamic> _getAllSchedules(Map<String, dynamic> roomData) {
    final allSchedules = <dynamic>[];
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    for (final day in days) {
      final daySchedules = roomData[day] as List<dynamic>;
      allSchedules.addAll(daySchedules);
    }
    
    // Sort by day and time
    allSchedules.sort((a, b) {
      final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      
      // Handle both Map and ScheduleModel objects
      String aDay, bDay;
      String aTime, bTime;
      
      if (a is Map<String, dynamic>) {
        aDay = a['DayOfWeek'] ?? a['dayOfWeek'] ?? a['day_of_week'] ?? '';
        aTime = a['StartTime'] ?? a['startTime'] ?? a['start_time'] ?? '';
      } else {
        // Assume it's a ScheduleModel object
        aDay = a.dayOfWeek ?? '';
        aTime = a.startTime ?? '';
      }
      
      if (b is Map<String, dynamic>) {
        bDay = b['DayOfWeek'] ?? b['dayOfWeek'] ?? b['day_of_week'] ?? '';
        bTime = b['StartTime'] ?? b['startTime'] ?? b['start_time'] ?? '';
      } else {
        // Assume it's a ScheduleModel object
        bDay = b.dayOfWeek ?? '';
        bTime = b.startTime ?? '';
      }
      
      final aDayIndex = dayOrder.indexOf(aDay);
      final bDayIndex = dayOrder.indexOf(bDay);
      
      if (aDayIndex != bDayIndex) {
        return aDayIndex.compareTo(bDayIndex);
      }
      
      return aTime.compareTo(bTime);
    });
    
    return allSchedules;
  }

  int _parseHour(String time) {
    try {
      // Handle both "7:00 AM" and "7AM:30" formats
      final parts = time.split(':');
      if (parts.isNotEmpty) {
        // For format like "7:00 AM", the hour is in parts[0]
        // For format like "7AM:30", the hour is in parts[0]
        String hourStr = parts[0];
        
        // Extract hour number
        final hourMatch = RegExp(r'(\d+)').firstMatch(hourStr);
        if (hourMatch != null) {
          int hour = int.parse(hourMatch.group(1)!);
          
          // Check if it's PM format - look in the entire time string
          if (time.toLowerCase().contains('pm') && hour < 12) {
            hour += 12; // Convert PM to 24-hour format
          } else if (time.toLowerCase().contains('am') && hour == 12) {
            hour = 0; // 12 AM is 0 in 24-hour format
          }
          
          return hour;
        }
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }
}

class AttendanceReportsView extends StatefulWidget {
  const AttendanceReportsView({super.key});

  @override
  State<AttendanceReportsView> createState() => _AttendanceReportsViewState();
}

class _AttendanceReportsViewState extends State<AttendanceReportsView> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  Future<Map<String, dynamic>> _safeLoadReport(DateTime start, DateTime end) async {
    try {
      return await DataService.getAttendanceReport(start, end);
    } catch (e) {
      debugPrint('[OfficerDashboard] Failed to load report: $e');
      return {'summary': {}, 'records': []};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(DateFormat('MMM d, yyyy').format(_startDate)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(DateFormat('MMM d, yyyy').format(_endDate)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _safeLoadReport(_startDate, _endDate),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final report = snapshot.data ?? {};
              final summary = report['summary'] as Map<String, dynamic>? ?? {};
              final records = report['records'] as List? ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildSummaryCard('Total', '${summary['total'] ?? 0}', Colors.blue),
                        const SizedBox(width: 12),
                        _buildSummaryCard('Present', '${summary['present'] ?? 0}', Colors.green),
                        const SizedBox(width: 12),
                        _buildSummaryCard('Late', '${summary['late'] ?? 0}', Colors.orange),
                        const SizedBox(width: 12),
                        _buildSummaryCard('Absent', '${summary['absent'] ?? 0}', Colors.red),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Recent Records',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (records.isEmpty)
                      const Center(child: Text('No records found'))
                    else
                      ...records.take(20).map((record) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(record['faculty_name'] ?? 'Unknown'),
                            subtitle: Text(record['date'] ?? ''),
                            trailing: Text(record['status'] ?? ''),
                          ),
                        )),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }
}
