import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../widgets/app_drawer.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _currentScreen = 'admin_dashboard';
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
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
      setState(() => _isLoading = false);
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                authProvider.user?.username ?? '',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
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
        return _buildDashboardView();
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
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard(
                'Total Faculty',
                '${stats['totalFaculty'] ?? 0}',
                Icons.people,
                Colors.blue,
              ),
              _buildStatCard(
                'Departments',
                '${stats['totalDepartments'] ?? 0}',
                Icons.business,
                Colors.purple,
              ),
              _buildStatCard(
                'Present Today',
                '${stats['presentToday'] ?? 0}',
                Icons.check_circle,
                Colors.green,
              ),
              _buildStatCard(
                'Late Today',
                '${stats['lateToday'] ?? 0}',
                Icons.access_time,
                Colors.orange,
              ),
            ],
          ),
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
        width: 200,
        padding: const EdgeInsets.all(20),
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
    return _buildCrudView(
      title: 'Department Management',
      fetchData: DataService.getDepartments,
      columns: ['Name', 'Head', 'Dean', 'Faculty Count'],
      getRowData: (dept) => [
        dept.departmentName,
        dept.departmentHead ?? '-',
        dept.departmentDean ?? '-',
        '${dept.facultyCount ?? 0}',
      ],
    );
  }

  Widget _buildSubjectsView() {
    return _buildCrudView(
      title: 'Subject Management',
      fetchData: DataService.getSubjects,
      columns: ['Code', 'Name', 'Units', 'Department'],
      getRowData: (subject) => [
        subject.courseCode,
        subject.subjectName,
        '${subject.units}',
        subject.departmentName ?? '-',
      ],
    );
  }

  Widget _buildRoomsView() {
    return _buildCrudView(
      title: 'Room Management',
      fetchData: DataService.getRooms,
      columns: ['Name', 'Building', 'Capacity', 'Devices'],
      getRowData: (room) => [
        room.roomName,
        room.building,
        '${room.capacity ?? "-"}',
        '${room.deviceCount ?? 0}',
      ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            Text(
                              '${room?.roomName ?? "Unknown"} - ${room?.building ?? ""}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text('Capacity: ${room?.capacity ?? "-"}'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Reports',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Generate Report',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Daily summary report feature')),
                          );
                        },
                        icon: const Icon(Icons.today),
                        label: const Text('Daily Summary'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Department report feature')),
                          );
                        },
                        icon: const Icon(Icons.business),
                        label: const Text('Department Report'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Faculty report feature')),
                          );
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('Faculty Report'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
