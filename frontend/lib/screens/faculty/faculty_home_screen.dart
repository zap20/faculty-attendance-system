import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/models.dart';
import '../../services/data_service.dart';
import '../../widgets/app_drawer.dart';

class FacultyHomeScreen extends StatefulWidget {
  const FacultyHomeScreen({super.key});

  @override
  State<FacultyHomeScreen> createState() => _FacultyHomeScreenState();
}

class _FacultyHomeScreenState extends State<FacultyHomeScreen> {
  String _currentScreen = 'faculty_home';
  List<DeviceModel> _devices = [];
  DeviceModel? _selectedDevice;
  bool _loadingDevices = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load today's data
    await context.read<AttendanceProvider>().loadTodayData();
    
    // Load devices
    try {
      final devices = await DataService.getDevices();
      setState(() {
        _devices = devices.where((d) => d.isActive).toList();
        _loadingDevices = false;
      });
    } catch (e) {
      setState(() {
        _loadingDevices = false;
      });
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
      case 'faculty_home':
        return 'Faculty Attendance';
      case 'faculty_schedule':
        return 'My Schedule';
      case 'faculty_history':
        return 'Attendance History';
      case 'profile':
        return 'Profile';
      case 'settings':
        return 'Settings';
      default:
        return 'Faculty Attendance';
    }
  }

  Widget _buildContent() {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    switch (_currentScreen) {
      case 'faculty_home':
        return _buildHomeView(authProvider, attendanceProvider);
      case 'faculty_schedule':
        return _buildScheduleView();
      case 'faculty_history':
        return _buildHistoryView();
      case 'profile':
        return _buildProfileView();
      case 'settings':
        return _buildSettingsView();
      default:
        return _buildHomeView(authProvider, attendanceProvider);
    }
  }

  Widget _buildHomeView(AuthProvider authProvider, AttendanceProvider attendanceProvider) {
    return RefreshIndicator(
      onRefresh: _loadData,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${authProvider.user?.facultyName ?? authProvider.user?.username ?? 'Faculty'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Device selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Device',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_loadingDevices)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<DeviceModel>(
                        initialValue: _selectedDevice,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Select attendance device',
                        ),
                        items: _devices.map((device) {
                          return DropdownMenuItem(
                            value: device,
                            child: Text('${device.location} (${device.deviceType})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDevice = value;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time In/Out buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: attendanceProvider.isLoading || attendanceProvider.hasOpenAttendance
                                ? null
                                : _handleTimeIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Time In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: attendanceProvider.isLoading || !attendanceProvider.hasOpenAttendance
                                ? null
                                : _handleTimeOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('Time Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (attendanceProvider.hasOpenAttendance) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You have an open attendance. Time in: ${attendanceProvider.openAttendance?.timeIn ?? ""}',
                                style: TextStyle(color: Colors.blue[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Today's Schedule
            Text(
              "Today's Schedule (${attendanceProvider.dayOfWeek})",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (attendanceProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (attendanceProvider.todaySchedules.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No schedules for today',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              ...attendanceProvider.todaySchedules.map((schedule) => _buildScheduleCard(schedule)),

            const SizedBox(height: 16),

            // Today's Attendance
            Text(
              "Today's Attendance",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (attendanceProvider.todayAttendances.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No attendance records for today',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              ...attendanceProvider.todayAttendances.map((attendance) => _buildAttendanceCard(attendance)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleView() {
    return const Center(
      child: Text('Schedule View - Coming Soon'),
    );
  }

  Widget _buildHistoryView() {
    return const Center(
      child: Text('Attendance History - Coming Soon'),
    );
  }

  Widget _buildProfileView() {
    return const Center(
      child: Text('Profile - Coming Soon'),
    );
  }

  Widget _buildSettingsView() {
    return const Center(
      child: Text('Settings - Coming Soon'),
    );
  }

  Future<void> _handleTimeIn() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device first')),
      );
      return;
    }

    final success = await context.read<AttendanceProvider>().timeIn(_selectedDevice!.deviceId);
    if (mounted) {
      final provider = context.read<AttendanceProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? provider.successMessage ?? 'Time in recorded' : provider.error ?? 'Failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _handleTimeOut() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device first')),
      );
      return;
    }

    final success = await context.read<AttendanceProvider>().timeOut(_selectedDevice!.deviceId);
    if (mounted) {
      final provider = context.read<AttendanceProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? provider.successMessage ?? 'Time out recorded' : provider.error ?? 'Failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      drawer: AppDrawer(
        currentScreen: _currentScreen,
        onItemSelected: _handleDrawerSelection,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildScheduleCard(ScheduleModel schedule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(Icons.schedule, color: Colors.blue[700]),
        ),
        title: Text('${schedule.subjectName} (${schedule.courseCode})'),
        subtitle: Text('${schedule.timeRange}\n${schedule.roomInfo}'),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceModel attendance) {
    Color statusColor;
    switch (attendance.attendanceStatus) {
      case 'Present':
        statusColor = Colors.green;
        break;
      case 'Late':
        statusColor = Colors.orange;
        break;
      case 'Wrong Room':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            attendance.hasTimedOut ? Icons.check_circle : Icons.access_time,
            color: statusColor,
          ),
        ),
        title: Text(attendance.subjectName ?? 'Attendance Record'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('In: ${attendance.timeIn ?? "-"} | Out: ${attendance.timeOut ?? "-"}'),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                attendance.attendanceStatus,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
