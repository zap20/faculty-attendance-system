import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../widgets/app_drawer.dart';

class DepartmentHeadDashboardScreen extends StatefulWidget {
  const DepartmentHeadDashboardScreen({super.key});

  @override
  State<DepartmentHeadDashboardScreen> createState() => _DepartmentHeadDashboardScreenState();
}

class _DepartmentHeadDashboardScreenState extends State<DepartmentHeadDashboardScreen> {
  String _currentScreen = 'dept_dashboard';
  bool _loading = true;
  Map<String, dynamic> _summary = {};

  List<FacultyModel> _faculties = [];
  List<ScheduleModel> _schedules = [];
  List<SubjectModel> _subjects = [];
  List<RoomModel> _rooms = [];

  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  String? _selectedFacultyId;
  int? _selectedSubjectId;
  int? _selectedRoomId;
  Map<String, dynamic> _analytics = {};
  bool _analyticsLoading = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 6))),
    );
    _toController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        DataService.getDepartmentHeadDashboardSummary(),
        DataService.getFaculties(),
        DataService.getDepartmentHeadSchedules(),
        DataService.getSubjects(),
        DataService.getRooms(),
      ]);

      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _faculties = results[1] as List<FacultyModel>;
        _schedules = results[2] as List<ScheduleModel>;
        _subjects = results[3] as List<SubjectModel>;
        _rooms = results[4] as List<RoomModel>;
        _loading = false;
      });

      await _loadAnalytics();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _analyticsLoading = true);
    try {
      final data = await DataService.getDepartmentHeadAnalytics(
        from: _fromController.text.trim(),
        to: _toController.text.trim(),
        facultyId: (_selectedFacultyId != null && _selectedFacultyId!.isNotEmpty) ? _selectedFacultyId : null,
        subjectId: _selectedSubjectId,
        roomId: _selectedRoomId,
      );
      setState(() {
        _analytics = data;
        _analyticsLoading = false;
      });
    } catch (_) {
      setState(() => _analyticsLoading = false);
    }
  }

  void _handleDrawerSelection(String selection) {
    if (selection == 'logout') {
      context.read<AuthProvider>().logout();
      return;
    }

    Navigator.pop(context);
    setState(() {
      _currentScreen = selection;
    });
  }

  String _getScreenTitle() {
    switch (_currentScreen) {
      case 'dept_dashboard':
        return 'Department Dashboard';
      case 'dept_faculty':
        return 'Faculty';
      case 'dept_schedules':
        return 'Schedules';
      case 'dept_analytics':
        return 'Attendance Analytics';
      default:
        return 'Department Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
            onPressed: _loadAll,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                auth.user?.username ?? '',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentScreen) {
      case 'dept_dashboard':
        return _buildDashboard();
      case 'dept_faculty':
        return _buildFaculty();
      case 'dept_schedules':
        return _buildSchedules();
      case 'dept_analytics':
        return _buildAnalytics();
      default:
        return _buildDashboard();
    }
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final totalFaculty = (_summary['totalFaculty'] ?? 0).toString();
    final attendanceToday = (_summary['attendanceToday'] as Map?) ?? {};

    final present = (attendanceToday['present'] ?? 0).toString();
    final late = (attendanceToday['late'] ?? 0).toString();
    final wrongRoom = (attendanceToday['wrongRoom'] ?? 0).toString();
    final noSchedule = (attendanceToday['noSchedule'] ?? 0).toString();
    final absent = (attendanceToday['absent'] ?? 0).toString();

    final weeklyRateValue = _summary['weeklyAttendanceRate'];
    final weeklyRate = (weeklyRateValue is num ? weeklyRateValue.toDouble() : double.tryParse(weeklyRateValue?.toString() ?? '') ?? 0)
        .toStringAsFixed(1);
    final topExceptions = (_summary['topExceptions'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: 320, child: _kpiCard('Total Faculty', totalFaculty, Icons.people, Colors.blue)),
              SizedBox(width: 320, child: _kpiCard('Present Today', present, Icons.check_circle, Colors.green)),
              SizedBox(width: 320, child: _kpiCard('Late Today', late, Icons.schedule, Colors.orange)),
              SizedBox(width: 320, child: _kpiCard('Absent Today', absent, Icons.cancel, Colors.red)),
              SizedBox(width: 320, child: _kpiCard('Wrong Room', wrongRoom, Icons.room, Colors.purple)),
              SizedBox(width: 320, child: _kpiCard('No Schedule', noSchedule, Icons.event_busy, Colors.grey)),
              SizedBox(width: 320, child: _kpiCard('Weekly Attendance Rate', '$weeklyRate%', Icons.trending_up, Colors.teal)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Department Status Breakdown', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _analyticsLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              : _buildStatusBreakdownChart(),
          const SizedBox(height: 16),
          Text('Top Exceptions (last 7 days)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: topExceptions.isEmpty
                    ? [const Text('No exceptions found')]
                    : topExceptions
                        .map((e) => ListTile(
                              dense: true,
                              title: Text(e['AttendanceStatus']?.toString() ?? '-'),
                              trailing: Text((e['Count'] ?? 0).toString()),
                            ))
                        .toList()
                        .cast<Widget>(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdownChart() {
    final charts = (_analytics['charts'] as Map?) ?? {};
    final breakdown = (charts['statusBreakdown'] as List?) ?? [];

    if (breakdown.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('No data')));
    }

    final colors = <String, Color>{
      'Present': Colors.green,
      'Late': Colors.orange,
      'Wrong Room': Colors.purple,
      'No Schedule': Colors.grey,
      'Absent': Colors.red,
    };

    int parseCount(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    final total = breakdown.fold<int>(0, (sum, e) => sum + parseCount((e as Map)['Count']));

    final sections = breakdown.map((e) {
      final status = e['AttendanceStatus']?.toString() ?? 'Unknown';
      final count = parseCount(e['Count']);
      final value = count.toDouble();
      final pct = total > 0 ? (count / total) * 100 : 0;

      return PieChartSectionData(
        value: value,
        color: colors[status] ?? Colors.blueGrey,
        radius: 54,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: breakdown
                    .map((e) {
                      final status = e['AttendanceStatus']?.toString() ?? 'Unknown';
                      final count = parseCount(e['Count']).toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, color: colors[status] ?? Colors.blueGrey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(status)),
                            Text(count, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    })
                    .toList()
                    .cast<Widget>(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaculty() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Faculty in your department',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openCreateFacultyDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Create Faculty'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: _faculties.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final f = _faculties[i];
                  return ListTile(
                    title: Text(f.facultyName),
                    subtitle: Text('${f.position} • ${f.employmentStatus}'),
                    trailing: Text(f.facultyId),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateFacultyDialog() async {
    final facultyName = TextEditingController();
    final position = TextEditingController();
    final employmentStatus = TextEditingController();
    final contact = TextEditingController();
    final username = TextEditingController();
    final tempPassword = TextEditingController();

    Future<void> submit() async {
      Navigator.of(context).pop();

      try {
        final result = await DataService.departmentHeadCreateFacultyWithAccount(
          facultyName: facultyName.text.trim(),
          position: position.text.trim(),
          employmentStatus: employmentStatus.text.trim(),
          contactInformation: contact.text.trim().isEmpty ? null : contact.text.trim(),
          username: username.text.trim(),
          tempPassword: tempPassword.text,
        );

        final creds = (result['credentials'] as Map?) ?? {};
        await _loadAll();

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Generated credentials'),
            content: SelectableText(
              'Username: ${creds['username'] ?? ''}\nPassword: ${creds['tempPassword'] ?? ''}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create faculty'), backgroundColor: Colors.red),
        );
      }
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Faculty Account'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: facultyName, decoration: const InputDecoration(labelText: 'Faculty Name')),
                const SizedBox(height: 12),
                TextField(controller: position, decoration: const InputDecoration(labelText: 'Position')),
                const SizedBox(height: 12),
                TextField(controller: employmentStatus, decoration: const InputDecoration(labelText: 'Employment Status')),
                const SizedBox(height: 12),
                TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact Information (optional)')),
                const SizedBox(height: 12),
                TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 12),
                TextField(controller: tempPassword, decoration: const InputDecoration(labelText: 'Temporary Password')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: submit, child: const Text('Create')),
        ],
      ),
    );

    facultyName.dispose();
    position.dispose();
    employmentStatus.dispose();
    contact.dispose();
    username.dispose();
    tempPassword.dispose();
  }

  Widget _buildSchedules() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Schedules in your department',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openCreateScheduleDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Schedule'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: _schedules.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = _schedules[i];
                  return ListTile(
                    title: Text('${s.courseCode ?? ''} ${s.subjectName ?? ''}'.trim()),
                    subtitle: Text('${s.facultyName ?? s.facultyId} • ${s.dayOfWeek} • ${s.timeRange}'),
                    trailing: Text(s.roomInfo),
                    onTap: () => _openEditScheduleDialog(s),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateScheduleDialog() async {
    await _openScheduleDialog();
  }

  Future<void> _openEditScheduleDialog(ScheduleModel schedule) async {
    await _openScheduleDialog(existing: schedule);
  }

  Future<void> _openScheduleDialog({ScheduleModel? existing}) async {
    final dayController = TextEditingController(text: existing?.dayOfWeek ?? 'Monday');
    final startController = TextEditingController(text: existing?.startTime ?? '08:00:00');
    final endController = TextEditingController(text: existing?.endTime ?? '09:00:00');

    String selectedFacultyId = existing?.facultyId ?? (_faculties.isNotEmpty ? _faculties.first.facultyId : '');
    int selectedSubjectId = existing?.subjectId ?? 0;
    int selectedRoomId = existing?.roomId ?? 0;

    List<SubjectModel> subjects = [];
    List<RoomModel> rooms = [];

    try {
      subjects = await DataService.getSubjects();
      rooms = await DataService.getRooms();
      if (selectedSubjectId == 0 && subjects.isNotEmpty) selectedSubjectId = subjects.first.subjectId;
      if (selectedRoomId == 0 && rooms.isNotEmpty) selectedRoomId = rooms.first.roomId;
    } catch (_) {}

    Future<void> submit() async {
      Navigator.of(context).pop();

      final data = {
        'FacultyID': selectedFacultyId,
        'SubjectID': selectedSubjectId,
        'RoomID': selectedRoomId,
        'DayOfWeek': dayController.text.trim(),
        'StartTime': startController.text.trim(),
        'EndTime': endController.text.trim(),
      };

      try {
        if (existing == null) {
          await DataService.departmentHeadCreateSchedule(data);
        } else {
          await DataService.departmentHeadUpdateSchedule(existing.scheduleId, data);
        }
        await _loadAll();
      } on ApiException catch (e) {
        if (!mounted) return;
        final formatted = _formatApiErrors(e.errors);
        final msg = formatted.isNotEmpty ? formatted : e.message;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save schedule'), backgroundColor: Colors.red),
        );
      }
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Schedule' : 'Edit Schedule'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedFacultyId.isEmpty ? null : selectedFacultyId,
                  decoration: const InputDecoration(labelText: 'Faculty'),
                  items: _faculties
                      .map((f) => DropdownMenuItem(value: f.facultyId, child: Text('${f.facultyName} (${f.facultyId})')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) selectedFacultyId = v;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedSubjectId == 0 ? null : selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: subjects
                      .map((s) => DropdownMenuItem(value: s.subjectId, child: Text('${s.courseCode} - ${s.subjectName}')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) selectedSubjectId = v;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedRoomId == 0 ? null : selectedRoomId,
                  decoration: const InputDecoration(labelText: 'Room'),
                  items: rooms.map((r) => DropdownMenuItem(value: r.roomId, child: Text(r.fullName))).toList(),
                  onChanged: (v) {
                    if (v != null) selectedRoomId = v;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: dayController.text,
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                  items: const [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday'
                  ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) {
                    if (v != null) dayController.text = v;
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: startController, decoration: const InputDecoration(labelText: 'Start Time (HH:MM:SS)')),
                const SizedBox(height: 12),
                TextField(controller: endController, decoration: const InputDecoration(labelText: 'End Time (HH:MM:SS)')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: submit, child: const Text('Save')),
        ],
      ),
    );

    dayController.dispose();
    startController.dispose();
    endController.dispose();
  }

  Widget _buildAnalytics() {
    final charts = (_analytics['charts'] as Map?) ?? {};
    final trend = (charts['trendByDay'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'From (YYYY-MM-DD)'),
                  controller: _fromController,
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'To (YYYY-MM-DD)'),
                  controller: _toController,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadAnalytics,
                icon: const Icon(Icons.search),
                label: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String?>(
                  value: _selectedFacultyId,
                  decoration: const InputDecoration(labelText: 'Faculty (optional)'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('All Faculty')),
                    ..._faculties
                        .map((f) => DropdownMenuItem<String?>(
                              value: f.facultyId,
                              child: Text('${f.facultyName} (${f.facultyId})'),
                            ))
                        .toList(),
                  ],
                  onChanged: (v) => setState(() => _selectedFacultyId = v),
                ),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<int?>(
                  value: _selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Subject (optional)'),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(value: null, child: Text('All Subjects')),
                    ..._subjects
                        .map((s) => DropdownMenuItem<int?>(
                              value: s.subjectId,
                              child: Text('${s.courseCode} - ${s.subjectName}'),
                            ))
                        .toList(),
                  ],
                  onChanged: (v) => setState(() => _selectedSubjectId = v),
                ),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<int?>(
                  value: _selectedRoomId,
                  decoration: const InputDecoration(labelText: 'Room (optional)'),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(value: null, child: Text('All Rooms')),
                    ..._rooms
                        .map((r) => DropdownMenuItem<int?>(
                              value: r.roomId,
                              child: Text(r.fullName),
                            ))
                        .toList(),
                  ],
                  onChanged: (v) => setState(() => _selectedRoomId = v),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedFacultyId = null;
                    _selectedSubjectId = null;
                    _selectedRoomId = null;
                  });
                },
                child: const Text('Clear filters'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Status Breakdown', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _analyticsLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              : _buildStatusBreakdownChart(),
          const SizedBox(height: 16),
          Text('Trend', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: trend.isEmpty
                  ? const Text('No trend data')
                  : SizedBox(
                      height: 280,
                      child: _buildTrendChart(trend),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List trend) {
    final spots = <FlSpot>[];
    for (int i = 0; i < trend.length; i++) {
      final day = trend[i];
      final raw = day['Present'];
      final present = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0;
      spots.add(FlSpot(i.toDouble(), present));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                final date = trend[idx]['Date']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(date.length >= 10 ? date.substring(5) : date, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  String _formatApiErrors(dynamic errors) {
    if (errors == null) return '';

    if (errors is List) {
      return errors
          .map((x) {
            if (x is Map && x['message'] != null) return x['message'].toString();
            return x.toString();
          })
          .join('\n');
    }

    if (errors is Map) {
      return errors.values.map((v) => v.toString()).join('\n');
    }

    return errors.toString();
  }
}
