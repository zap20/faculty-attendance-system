import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_head_provider.dart';
import '../../services/data_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/sync_status_widget.dart';
import '../shared/reports_screen.dart';
import '../../widgets/auto_refresh_mixin.dart';

class DepartmentHeadDashboardScreen extends StatefulWidget {
  const DepartmentHeadDashboardScreen({super.key});

  @override
  State<DepartmentHeadDashboardScreen> createState() => _DepartmentHeadDashboardScreenState();
}

class _DepartmentHeadDashboardScreenState extends State<DepartmentHeadDashboardScreen> with AutoRefreshMixin {
  String _currentScreen = 'dept_head_dashboard';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAllData();
      startAutoRefresh(() => _silentRefresh());
    });
  }

  Future<void> _loadAllData() async {
    final provider = context.read<DepartmentHeadProvider>();
    await Future.wait([
      provider.loadDashboardSummary().catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dashboard load failed: $e'), backgroundColor: Colors.red),
          );
        }
      }),
      provider.loadFaculties().catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Faculty load failed: $e'), backgroundColor: Colors.red),
          );
        }
      }),
      provider.loadSchedules().catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Schedules load failed: $e'), backgroundColor: Colors.red),
          );
        }
      }),
    ]);
  }

  void _silentRefresh() {
    final provider = context.read<DepartmentHeadProvider>();
    provider.loadDashboardSummary().catchError((_) {});
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
      case 'dept_head_dashboard':
        return 'Department Dashboard';
      case 'dept_head_faculty':
        return 'Faculty Management';
      case 'dept_head_schedules':
        return 'Schedule Management';
      case 'dept_head_reports':
        return 'Reports';
      default:
        return 'Department Dashboard';
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
          if (!kIsWeb) const SyncStatusWidget(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final provider = context.read<DepartmentHeadProvider>();
              if (_currentScreen == 'dept_head_dashboard') {
                await provider.loadDashboardSummary();
              } else if (_currentScreen == 'dept_head_faculty') {
                await provider.loadFaculties();
              } else if (_currentScreen == 'dept_head_schedules') {
                await provider.loadSchedules();
              } else if (_currentScreen == 'dept_head_analytics') {
                await provider.loadAnalytics();
              }
            },
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentScreen) {
      case 'dept_head_dashboard':
        return const _DepartmentHeadOverviewView();
      case 'dept_head_faculty':
        return const _DepartmentHeadFacultyView();
      case 'dept_head_schedules':
        return const _DepartmentHeadSchedulesView();
      case 'dept_head_reports':
        return const ReportsScreen();
      default:
        return const _DepartmentHeadOverviewView();
    }
  }
}

class _DepartmentHeadOverviewView extends StatefulWidget {
  const _DepartmentHeadOverviewView();

  @override
  State<_DepartmentHeadOverviewView> createState() => _DepartmentHeadOverviewViewState();
}

class _DepartmentHeadOverviewViewState extends State<_DepartmentHeadOverviewView> {
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    _toDate = DateTime.now();
    _fromDate = _toDate.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final from = DateFormat('yyyy-MM-dd').format(_fromDate);
    final to = DateFormat('yyyy-MM-dd').format(_toDate);
    context.read<DepartmentHeadProvider>().loadAnalytics(from: from, to: to);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DepartmentHeadProvider>();

    if (provider.loadingDashboard) {
      return const Center(child: CircularProgressIndicator());
    }

    final kpis = provider.dashboardSummary['kpis'] ?? {};
    final date = provider.dashboardSummary['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview ($date)', style: Theme.of(context).textTheme.headlineSmall),
          // Analytics Section
          const SizedBox(height: 32),
          // Date Range Filter
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range, size: 20),
                      const SizedBox(width: 8),
                      Text('${DateFormat('MMM d, yyyy').format(_fromDate)}  —  ${DateFormat('MMM d, yyyy').format(_toDate)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (provider.loadingAnalytics)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else ...[
            // Analytics KPI Cards
            _buildAnalyticsKpiCards(provider.analytics, kpis),
            const SizedBox(height: 24),

            // Row: Pie Chart + Trend Line Chart
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 800;
              final children = [
                _buildAnalyticsStatusPieChart(provider.analytics),
                _buildAnalyticsAttendanceTrendChart(provider.analytics),
              ];
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: c))).toList(),
                );
              }
              return Column(children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)).toList());
            }),
            const SizedBox(height: 16),

            // Faculty Ranking
            _buildAnalyticsFacultyRanking(provider.analytics),
            const SizedBox(height: 16),

            // Room Utilization
            _buildAnalyticsRoomUtilization(provider.analytics),
          ],
        ],
      ),
    );
  }

  // Analytics helper methods (moved from analytics view)
  Widget _buildAnalyticsKpiCards(Map<String, dynamic> analytics, Map<dynamic, dynamic> dashboardKpis) {
    final aKpis = (analytics['kpis'] as Map?) ?? {};

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final cols = isMobile ? 2 : (constraints.maxWidth < 900 ? 3 : 6);
      const spacing = 12.0;
      final cardWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          SizedBox(width: cardWidth, child: _StatCard(title: 'Total Faculty', value: '${aKpis['totalFaculty'] ?? 0}', icon: Icons.people, color: Colors.blue)),
          SizedBox(width: cardWidth, child: _StatCard(title: 'Scheduled Sessions', value: '${aKpis['totalScheduledSessions'] ?? 0}', icon: Icons.calendar_today, color: Colors.indigo)),
          SizedBox(width: cardWidth, child: _StatCardDual(
            title: 'Present',
            value: '${aKpis['totalPresent'] ?? 0}',
            todayValue: '${dashboardKpis['presentToday'] ?? 0}',
            icon: Icons.check_circle,
            color: Colors.green,
          )),
          SizedBox(width: cardWidth, child: _StatCardDual(
            title: 'Late',
            value: '${aKpis['totalLate'] ?? 0}',
            todayValue: '${dashboardKpis['lateToday'] ?? 0}',
            icon: Icons.access_time,
            color: Colors.orange,
          )),
          SizedBox(width: cardWidth, child: _StatCard(title: 'Absent Today', value: '${dashboardKpis['absentToday'] ?? 0}', icon: Icons.cancel, color: Colors.red)),
          SizedBox(width: cardWidth, child: _StatCard(title: 'Attendance Rate', value: '${aKpis['attendanceRate'] ?? 0}%', icon: Icons.trending_up, color: Colors.teal)),
        ],
      );
    });
  }

  Widget _buildAnalyticsStatusPieChart(Map<String, dynamic> analytics) {
    final breakdown = (analytics['statusBreakdown'] as List?) ?? [];
    final sections = breakdown.map((e) {
      final m = e as Map;
      return MapEntry(m['status']?.toString() ?? '', (m['count'] as num?)?.toDouble() ?? 0);
    }).toList();
    final total = sections.fold<double>(0, (sum, e) => sum + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status Distribution', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: total <= 0
                  ? const Center(child: Text('No attendance data for this period'))
                  : PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(sections.length, (i) {
                        final item = sections[i];
                        final color = _statusColors[item.key] ?? Colors.grey;
                        final pct = total == 0 ? 0.0 : (item.value / total) * 100;
                        return PieChartSectionData(
                          value: item.value,
                          title: '${pct.toStringAsFixed(0)}%',
                          color: color,
                          radius: 55,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }),
                    )),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: sections.map((e) {
                final color = _statusColors[e.key] ?? Colors.grey;
                return _LegendChip(label: '${e.key}: ${e.value.toInt()}', color: color);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsAttendanceTrendChart(Map<String, dynamic> analytics) {
    final trend = (analytics['attendanceTrend'] as List?) ?? [];
    if (trend.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attendance Trend', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 48),
              const Center(child: Text('No trend data for this period')),
              const SizedBox(height: 48),
            ],
          ),
        ),
      );
    }

    final presentSpots = <FlSpot>[];
    final lateSpots = <FlSpot>[];
    final labels = <String>[];

    for (int i = 0; i < trend.length; i++) {
      final m = trend[i] as Map;
      labels.add((m['date']?.toString() ?? '').substring(5)); // MM-DD
      presentSpots.add(FlSpot(i.toDouble(), (m['present'] as num?)?.toDouble() ?? 0));
      lateSpots.add(FlSpot(i.toDouble(), (m['late'] as num?)?.toDouble() ?? 0));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance Trend', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: math.max(1, (labels.length / 6).ceilToDouble()),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[idx], style: const TextStyle(fontSize: 9)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: presentSpots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 2,
                    dotData: FlDotData(show: presentSpots.length < 15),
                    belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
                  ),
                  LineChartBarData(
                    spots: lateSpots,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 2,
                    dotData: FlDotData(show: lateSpots.length < 15),
                    belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
                  ),
                ],
              )),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _LegendChip(label: 'Present', color: Colors.green),
                SizedBox(width: 12),
                _LegendChip(label: 'Late', color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsFacultyRanking(Map<String, dynamic> analytics) {
    final ranking = (analytics['facultyRanking'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Faculty Performance Ranking', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (ranking.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No data')))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Faculty')),
                    DataColumn(label: Text('Sessions'), numeric: true),
                    DataColumn(label: Text('Present'), numeric: true),
                    DataColumn(label: Text('Late'), numeric: true),
                    DataColumn(label: Text('Exceptions'), numeric: true),
                    DataColumn(label: Text('Rate'), numeric: true),
                  ],
                  rows: List.generate(ranking.length, (i) {
                    final r = ranking[i] as Map;
                    final rate = (r['attendanceRate'] as num?)?.toDouble() ?? 0;
                    final rateColor = rate >= 80 ? Colors.green : (rate >= 50 ? Colors.orange : Colors.red);
                    return DataRow(cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(Text(r['FacultyName']?.toString() ?? '')),
                      DataCell(Text('${r['totalSessions'] ?? 0}')),
                      DataCell(Text('${r['presentCount'] ?? 0}')),
                      DataCell(Text('${r['lateCount'] ?? 0}')),
                      DataCell(Text('${r['exceptionCount'] ?? 0}')),
                      DataCell(Text('${rate.toStringAsFixed(1)}%', style: TextStyle(color: rateColor, fontWeight: FontWeight.bold))),
                    ]);
                  }),
                ),
              ),
            if (ranking.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= ranking.length) return const SizedBox.shrink();
                          final name = (ranking[idx] as Map)['FacultyName']?.toString() ?? '';
                          final short = name.length > 10 ? '${name.substring(0, 10)}...' : name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(short, style: const TextStyle(fontSize: 9)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  maxY: 100,
                  barGroups: List.generate(ranking.length, (i) {
                    final rate = ((ranking[i] as Map)['attendanceRate'] as num?)?.toDouble() ?? 0;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: rate,
                        color: rate >= 80 ? Colors.green : (rate >= 50 ? Colors.orange : Colors.red),
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]);
                  }),
                )),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsRoomUtilization(Map<String, dynamic> analytics) {
    final rooms = (analytics['roomUtilization'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room Utilization', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (rooms.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No room data')))
            else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Room')),
                    DataColumn(label: Text('Building')),
                    DataColumn(label: Text('Scheduled'), numeric: true),
                    DataColumn(label: Text('Recorded'), numeric: true),
                    DataColumn(label: Text('Util. Rate'), numeric: true),
                  ],
                  rows: rooms.map((e) {
                    final r = e as Map;
                    final rate = (r['utilizationRate'] as num?)?.toDouble() ?? 0;
                    return DataRow(cells: [
                      DataCell(Text(r['RoomName']?.toString() ?? '')),
                      DataCell(Text(r['Building']?.toString() ?? '')),
                      DataCell(Text('${r['scheduledSessions'] ?? 0}')),
                      DataCell(Text('${r['attendanceRecorded'] ?? 0}')),
                      DataCell(Text('${rate.toStringAsFixed(1)}%', style: TextStyle(
                        color: rate >= 60 ? Colors.green : (rate >= 30 ? Colors.orange : Colors.red),
                        fontWeight: FontWeight.bold,
                      ))),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= rooms.length) return const SizedBox.shrink();
                          final name = (rooms[idx] as Map)['RoomName']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(name, style: const TextStyle(fontSize: 9)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(rooms.length, (i) {
                    final r = rooms[i] as Map;
                    final scheduled = (r['scheduledSessions'] as num?)?.toDouble() ?? 0;
                    final recorded = (r['attendanceRecorded'] as num?)?.toDouble() ?? 0;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: scheduled, color: Colors.blue.shade300, width: 12, borderRadius: BorderRadius.circular(3)),
                      BarChartRodData(toY: recorded, color: Colors.green, width: 12, borderRadius: BorderRadius.circular(3)),
                    ]);
                  }),
                )),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendChip(label: 'Scheduled', color: Colors.blue.shade300),
                  const SizedBox(width: 12),
                  const _LegendChip(label: 'Recorded', color: Colors.green),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _statusColors = {
    'Present': Colors.green,
    'Late': Colors.orange,
    'No Schedule': Colors.purple,
    'Wrong Room': Colors.red,
  };
}

class _DepartmentHeadFacultyView extends StatefulWidget {
  const _DepartmentHeadFacultyView();

  @override
  State<_DepartmentHeadFacultyView> createState() => _DepartmentHeadFacultyViewState();
}

class _DepartmentHeadFacultyViewState extends State<_DepartmentHeadFacultyView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _positionController = TextEditingController();
  final _statusController = TextEditingController(text: 'Full-Time');
  final _contactController = TextEditingController();
  final _usernameController = TextEditingController();
  final _tempPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _statusController.dispose();
    _contactController.dispose();
    _usernameController.dispose();
    _tempPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<DepartmentHeadProvider>();

    try {
      final result = await provider.createFaculty(
        facultyName: _nameController.text.trim(),
        position: _positionController.text.trim(),
        employmentStatus: _statusController.text.trim(),
        contactInformation: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
        username: _usernameController.text.trim(),
        tempPassword: _tempPasswordController.text.trim().isEmpty ? null : _tempPasswordController.text.trim(),
      );

      if (!mounted) return;
      final creds = (result['credentials'] as Map?) ?? {};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created. Username: ${creds['username'] ?? ''} Password: ${creds['tempPassword'] ?? ''}'),
          backgroundColor: Colors.green,
        ),
      );

      _nameController.clear();
      _positionController.clear();
      _contactController.clear();
      _usernameController.clear();
      _tempPasswordController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DepartmentHeadProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Faculty (with user account)', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final fieldWidth = isMobile ? constraints.maxWidth : 260.0;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Faculty Name'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? fieldWidth : 220.0,
                            child: TextFormField(
                              controller: _positionController,
                              decoration: const InputDecoration(labelText: 'Position'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? fieldWidth : 220.0,
                            child: TextFormField(
                              controller: _statusController,
                              decoration: const InputDecoration(labelText: 'Employment Status'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _contactController,
                              decoration: const InputDecoration(labelText: 'Contact Information'),
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? fieldWidth : 220.0,
                            child: TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(labelText: 'Username'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? fieldWidth : 220.0,
                            child: TextFormField(
                              controller: _tempPasswordController,
                              decoration: const InputDecoration(labelText: 'Temp Password (optional)'),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Create Faculty'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Faculty List', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (provider.loadingFaculties)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Faculty ID')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Position')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: provider.faculties
                      .map(
                        (f) => DataRow(cells: [
                          DataCell(Text(f.facultyId)),
                          DataCell(Text(f.facultyName)),
                          DataCell(Text(f.position)),
                          DataCell(Text(f.employmentStatus)),
                        ]),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DepartmentHeadSchedulesView extends StatefulWidget {
  const _DepartmentHeadSchedulesView();

  @override
  State<_DepartmentHeadSchedulesView> createState() => _DepartmentHeadSchedulesViewState();
}

class _DepartmentHeadSchedulesViewState extends State<_DepartmentHeadSchedulesView> {
  final _formKey = GlobalKey<FormState>();
  String? _facultyId;
  String? _filterFacultyId;
  int? _subjectId;
  int? _roomId;
  String _dayOfWeek = 'Monday';
  final _startTimeController = TextEditingController(text: '08:00:00');
  final _endTimeController = TextEditingController(text: '10:00:00');

  final Map<int, TransformationController> _zoomControllers = {};

  List<SubjectModel> _subjects = [];
  List<RoomModel> _rooms = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final authProvider = context.read<AuthProvider>();
        final deptId = authProvider.user?.departmentId;
        final results = await Future.wait([
          DataService.getSubjects(departmentId: deptId),
          DataService.getRooms(),
        ]);
        if (!mounted) return;
        setState(() {
          _subjects = results[0] as List<SubjectModel>;
          _rooms = results[1] as List<RoomModel>;
        });
      } catch (e) {
        // Data not available offline
        if (!mounted) return;
        setState(() {
          _subjects = [];
          _rooms = [];
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    _zoomControllers.clear();
    _startTimeController.dispose();
    _endTimeController.dispose();
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

  int _parseHour(String time) {
    try {
      final parts = time.split(':');
      if (parts.isNotEmpty) {
        String hourStr = parts[0];
        final hourMatch = RegExp(r'(\d+)').firstMatch(hourStr);
        if (hourMatch != null) {
          int hour = int.parse(hourMatch.group(1)!);
          if (time.toLowerCase().contains('pm') && hour < 12) {
            hour += 12;
          } else if (time.toLowerCase().contains('am') && hour == 12) {
            hour = 0;
          }
          return hour;
        }
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    try {
      final parts = time.split(':');
      if (parts.length < 2) return time;
      int hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    } catch (e) {
      return time;
    }
  }

  int _parseMinute(String time) {
    try {
      final parts = time.split(':');
      if (parts.length > 1) {
        String minuteStr = parts[1];
        minuteStr = minuteStr.replaceAll(RegExp(r'[^0-9]'), '');
        return int.tryParse(minuteStr) ?? 0;
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }

  List<String> _generateTimeSlots() {
    final slots = <String>[];
    for (int hour = 7; hour <= 21; hour++) {
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      slots.add('${displayHour.toString().padLeft(2, '0')}:00 $period');
      if (hour < 21) {
        slots.add('${displayHour.toString().padLeft(2, '0')}:30 $period');
      }
    }
    return slots;
  }

  Widget _buildZoomableScheduleGrid(BuildContext context, int roomId, Map<String, dynamic> roomData) {
    final isMobile = !kIsWeb && MediaQuery.of(context).size.width < 600;
    final initialScale = isMobile ? 0.85 : 1.0;
    final viewportWidth = MediaQuery.of(context).size.width;
    const dayCount = 7;
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

    final existing = _zoomControllers[roomId];
    final controller = existing ?? TransformationController(Matrix4.identity()..scale(initialScale));
    if (existing == null) {
      _zoomControllers[roomId] = controller;
    }

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
                child: _buildTimeGridSchedule(context, roomData),
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

  Widget _buildTimeGridSchedule(BuildContext context, Map<String, dynamic> roomData) {
    final timeSlots = _generateTimeSlots();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    final Map<String, Map<String, dynamic>> mergedSchedules = {};
    for (final day in days) {
      mergedSchedules[day] = {};
      final daySchedules = (roomData[day] as List<ScheduleModel>?) ?? <ScheduleModel>[];

      for (final schedule in daySchedules) {
        final startTime = schedule.startTime;
        final endTime = schedule.endTime;
        final subjectName = schedule.subjectName ?? '';
        final facultyName = schedule.facultyName ?? schedule.facultyId;
        final courseCode = schedule.courseCode ?? '';

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
          };
        }
      }
    }

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 60),
            const SizedBox(width: 4),
            ...days.map(
              (day) => Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    day.substring(0, 3),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildMainContent(mergedSchedules, timeSlots, days),
      ],
    );
  }

  Widget _buildMainContent(Map<String, Map<String, dynamic>> mergedSchedules, List<String> timeSlots, List<String> days) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 60, child: _buildTimeTable(timeSlots)),
        const SizedBox(width: 4),
        Expanded(child: _buildScheduleTable(mergedSchedules, timeSlots, days)),
      ],
    );
  }

  Widget _buildTimeTable(List<String> timeSlots) {
    return Column(
      children: timeSlots.asMap().entries.map((entry) {
        final index = entry.key;
        final timeSlot = entry.value;
        return _buildTimeCell(timeSlot, height: 30, addBottomGap: index != timeSlots.length - 1);
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
          style: TextStyle(fontSize: 8, color: Colors.grey[700], fontWeight: FontWeight.w500),
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

            scheduleBlocks.add(
              Positioned(
                top: top,
                left: dayIndex * dayWidth,
                width: dayWidth,
                height: height,
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: _buildScheduleBlock(context, scheduleData),
                ),
              ),
            );
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
                        ...days.map(
                          (_) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              height: cellHeight,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade200, width: 0.5),
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildScheduleBlock(BuildContext context, Map<String, dynamic> scheduleData) {
    final startTime = scheduleData['startTime'] as String;
    final endTime = scheduleData['endTime'] as String;
    final facultyName = scheduleData['facultyName'] as String;
    final courseCode = (scheduleData['courseCode'] as String?) ?? '';
    final subjectName = (scheduleData['subjectName'] as String?) ?? '';
    final schedule = scheduleData['schedule'] as ScheduleModel;

    final title = courseCode.isNotEmpty ? courseCode : subjectName;
    final displayStart = _formatTime(startTime);
    final displayEnd = _formatTime(endTime);

    return GestureDetector(
      onLongPress: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete schedule?'),
            content: Text('$courseCode\n$facultyName\n$startTime - $endTime'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
        try {
          await context.read<DepartmentHeadProvider>().deleteSchedule(schedule.scheduleId);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deleted'), backgroundColor: Colors.green),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      },
      child: Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.length > 8 ? '${title.substring(0, 8)}...' : title,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                '$displayStart - $displayEnd',
                style: TextStyle(fontSize: 6, color: Colors.blue[600], fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                facultyName,
                style: TextStyle(fontSize: 6, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.read<DepartmentHeadProvider>().createSchedule({
        'FacultyID': _facultyId,
        'SubjectID': _subjectId,
        'RoomID': _roomId,
        'DayOfWeek': _dayOfWeek,
        'StartTime': _startTimeController.text.trim(),
        'EndTime': _endTimeController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule created'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DepartmentHeadProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Schedule', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final fieldWidth = isMobile ? constraints.maxWidth : 260.0;
                      final smallFieldWidth = isMobile ? (constraints.maxWidth - 16) / 2 : 160.0;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: DropdownButtonFormField<String>(
                              value: _facultyId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Faculty'),
                              items: provider.faculties
                                  .map((f) => DropdownMenuItem(value: f.facultyId, child: Text('${f.facultyName} (${f.facultyId})', overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (v) => setState(() => _facultyId = v),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: DropdownButtonFormField<int>(
                              value: _subjectId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Subject'),
                              items: _subjects
                                  .map((s) => DropdownMenuItem(value: s.subjectId, child: Text('${s.courseCode} - ${s.subjectName}', overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (v) => setState(() => _subjectId = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: DropdownButtonFormField<int>(
                              value: _roomId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Room'),
                              items: _rooms
                                  .map((r) => DropdownMenuItem(value: r.roomId, child: Text('${r.roomName} (${r.building})', overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (v) => setState(() => _roomId = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? fieldWidth : 180.0,
                            child: DropdownButtonFormField<String>(
                              value: _dayOfWeek,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Day'),
                              items: const [
                                DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                                DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday')),
                                DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday')),
                                DropdownMenuItem(value: 'Thursday', child: Text('Thursday')),
                                DropdownMenuItem(value: 'Friday', child: Text('Friday')),
                                DropdownMenuItem(value: 'Saturday', child: Text('Saturday')),
                                DropdownMenuItem(value: 'Sunday', child: Text('Sunday')),
                              ],
                              onChanged: (v) => setState(() => _dayOfWeek = v ?? 'Monday'),
                            ),
                          ),
                          SizedBox(
                            width: smallFieldWidth,
                            child: TextFormField(
                              controller: _startTimeController,
                              decoration: const InputDecoration(labelText: 'Start (HH:MM:SS)'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          SizedBox(
                            width: smallFieldWidth,
                            child: TextFormField(
                              controller: _endTimeController,
                              decoration: const InputDecoration(labelText: 'End (HH:MM:SS)'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Create'),
                    )
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Schedules', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return SizedBox(
              width: isMobile ? constraints.maxWidth : 320,
              child: DropdownButtonFormField<String>(
                value: _filterFacultyId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Filter by Faculty (optional)'),
                items: [
                  DropdownMenuItem<String>(value: null, child: const Text('All Faculty')),
                  ...provider.faculties.map(
                    (f) => DropdownMenuItem(
                      value: f.facultyId,
                      child: Text('${f.facultyName} (${f.facultyId})', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) async {
                  setState(() => _filterFacultyId = v);
                  try {
                    await context.read<DepartmentHeadProvider>().loadSchedules(facultyId: v);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
            );
          }),
          const SizedBox(height: 8),
          if (provider.loadingSchedules)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else
            Builder(
              builder: (context) {
                final today = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

                if (provider.schedules.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.schedule, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No schedules found'),
                        ],
                      ),
                    ),
                  );
                }

                final Map<int, RoomModel?> roomById = {
                  for (final r in _rooms) r.roomId: r,
                };

                final Map<int, Map<String, dynamic>> schedulesByRoom = {};
                void ensureRoom(int roomId) {
                  if (schedulesByRoom.containsKey(roomId)) return;
                  schedulesByRoom[roomId] = {
                    'room': roomById[roomId],
                    'Monday': <ScheduleModel>[],
                    'Tuesday': <ScheduleModel>[],
                    'Wednesday': <ScheduleModel>[],
                    'Thursday': <ScheduleModel>[],
                    'Friday': <ScheduleModel>[],
                    'Saturday': <ScheduleModel>[],
                    'Sunday': <ScheduleModel>[],
                  };
                }

                for (final s in provider.schedules) {
                  ensureRoom(s.roomId);
                  final dayList = schedulesByRoom[s.roomId]?[s.dayOfWeek];
                  if (dayList is List<ScheduleModel>) {
                    dayList.add(s);
                  }
                }

                for (final roomData in schedulesByRoom.values) {
                  for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']) {
                    final dayList = roomData[day] as List<ScheduleModel>;
                    dayList.sort((a, b) => a.startTime.compareTo(b.startTime));
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Column(
                        children: [
                          Text(today, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Weekly Schedule View', style: TextStyle(color: Colors.grey[700])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...schedulesByRoom.entries.map((entry) {
                      final roomId = entry.key;
                      final roomData = entry.value;
                      final room = roomData['room'] as RoomModel?;
                      final hasSchedules = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                          .any((day) => (roomData[day] as List<ScheduleModel>).isNotEmpty);
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
                                      room != null ? '${room.roomName} - ${room.building}' : 'Room $roomId',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (room != null) Text('Capacity: ${room.capacity}'),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildZoomableScheduleGrid(context, roomId, roomData),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _StatCardDual extends StatelessWidget {
  final String title;
  final String value;
  final String todayValue;
  final IconData icon;
  final Color color;

  const _StatCardDual({required this.title, required this.value, required this.todayValue, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13), overflow: TextOverflow.ellipsis)),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 26),
                Expanded(child: Text('$title Today', style: TextStyle(color: Colors.grey[600], fontSize: 12), overflow: TextOverflow.ellipsis)),
                Text(todayValue, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
