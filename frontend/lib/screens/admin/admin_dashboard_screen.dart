import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/sync_status_widget.dart';
import '../shared/reports_screen.dart';
import 'admin_analytics_screen.dart';
import '../../widgets/auto_refresh_mixin.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with AutoRefreshMixin {
  String _currentScreen = 'admin_dashboard';
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    startAutoRefresh(() => _silentRefresh());
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await DataService.getDashboard();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      // Dashboard not available offline
      setState(() {
        _dashboardData = {};
        _isLoading = false;
      });
    }
  }

  void _silentRefresh() async {
    try {
      final data = await DataService.getDashboard();
      if (mounted) {
        setState(() => _dashboardData = data);
      }
    } catch (_) {}
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
      case 'admin_dashboard':
        return 'Admin Dashboard';
      case 'admin_faculty':
        return 'Faculty Management';
      case 'admin_departments':
        return 'Department Management';
      case 'admin_subjects':
        return 'Subject Management';
      case 'admin_rooms':
        return 'Room Management';
      case 'admin_schedules':
        return 'Schedule Management';
      case 'admin_devices':
        return 'Device Management';
      case 'admin_reports':
        return 'Reports';
      default:
        return 'Admin Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          const SyncStatusWidget(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
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

  Widget _buildContent() {
    switch (_currentScreen) {
      case 'admin_dashboard':
        return const AdminAnalyticsScreen();
      case 'admin_faculty':
        return _buildFacultyView();
      case 'admin_departments':
        return _buildDepartmentsView();
      case 'admin_subjects':
        return _buildSubjectsView();
      case 'admin_rooms':
        return _buildRoomsView();
      case 'admin_schedules':
        return _buildSchedulesView();
      case 'admin_devices':
        return _buildDevicesView();
      case 'admin_reports':
        return _buildReportsView();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _dashboardData['stats'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final cardWidth = isMobile
                ? (constraints.maxWidth - 16) / 2
                : (constraints.maxWidth - 48) / 4;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: cardWidth, child: _buildStatCard('Total Faculty', '${stats['totalFaculty'] ?? 0}', Icons.people, Colors.blue)),
                SizedBox(width: cardWidth, child: _buildStatCard('Departments', '${stats['totalDepartments'] ?? 0}', Icons.business, Colors.purple)),
                SizedBox(width: cardWidth, child: _buildStatCard('Present Today', '${stats['presentToday'] ?? 0}', Icons.check_circle, Colors.green)),
                SizedBox(width: cardWidth, child: _buildStatCard('Late Today', '${stats['lateToday'] ?? 0}', Icons.access_time, Colors.orange)),
              ],
            );
          }),
          const SizedBox(height: 24),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentScreen = 'admin_faculty'),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Faculty'),
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentScreen = 'admin_schedules'),
                icon: const Icon(Icons.schedule),
                label: const Text('Manage Schedules'),
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentScreen = 'admin_reports'),
                icon: const Icon(Icons.assessment),
                label: const Text('View Reports'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyView() {
    return _buildCrudView(
      title: 'Faculty Management',
      fetchData: DataService.getFaculties,
      columns: ['Name', 'Department', 'Position', 'Status'],
      getRowData: (faculty) => [
        faculty.facultyName,
        faculty.departmentName ?? '-',
        faculty.position,
        faculty.employmentStatus,
      ],
    );
  }

  Widget _buildDepartmentsView() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        DataService.getDepartments(),
        DataService.getFaculties(),
        DataService.getSubjects(),
        DataService.getRooms(),
        DataService.getSchedules(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final departments = snapshot.data![0] as List;
        final faculties = snapshot.data![1] as List;
        final subjects = snapshot.data![2] as List;
        final rooms = snapshot.data![3] as List;
        final schedules = snapshot.data![4] as List;

        // Build a set of roomIds used by each department (via schedules)
        final Map<int, Set<int>> deptRoomIds = {};
        for (var schedule in schedules) {
          final faculty = faculties.cast<dynamic>().where((f) => f.facultyId == schedule.facultyId?.toString()).toList();
          if (faculty.isNotEmpty) {
            final deptId = faculty.first.departmentId as int;
            deptRoomIds.putIfAbsent(deptId, () => {});
            if (schedule.roomId != null) deptRoomIds[deptId]!.add(schedule.roomId as int);
          }
        }

        return SingleChildScrollView(
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
                  Text('Department Management', style: Theme.of(context).textTheme.headlineSmall),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add new Department item')),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                const spacing = 16.0;
                final cardWidth = (constraints.maxWidth - spacing * 2) / 3;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: departments.map<Widget>((dept) {
                    final deptId = dept.departmentId as int;
                    final deptFaculties = faculties.cast<dynamic>().where((f) => f.departmentId == deptId).toList();
                    final deptSubjects = subjects.cast<dynamic>().where((s) => s.departmentId == deptId).toList();
                    final usedRoomIds = deptRoomIds[deptId] ?? {};
                    final deptRooms = rooms.cast<dynamic>().where((r) => usedRoomIds.contains(r.roomId)).toList();

                    return SizedBox(
                      width: cardWidth.clamp(300.0, double.infinity),
                      child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Department header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.business, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dept.departmentName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildDeptInfoChip(Icons.person, 'Head', dept.departmentHead ?? 'Not Assigned', Colors.blue),
                                _buildDeptInfoChip(Icons.school, 'Dean', dept.departmentDean ?? 'Not Assigned', Colors.purple),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Stats row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildDeptStatBadge('${deptFaculties.length}', 'Faculty', Colors.blue),
                            _buildDeptStatBadge('${deptSubjects.length}', 'Subjects', Colors.orange),
                            _buildDeptStatBadge('${deptRooms.length}', 'Rooms', Colors.green),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Faculty list
                      if (deptFaculties.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text('Faculty Members', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                        ),
                        ...deptFaculties.map((f) => ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(f.facultyName.substring(0, 1).toUpperCase(), style: TextStyle(fontSize: 14, color: Colors.blue.shade800)),
                          ),
                          title: Text(f.facultyName, style: const TextStyle(fontSize: 14)),
                          subtitle: Text('${f.position} • ${f.employmentStatus}', style: const TextStyle(fontSize: 12)),
                          trailing: Text(f.facultyId, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        )),
                      ],
                      // Subjects list
                      if (deptSubjects.isNotEmpty) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text('Subjects', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: deptSubjects.map<Widget>((s) => Chip(
                              avatar: const Icon(Icons.book, size: 16),
                              label: Text('${s.courseCode} - ${s.subjectName} (${s.units}u)', style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.orange.shade50,
                              side: BorderSide(color: Colors.orange.shade200),
                            )).toList(),
                          ),
                        ),
                      ],
                      // Rooms list
                      if (deptRooms.isNotEmpty) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text('Rooms Used', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: deptRooms.map<Widget>((r) => Chip(
                              avatar: const Icon(Icons.room, size: 16),
                              label: Text('${r.roomName} - ${r.building}', style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.green.shade50,
                              side: BorderSide(color: Colors.green.shade200),
                            )).toList(),
                          ),
                        ),
                      ],
                      if (deptFaculties.isEmpty && deptSubjects.isEmpty && deptRooms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No data assigned to this department yet.', style: TextStyle(color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeptInfoChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDeptStatBadge(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildSubjectsView() {
    return FutureBuilder<List<dynamic>>(
      future: DataService.getSubjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        final subjects = snapshot.data ?? [];
        return SingleChildScrollView(
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
                  Text('Subject Management', style: Theme.of(context).textTheme.headlineSmall),
                  ElevatedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add new Subject'))),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                const spacing = 16.0;
                final cardWidth = (constraints.maxWidth - spacing * 2) / 3;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: subjects.map<Widget>((subject) {
                    return SizedBox(
                      width: cardWidth.clamp(280.0, double.infinity),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.orange.shade100,
                                    child: Icon(Icons.book, color: Colors.orange.shade700),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(subject.courseCode, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                                        const SizedBox(height: 2),
                                        Text(subject.subjectName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 2),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  _subjectInfoChip(Icons.school, '${subject.units} Units', Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(child: _subjectInfoChip(Icons.business, subject.departmentName ?? 'N/A', Colors.purple)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _subjectInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildRoomsView() {
    return FutureBuilder<List<dynamic>>(
      future: DataService.getRooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        final rooms = snapshot.data ?? [];
        return SingleChildScrollView(
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
                  Text('Room Management', style: Theme.of(context).textTheme.headlineSmall),
                  ElevatedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add new Room'))),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                const spacing = 16.0;
                final cardWidth = (constraints.maxWidth - spacing * 2) / 3;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: rooms.map<Widget>((room) {
                    return SizedBox(
                      width: cardWidth.clamp(280.0, double.infinity),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.green.shade100,
                                    child: Icon(Icons.meeting_room, color: Colors.green.shade700),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(room.roomName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(room.building, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  _roomInfoChip(Icons.people, 'Capacity: ${room.capacity ?? "N/A"}', Colors.blue),
                                  const SizedBox(width: 8),
                                  _roomInfoChip(Icons.devices, 'Devices: ${room.deviceCount ?? 0}', Colors.teal),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _roomInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSchedulesView() {
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
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        final schedules = snapshot.data![0] as List;
        final rooms = snapshot.data![1] as List;
        
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
          for (var day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']) {
            final dayList = roomData[day] as List<dynamic>;
            dayList.sort((a, b) => a.startTime.compareTo(b.startTime));
          }
        }

        return SingleChildScrollView(
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
                  Text('Schedule Management', style: Theme.of(context).textTheme.headlineSmall),
                  ElevatedButton.icon(
                    onPressed: () => _addTestSchedule(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Schedule'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Room cards with timetable
              ...schedulesByRoom.entries.map((entry) {
                final roomData = entry.value;
                final room = roomData['room'];
                final hasSchedules = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
                    .any((day) => (roomData[day] as List<dynamic>).isNotEmpty);
                
                if (!hasSchedules) return const SizedBox.shrink();
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.room, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${room?.roomName ?? "Unknown"} - ${room?.building ?? ""}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Capacity: ${room?.capacity ?? "-"}'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64),
                            child: Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          defaultVerticalAlignment: TableCellVerticalAlignment.top,
                          columnWidths: const {
                            0: FlexColumnWidth(1),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                            4: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade100),
                              children: const [
                                Padding(padding: EdgeInsets.all(12), child: Text('Monday', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Padding(padding: EdgeInsets.all(12), child: Text('Tuesday', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Padding(padding: EdgeInsets.all(12), child: Text('Wednesday', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Padding(padding: EdgeInsets.all(12), child: Text('Thursday', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Padding(padding: EdgeInsets.all(12), child: Text('Friday', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              ],
                            ),
                            ..._buildScheduleTableRows(roomData),
                          ],
                        ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  List<TableRow> _buildScheduleTableRows(Map<String, dynamic> roomData) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final maxSchedules = days.map((d) => (roomData[d] as List<dynamic>).length).reduce((a, b) => a > b ? a : b);
    
    if (maxSchedules == 0) return [];
    
    List<TableRow> rows = [];
    for (int i = 0; i < maxSchedules; i++) {
      rows.add(TableRow(
        children: days.map((day) {
          final daySchedules = roomData[day] as List<dynamic>;
          if (i < daySchedules.length) {
            final schedule = daySchedules[i];
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        schedule.timeRange,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      schedule.courseCode ?? schedule.subjectName ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      schedule.facultyName ?? '-',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: Text('-', style: TextStyle(color: Colors.grey))),
          );
        }).toList(),
      ));
    }
    return rows;
  }

  Widget _buildDevicesView() {
    return _buildCrudView(
      title: 'Device Management',
      fetchData: DataService.getDevices,
      columns: ['Type', 'Location', 'Room', 'Status'],
      getRowData: (device) => [
        device.deviceType,
        device.location,
        device.roomName ?? '-',
        device.status,
      ],
    );
  }

  Widget _buildReportsView() {
    return const ReportsScreen();
  }

  Widget _buildCrudView<T>({
    required String title,
    required Future<List<T>> Function() fetchData,
    required List<String> columns,
    required List<String> Function(T item) getRowData,
  }) {
    return FutureBuilder<List<T>>(
      future: fetchData(),
      builder: (context, snapshot) {
        return SingleChildScrollView(
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
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Add new $title item')),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                Center(
                  child: Text(
                    'Error loading data: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else if (!snapshot.hasData || snapshot.data!.isEmpty)
                const Center(child: Text('No data available'))
              else
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: columns
                          .map((col) => DataColumn(label: Text(col)))
                          .toList(),
                      rows: snapshot.data!.map((item) {
                        final rowData = getRowData(item);
                        return DataRow(
                          cells: rowData
                              .map((cell) => DataCell(Text(cell)))
                              .toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _addTestSchedule() async {
    try {
      // Create a test schedule with string FacultyID
      final scheduleData = {
        'FacultyID': '2026-001', // String FacultyID as required
        'SubjectID': 8,
        'RoomID': 8,
        'DayOfWeek': 'Tuesday',
        'StartTime': '09:00',
        'EndTime': '10:00',
      };

      print('Creating test schedule with data: $scheduleData');
      print('FacultyID type: ${scheduleData['FacultyID'].runtimeType}');

      await DataService.createSchedule(scheduleData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test schedule created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Note: You may need to refresh the page to see the new schedule
      }
    } catch (e) {
      print('Error creating test schedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
