import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/models.dart';
import '../../services/data_service.dart';
import '../../services/faculty_analytics_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/sync_status_widget.dart';
import '../../widgets/auto_refresh_mixin.dart';

class FacultyDashboardScreen extends StatefulWidget {
  const FacultyDashboardScreen({super.key});

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> with AutoRefreshMixin {
  String _currentScreen = 'faculty_home';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Device selection
  List<DeviceModel> _devices = [];
  DeviceModel? _selectedDevice;
  bool _loadingDevices = true;

  // Overview data
  Map<String, dynamic> _summary = {};
  bool _summaryLoading = true;

  // Attendance history
  List<Map<String, dynamic>> _attendanceHistory = [];
  bool _historyLoading = true;

  // Analytics
  List<Map<String, dynamic>> _statusBreakdown = [];
  List<Map<String, dynamic>> _trend = [];
  Map<String, dynamic> _analyticsSummary = {};
  bool _analyticsLoading = true;

  // Schedule grid zoom
  final Map<String, TransformationController> _zoomControllers = {};

  // Filters
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  String get _fromStr => DateFormat('yyyy-MM-dd').format(_dateRange.start);
  String get _toStr => DateFormat('yyyy-MM-dd').format(_dateRange.end);

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _loadOverview();
    startAutoRefresh(() => _silentRefresh());
  }

  @override
  void dispose() {
    stopAutoRefresh();
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _silentRefresh() {
    _loadOverview();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await DataService.getDevices();
      if (mounted) setState(() { _devices = devices.where((d) => d.isActive).toList(); _loadingDevices = false; });
    } catch (_) {
      if (mounted) setState(() { _devices = []; _loadingDevices = false; });
    }
  }

  Future<void> _loadOverview() async {
    setState(() => _summaryLoading = true);
    setState(() => _analyticsLoading = true);
    try {
      final results = await Future.wait([
        FacultyAnalyticsService.getDashboardSummary(from: _fromStr, to: _toStr),
        FacultyAnalyticsService.getStatusBreakdown(from: _fromStr, to: _toStr),
        FacultyAnalyticsService.getAttendanceTrend(from: _fromStr, to: _toStr),
        FacultyAnalyticsService.getAnalyticsSummary(from: _fromStr, to: _toStr),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>;
          _statusBreakdown = results[1] as List<Map<String, dynamic>>;
          _trend = results[2] as List<Map<String, dynamic>>;
          _analyticsSummary = results[3] as Map<String, dynamic>;
          _summaryLoading = false;
          _analyticsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summary = {'error': e.toString()};
          _summaryLoading = false;
          _analyticsLoading = false;
        });
      }
    }
    if (mounted) context.read<AttendanceProvider>().loadTodayData();
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final data = await FacultyAnalyticsService.getAttendance(from: _fromStr, to: _toStr);
      if (mounted) setState(() { _attendanceHistory = data; _historyLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _attendanceHistory = []; _historyLoading = false; });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _refreshCurrentScreen();
    }
  }

  void _refreshCurrentScreen() {
    switch (_currentScreen) {
      case 'faculty_home': _loadOverview(); break;
      case 'faculty_schedule': setState(() {}); break;
      case 'faculty_history': _loadHistory(); break;
    }
  }

  void _handleDrawerSelection(String selection) {
    if (selection == 'logout') {
      context.read<AuthProvider>().logout();
      return;
    }
    Navigator.pop(context);
    setState(() => _currentScreen = selection);
    // Load data for the selected screen
    switch (selection) {
      case 'faculty_home': _loadOverview(); break;
      case 'faculty_history': _loadHistory(); break;
    }
  }

  String _getScreenTitle() {
    switch (_currentScreen) {
      case 'faculty_home': return 'Faculty Dashboard';
      case 'faculty_schedule': return 'My Schedule';
      case 'faculty_history': return 'Attendance History';
      default: return 'Faculty Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshCurrentScreen, tooltip: 'Refresh'),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => authProvider.logout(), tooltip: 'Logout'),
        ],
      ),
      drawer: AppDrawer(
        currentScreen: _currentScreen,
        onItemSelected: _handleDrawerSelection,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_currentScreen) {
      case 'faculty_home': return _buildOverviewView();
      case 'faculty_schedule': return _buildScheduleView();
      case 'faculty_history': return _buildAttendanceView();
      default: return _buildOverviewView();
    }
  }

  // ═══════════════════════════════════════════════
  // OVERVIEW
  // ═══════════════════════════════════════════════
  Widget _buildOverviewView() {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.person, size: 32, color: Colors.blue.shade700),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${authProvider.user?.facultyName ?? authProvider.user?.username ?? 'Faculty'}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()), style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // KPI cards
            if (_summaryLoading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else ...[
              LayoutBuilder(builder: (context, constraints) {
                const spacing = 12.0;
                final isMobile = constraints.maxWidth < 600;
                final cols = isMobile ? 2 : 4;
                final cardWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _kpiCard('Attendance Rate', '${_summary['attendanceRate'] ?? 0}%', Icons.check_circle, Colors.green, cardWidth),
                    _kpiCard('Punctuality', '${_summary['punctualityIndex'] ?? 0}%', Icons.access_time, Colors.blue, cardWidth),
                    _kpiCard('Late', '${_summary['totalLate'] ?? 0}', Icons.warning_amber, Colors.orange, cardWidth),
                    _kpiCard('Exceptions', '${_summary['totalExceptions'] ?? 0}', Icons.error_outline, Colors.red, cardWidth),
                  ],
                );
              }),
              const SizedBox(height: 16),

              // Upcoming class
              if (_summary['upcomingClass'] != null) ...[
                Card(
                  color: Colors.blue.shade50,
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: Icon(Icons.upcoming, color: Colors.blue.shade700)),
                    title: Text('Next: ${_summary['upcomingClass']['SubjectName'] ?? ''} (${_summary['upcomingClass']['CourseCode'] ?? ''})'),
                    subtitle: Text('${_summary['upcomingClass']['StartTime'] ?? ''} - ${_summary['upcomingClass']['EndTime'] ?? ''} • ${_summary['upcomingClass']['RoomName'] ?? ''} (${_summary['upcomingClass']['Building'] ?? ''})'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Time In/Out
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Attendance', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (_loadingDevices)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<DeviceModel>(
                        initialValue: _selectedDevice,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Select device', isDense: true),
                        items: _devices.map((d) => DropdownMenuItem(value: d, child: Text('${d.location} (${d.deviceType})'))).toList(),
                        onChanged: (v) => setState(() => _selectedDevice = v),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: attendanceProvider.isLoading || attendanceProvider.hasOpenAttendance ? null : _handleTimeIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Time In'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: attendanceProvider.isLoading || !attendanceProvider.hasOpenAttendance ? null : _handleTimeOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('Time Out'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                      ],
                    ),
                    if (attendanceProvider.hasOpenAttendance) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Open attendance. Time in: ${attendanceProvider.openAttendance?.timeIn ?? ""}', style: TextStyle(color: Colors.blue[700], fontSize: 13))),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Today's schedule
            Text("Today's Schedule (${attendanceProvider.dayOfWeek})", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (attendanceProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (attendanceProvider.todaySchedules.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('No schedules for today', style: TextStyle(color: Colors.grey[600])))))
            else
              ...attendanceProvider.todaySchedules.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue[100], child: Icon(Icons.schedule, color: Colors.blue[700])),
                  title: Text('${s.subjectName} (${s.courseCode})'),
                  subtitle: Text('${s.timeRange}\n${s.roomInfo}'),
                  isThreeLine: true,
                ),
              )),

            // Analytics Charts
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('My Analytics', style: Theme.of(context).textTheme.headlineSmall),
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text('${DateFormat('MMM d').format(_dateRange.start)} — ${DateFormat('MMM d').format(_dateRange.end)}', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_analyticsLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else ...[
              // Pie + Trend side by side
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 700;
                if (wide) {
                  final halfWidth = (constraints.maxWidth - 16) / 2;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(width: halfWidth, child: _buildStatusPieChart()),
                      SizedBox(width: halfWidth, child: _buildTrendLineChart()),
                    ],
                  );
                }
                return Column(children: [
                  _buildStatusPieChart(),
                  const SizedBox(height: 16),
                  _buildTrendLineChart(),
                ]);
              }),
              const SizedBox(height: 16),
              _buildSubjectBarChart(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, double width) {
    return SizedBox(
      width: width.clamp(130.0, double.infinity),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(icon, color: color, size: 24),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              ]),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // SCHEDULE (Officer-style room-based grid)
  // ═══════════════════════════════════════════════
  Widget _buildScheduleView() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        DataService.getSchedules(),
        DataService.getRooms(),
      ]),
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
                ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry')),
              ],
            ),
          );
        }

        final schedules = snapshot.data![0] as List;
        final rooms = snapshot.data![1] as List;
        final today = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
        final isMobile = !kIsWeb && MediaQuery.of(context).size.width < 600;

        // Group schedules by room
        final Map<int, Map<String, dynamic>> schedulesByRoom = {};
        for (var room in rooms) {
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
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                children: [
                  Text(today, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Weekly Schedule View', style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
            Expanded(
              child: schedules.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.schedule, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No schedules found'),
                    ]))
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 8 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                              Row(children: [
                                                const Icon(Icons.room, size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text('${room?.roomName ?? "Unknown"} - ${room?.building ?? ""}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                              ]),
                                              const SizedBox(height: 4),
                                              Text('Capacity: ${room?.capacity ?? "-"}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                            ],
                                          )
                                        : Row(children: [
                                            const Icon(Icons.room, size: 24),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text('${room?.roomName ?? "Unknown"} - ${room?.building ?? ""}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            const SizedBox(width: 12),
                                            Text('Capacity: ${room?.capacity ?? "-"}'),
                                          ]),
                                  ),
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
                    ),
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
    final key = 'faculty_$roomId';
    final controller = _zoomControllers.putIfAbsent(
      key,
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
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: () => _applyZoom(key, 1.2),
                      icon: const Icon(Icons.add),
                      tooltip: 'Zoom in',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: () => _applyZoom(key, 1 / 1.2),
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

  void _applyZoom(String key, double factor) {
    final controller = _zoomControllers[key];
    if (controller == null) return;
    final current = controller.value.clone();
    final currentScale = current.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.6, 3.0);
    current.scale(newScale / currentScale);
    controller.value = current;
  }

  Widget _buildTimeGridSchedule(Map<String, dynamic> roomData) {
    final timeSlots = _generateTimeSlots();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    // Pre-process schedules
    final Map<String, Map<String, dynamic>> mergedSchedules = {};
    for (final day in days) {
      mergedSchedules[day] = {};
      final daySchedules = roomData[day] as List<dynamic>;
      for (final schedule in daySchedules) {
        String startTime, endTime, subjectName, facultyName, courseCode, roomName;
        if (schedule is Map<String, dynamic>) {
          startTime = schedule['StartTime'] ?? schedule['startTime'] ?? '';
          endTime = schedule['EndTime'] ?? schedule['endTime'] ?? '';
          subjectName = schedule['SubjectName'] ?? schedule['subjectName'] ?? '';
          facultyName = schedule['FacultyName'] ?? schedule['facultyName'] ?? '';
          courseCode = schedule['CourseCode'] ?? schedule['courseCode'] ?? '';
          roomName = schedule['RoomName'] ?? schedule['roomName'] ?? '';
        } else {
          startTime = schedule.startTime ?? '';
          endTime = schedule.endTime ?? '';
          subjectName = schedule.subjectName ?? '';
          facultyName = schedule.facultyName ?? '';
          courseCode = schedule.courseCode ?? '';
          roomName = schedule.roomName ?? '';
        }
        final key = '$subjectName-$facultyName-$startTime-$endTime';
        mergedSchedules[day]!.putIfAbsent(key, () => {
          'startTime': startTime,
          'endTime': endTime,
          'subjectName': subjectName,
          'facultyName': facultyName,
          'courseCode': courseCode,
          'roomName': roomName,
        });
      }
    }

    return Column(
      children: [
        // Header row
        Row(
          children: [
            const SizedBox(width: 60),
            const SizedBox(width: 4),
            ...days.map((day) => Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                child: Text(day.substring(0, 3), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
              ),
            )),
          ],
        ),
        const SizedBox(height: 4),
        _buildScheduleGrid(mergedSchedules, timeSlots, days),
      ],
    );
  }

  Widget _buildScheduleGrid(Map<String, Map<String, dynamic>> mergedSchedules, List<String> timeSlots, List<String> days) {
    const cellHeight = 30.0;
    const rowGap = 2.0;
    final gridHeight = (timeSlots.length * (cellHeight + rowGap)) - rowGap;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time column
        SizedBox(
          width: 60,
          child: Column(
            children: timeSlots.asMap().entries.map((entry) {
              return Container(
                margin: EdgeInsets.only(bottom: entry.key != timeSlots.length - 1 ? rowGap : 0),
                height: cellHeight,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(child: Text(entry.value, style: TextStyle(fontSize: 8, color: Colors.grey[700], fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 4),
        // Schedule columns
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dayWidth = constraints.maxWidth / days.length;
              final scheduleBlocks = <Widget>[];

              for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
                final day = days[dayIndex];
                final daySchedules = mergedSchedules[day] ?? {};

                for (final entry in daySchedules.entries) {
                  final data = entry.value;
                  final startTime = data['startTime'] as String;
                  final endTime = data['endTime'] as String;

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
                      child: _buildScheduleBlock(data),
                    ),
                  ));
                }
              }

              return SizedBox(
                height: gridHeight,
                child: Stack(
                  children: [
                    // Background grid
                    Column(
                      children: List.generate(timeSlots.length, (index) {
                        return Container(
                          margin: EdgeInsets.only(bottom: index == timeSlots.length - 1 ? 0 : rowGap),
                          height: cellHeight,
                          child: Row(
                            children: days.map((_) => Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 2),
                                height: cellHeight,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade200, width: 0.5),
                                ),
                              ),
                            )).toList(),
                          ),
                        );
                      }),
                    ),
                    ...scheduleBlocks,
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleBlock(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data['courseCode'] as String,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              '${data['startTime']} - ${data['endTime']}',
              style: TextStyle(fontSize: 6, color: Colors.blue[600], fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              data['subjectName'] as String,
              style: TextStyle(fontSize: 6, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _generateTimeSlots() {
    final slots = <String>[];
    for (int hour = 7; hour <= 21; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00');
      if (hour < 21) slots.add('${hour.toString().padLeft(2, '0')}:30');
    }
    return slots;
  }

  int _parseHour(String time) {
    try { return int.parse(time.split(':')[0]); } catch (_) { return 0; }
  }

  int _parseMinute(String time) {
    try { return int.parse(time.split(':')[1]); } catch (_) { return 0; }
  }

  // ═══════════════════════════════════════════════
  // ATTENDANCE HISTORY
  // ═══════════════════════════════════════════════
  Widget _buildAttendanceView() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Attendance History', style: Theme.of(context).textTheme.headlineSmall),
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text('${DateFormat('MMM d').format(_dateRange.start)} — ${DateFormat('MMM d').format(_dateRange.end)}', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_historyLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_attendanceHistory.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No attendance records found', style: TextStyle(color: Colors.grey[600])))))
            else
              ..._attendanceHistory.map((a) {
                final status = a['AttendanceStatus'] ?? '';
                final statusColor = status == 'Present' ? Colors.green : status == 'Late' ? Colors.orange : status == 'Absent' ? Colors.red : Colors.grey;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      child: Icon(
                        status == 'Present' ? Icons.check_circle : status == 'Late' ? Icons.access_time : status == 'Absent' ? Icons.cancel : Icons.help_outline,
                        color: statusColor, size: 20,
                      ),
                    ),
                    title: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: a['SubjectName'] ?? 'N/A', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        if (a['CourseCode'] != null) TextSpan(text: ' (${a['CourseCode']})', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ]),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${a['Date'] ?? ''} • In: ${a['TimeIn'] ?? '-'} | Out: ${a['TimeOut'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                        if (a['RoomName'] != null) Text('${a['RoomName']} (${a['Building'] ?? ''})', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        if (a['Remarks'] != null && a['Remarks'].toString().isNotEmpty)
                          Text('Remarks: ${a['Remarks']}', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPieChart() {
    final total = _statusBreakdown.fold<int>(0, (sum, e) => sum + ((e['count'] ?? 0) as int));
    final colorMap = {'Present': Colors.green, 'Late': Colors.orange, 'Absent': Colors.red};

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: total == 0
                  ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                  : Row(children: [
                      Expanded(
                        child: PieChart(PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 35,
                          sections: _statusBreakdown.map((s) {
                            final count = (s['count'] ?? 0).toDouble();
                            final status = s['status'] ?? '';
                            final color = colorMap[status] ?? Colors.grey;
                            return PieChartSectionData(
                              value: count,
                              title: '${(count / total * 100).toStringAsFixed(0)}%',
                              color: color,
                              radius: 45,
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            );
                          }).toList(),
                        )),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _statusBreakdown.map((s) {
                          final color = colorMap[s['status']] ?? Colors.grey;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 6),
                              Text('${s['status']} (${s['count']})', style: const TextStyle(fontSize: 11)),
                            ]),
                          );
                        }).toList(),
                      ),
                    ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendLineChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: _trend.isEmpty
                  ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                  : LineChart(LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, reservedSize: 28,
                          interval: (_trend.length / 5).ceilToDouble().clamp(1, double.infinity),
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= _trend.length) return const SizedBox();
                            return Padding(padding: const EdgeInsets.only(top: 6), child: Text((_trend[idx]['date'] ?? '').toString().substring(5), style: const TextStyle(fontSize: 9)));
                          },
                        )),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9)))),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['totalPresent'] ?? 0).toDouble())).toList(),
                          isCurved: true, color: Colors.green, barWidth: 2,
                          dotData: FlDotData(show: _trend.length < 15),
                          belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: 0.1)),
                        ),
                        LineChartBarData(
                          spots: _trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['totalLate'] ?? 0).toDouble())).toList(),
                          isCurved: true, color: Colors.orange, barWidth: 2,
                          dotData: FlDotData(show: _trend.length < 15),
                        ),
                      ],
                    )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectBarChart() {
    final subjects = List<Map<String, dynamic>>.from(_analyticsSummary['subjectBreakdown'] ?? []);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Subject Attendance Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: subjects.isEmpty
                  ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                  : BarChart(BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, gi, rod, ri) {
                            final s = subjects[gi];
                            return BarTooltipItem('${s['CourseCode']}\n${rod.toY.toStringAsFixed(1)}%', const TextStyle(color: Colors.white, fontSize: 12));
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, reservedSize: 30,
                          getTitlesWidget: (v, m) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= subjects.length) return const SizedBox();
                            final code = subjects[idx]['CourseCode'] ?? '';
                            return Padding(padding: const EdgeInsets.only(top: 6), child: Text(code.length > 8 ? '${code.substring(0, 8)}..' : code, style: const TextStyle(fontSize: 10)));
                          },
                        )),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)))),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25),
                      borderData: FlBorderData(show: false),
                      barGroups: subjects.asMap().entries.map((e) {
                        final rate = (e.value['attendanceRate'] ?? 0).toDouble();
                        return BarChartGroupData(x: e.key, barRods: [
                          BarChartRodData(toY: rate, color: rate >= 80 ? Colors.green : rate >= 50 ? Colors.orange : Colors.red, width: 22, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                        ]);
                      }).toList(),
                    )),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // TIME IN / OUT HANDLERS
  // ═══════════════════════════════════════════════
  Future<void> _handleTimeIn() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a device first')));
      return;
    }
    final success = await context.read<AttendanceProvider>().timeIn(_selectedDevice!.deviceId);
    if (mounted) {
      final provider = context.read<AttendanceProvider>();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? provider.successMessage ?? 'Time in recorded' : provider.error ?? 'Failed'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _handleTimeOut() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a device first')));
      return;
    }
    final success = await context.read<AttendanceProvider>().timeOut(_selectedDevice!.deviceId);
    if (mounted) {
      final provider = context.read<AttendanceProvider>();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? provider.successMessage ?? 'Time out recorded' : provider.error ?? 'Failed'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }
}
