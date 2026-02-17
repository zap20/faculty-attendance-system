import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/analytics_service.dart';
import '../../services/data_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  // Filters
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  int? _selectedDepartmentId;
  String? _selectedFacultyId;

  // Data
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _deptComparison = [];
  List<Map<String, dynamic>> _deptRanking = [];
  List<Map<String, dynamic>> _trend = [];
  List<Map<String, dynamic>> _heatmap = [];
  List<Map<String, dynamic>> _roomUtil = [];
  List<Map<String, dynamic>> _facultyPerf = [];

  // Filter options
  List<dynamic> _departments = [];
  List<dynamic> _faculties = [];

  bool _isLoading = true;
  String? _error;

  String get _fromStr => DateFormat('yyyy-MM-dd').format(_dateRange.start);
  String get _toStr => DateFormat('yyyy-MM-dd').format(_dateRange.end);

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _loadAllData();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final depts = await DataService.getDepartments();
      final facs = await DataService.getFaculties();
      if (mounted) setState(() { _departments = depts; _faculties = facs; });
    } catch (_) {}
  }

  Future<void> _loadAllData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        AnalyticsService.getSummary(
          from: _fromStr, to: _toStr,
          departmentId: _selectedDepartmentId,
          facultyId: _selectedFacultyId,
        ),
        AnalyticsService.getDepartmentComparison(from: _fromStr, to: _toStr),
        AnalyticsService.getDepartmentRanking(from: _fromStr, to: _toStr),
        AnalyticsService.getAttendanceTrend(
          from: _fromStr, to: _toStr,
          departmentId: _selectedDepartmentId,
          facultyId: _selectedFacultyId,
        ),
        AnalyticsService.getExceptionHeatmap(from: _fromStr, to: _toStr),
        AnalyticsService.getRoomUtilization(from: _fromStr, to: _toStr),
        AnalyticsService.getFacultyPerformance(
          from: _fromStr, to: _toStr,
          departmentId: _selectedDepartmentId,
        ),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>;
          _deptComparison = results[1] as List<Map<String, dynamic>>;
          _deptRanking = results[2] as List<Map<String, dynamic>>;
          _trend = results[3] as List<Map<String, dynamic>>;
          _heatmap = results[4] as List<Map<String, dynamic>>;
          _roomUtil = results[5] as List<Map<String, dynamic>>;
          _facultyPerf = results[6] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
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
      _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(),
            ))
          else if (_error != null)
            Center(child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
                ],
              ),
            ))
          else ...[
            _buildKpiSection(),
            const SizedBox(height: 24),
            _buildChartsRow1(),
            const SizedBox(height: 24),
            _buildChartsRow2(),
            const SizedBox(height: 24),
            _buildDeptRankingTable(),
            const SizedBox(height: 24),
            _buildFacultyPerformanceTable(),
          ],
        ],
      ),
    );
  }

  // ─── FILTERS ─────────────────────────────────
  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Date range
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(
                '${DateFormat('MMM d, yyyy').format(_dateRange.start)} — ${DateFormat('MMM d, yyyy').format(_dateRange.end)}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            // Department filter
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                initialValue: _selectedDepartmentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Departments')),
                  ..._departments.map((d) => DropdownMenuItem(
                    value: d.departmentId as int,
                    child: Text(d.departmentName, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) { setState(() => _selectedDepartmentId = v); _loadAllData(); },
              ),
            ),
            // Faculty filter
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedFacultyId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Faculty',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Faculty')),
                  ..._faculties.map((f) => DropdownMenuItem(
                    value: f.facultyId as String,
                    child: Text(f.facultyName, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) { setState(() => _selectedFacultyId = v); _loadAllData(); },
              ),
            ),
            // Refresh
            IconButton(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  // ─── KPI CARDS ───────────────────────────────
  Widget _buildKpiSection() {
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 12.0;
      final cardWidth = (constraints.maxWidth - spacing * 5) / 6;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          _kpiCard('Total Departments', '${_summary['totalDepartments'] ?? 0}', Icons.business, Colors.indigo, cardWidth),
          _kpiCard('Total Faculty', '${_summary['totalFaculty'] ?? 0}', Icons.people, Colors.blue, cardWidth),
          _kpiCard('Attendance Rate', '${_summary['globalAttendanceRate'] ?? 0}%', Icons.check_circle, Colors.green, cardWidth),
          _kpiCard('Late', '${_summary['totalLate'] ?? 0}', Icons.access_time, Colors.orange, cardWidth),
          _kpiCard('Exceptions', '${_summary['totalExceptions'] ?? 0}', Icons.warning_amber, Colors.red, cardWidth),
          _kpiCard('Active Devices', '${_summary['totalActiveDevices'] ?? 0}', Icons.devices, Colors.teal, cardWidth),
        ],
      );
    });
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, double width) {
    return SizedBox(
      width: width.clamp(140.0, double.infinity),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 28),
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CHARTS ROW 1: Pie + Bar ─────────────────
  Widget _buildChartsRow1() {
    return LayoutBuilder(builder: (context, constraints) {
      final halfWidth = (constraints.maxWidth - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(width: halfWidth.clamp(300.0, double.infinity), child: _buildPieChart()),
          SizedBox(width: halfWidth.clamp(300.0, double.infinity), child: _buildDeptBarChart()),
        ],
      );
    });
  }

  Widget _buildPieChart() {
    final present = (_summary['totalPresent'] ?? 0).toDouble();
    final late = (_summary['totalLate'] ?? 0).toDouble();
    final exceptions = (_summary['totalExceptions'] ?? 0).toDouble();
    final total = present + late + exceptions;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance Status Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: total == 0
                  ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                  : Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(value: present, title: '${(present / total * 100).toStringAsFixed(1)}%', color: Colors.green, radius: 50, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                PieChartSectionData(value: late, title: '${(late / total * 100).toStringAsFixed(1)}%', color: Colors.orange, radius: 50, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                PieChartSectionData(value: exceptions, title: '${(exceptions / total * 100).toStringAsFixed(1)}%', color: Colors.red, radius: 50, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _legendItem(Colors.green, 'Present (${present.toInt()})'),
                            const SizedBox(height: 8),
                            _legendItem(Colors.orange, 'Late (${late.toInt()})'),
                            const SizedBox(height: 8),
                            _legendItem(Colors.red, 'Exceptions (${exceptions.toInt()})'),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildDeptBarChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Department Attendance Comparison', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: _deptComparison.isEmpty
                  ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 100,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final dept = _deptComparison[groupIndex];
                              return BarTooltipItem(
                                '${dept['DepartmentName']}\n${rod.toY.toStringAsFixed(1)}%',
                                const TextStyle(color: Colors.white, fontSize: 12),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= _deptComparison.length) return const SizedBox();
                                final name = _deptComparison[idx]['DepartmentName'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    name.length > 8 ? '${name.substring(0, 8)}..' : name,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25),
                        borderData: FlBorderData(show: false),
                        barGroups: _deptComparison.asMap().entries.map((e) {
                          final rate = (e.value['attendanceRate'] ?? 0).toDouble();
                          return BarChartGroupData(x: e.key, barRods: [
                            BarChartRodData(
                              toY: rate,
                              color: rate >= 80 ? Colors.green : rate >= 50 ? Colors.orange : Colors.red,
                              width: 20,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CHARTS ROW 2: Line + Heatmap + Room ─────
  Widget _buildChartsRow2() {
    return Column(
      children: [
        _buildTrendLineChart(),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final halfWidth = (constraints.maxWidth - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(width: halfWidth.clamp(300.0, double.infinity), child: _buildExceptionHeatmap()),
              SizedBox(width: halfWidth.clamp(300.0, double.infinity), child: _buildRoomUtilChart()),
            ],
          );
        }),
      ],
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
            Row(
              children: [
                const Text('Global Attendance Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                _legendItem(Colors.green, 'Present'),
                const SizedBox(width: 12),
                _legendItem(Colors.orange, 'Late'),
                const SizedBox(width: 12),
                _legendItem(Colors.red, 'Exceptions'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _trend.isEmpty
                  ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                  : LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => spots.map((s) {
                              final idx = s.spotIndex;
                              final date = idx < _trend.length ? _trend[idx]['date'] : '';
                              return LineTooltipItem('$date\n${s.y.toStringAsFixed(0)}', TextStyle(color: s.bar.color, fontSize: 12));
                            }).toList(),
                          ),
                        ),
                        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: (_trend.length / 6).ceilToDouble().clamp(1, double.infinity),
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= _trend.length) return const SizedBox();
                                final date = _trend[idx]['date'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(date.toString().substring(5), style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          _trendLine(_trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['totalPresent'] ?? 0).toDouble())).toList(), Colors.green),
                          _trendLine(_trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['totalLate'] ?? 0).toDouble())).toList(), Colors.orange),
                          _trendLine(_trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['totalExceptions'] ?? 0).toDouble())).toList(), Colors.red),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _trendLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: spots.length < 15),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
    );
  }

  Widget _buildExceptionHeatmap() {
    // Group heatmap data by department
    final Map<String, Map<String, int>> grid = {};
    final Set<String> allTypes = {};
    for (var item in _heatmap) {
      final dept = item['DepartmentName'] ?? '';
      final type = item['ExceptionType'] ?? '';
      final count = (item['Count'] ?? 0) as int;
      grid.putIfAbsent(dept, () => {});
      grid[dept]![type] = count;
      allTypes.add(type);
    }
    final deptNames = grid.keys.toList();
    final typeNames = allTypes.toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Exception Heatmap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (deptNames.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No exceptions', style: TextStyle(color: Colors.grey))))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 36,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 36,
                  columnSpacing: 16,
                  columns: [
                    const DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ...typeNames.map((t) => DataColumn(label: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                  ],
                  rows: deptNames.map((dept) {
                    return DataRow(cells: [
                      DataCell(Text(dept, style: const TextStyle(fontSize: 12))),
                      ...typeNames.map((type) {
                        final count = grid[dept]?[type] ?? 0;
                        return DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: count == 0 ? Colors.grey[100] : Colors.red.withValues(alpha: (count / 10).clamp(0.1, 0.8)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: count > 0 ? Colors.white : Colors.grey)),
                        ));
                      }),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomUtilChart() {
    final topRooms = _roomUtil.take(10).toList();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room Utilization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: topRooms.isEmpty
                  ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 100,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final room = topRooms[groupIndex];
                              return BarTooltipItem(
                                '${room['RoomName']}\n${rod.toY.toStringAsFixed(1)}%',
                                const TextStyle(color: Colors.white, fontSize: 12),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= topRooms.length) return const SizedBox();
                                final name = topRooms[idx]['RoomName'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(name.length > 6 ? '${name.substring(0, 6)}..' : name, style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25),
                        borderData: FlBorderData(show: false),
                        barGroups: topRooms.asMap().entries.map((e) {
                          final rate = (e.value['utilizationRate'] ?? 0).toDouble();
                          return BarChartGroupData(x: e.key, barRods: [
                            BarChartRodData(
                              toY: rate,
                              color: Colors.teal,
                              width: 18,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RANKING TABLE ───────────────────────────
  Widget _buildDeptRankingTable() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Department Ranking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_deptRanking.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No data', style: TextStyle(color: Colors.grey))))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Attendance Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Punctuality Index', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Exceptions', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _deptRanking.map((r) {
                    final rank = r['Rank'] ?? 0;
                    final rate = (r['attendanceRate'] ?? 0).toDouble();
                    return DataRow(cells: [
                      DataCell(Row(children: [
                        if (rank <= 3) Icon(Icons.emoji_events, size: 18, color: rank == 1 ? Colors.amber : rank == 2 ? Colors.grey : Colors.brown),
                        Text(' $rank', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ])),
                      DataCell(Text(r['DepartmentName'] ?? '')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rate >= 80 ? Colors.green[50] : rate >= 50 ? Colors.orange[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: rate >= 80 ? Colors.green : rate >= 50 ? Colors.orange : Colors.red)),
                      )),
                      DataCell(Text('${(r['punctualityIndex'] ?? 0).toStringAsFixed(1)}%')),
                      DataCell(Text('${r['exceptionCount'] ?? 0}')),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── FACULTY PERFORMANCE (grouped by dept, top 5) ───
  Widget _buildFacultyPerformanceTable() {
    if (_facultyPerf.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Faculty Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Center(child: Text('No data', style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      );
    }

    // Group by department, take top 5 per dept (sorted by attendanceRate desc)
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var f in _facultyPerf) {
      final dept = f['DepartmentName'] ?? 'Unknown';
      grouped.putIfAbsent(dept, () => []);
      grouped[dept]!.add(f);
    }
    // Sort each group by attendanceRate desc, take top 5
    for (var key in grouped.keys) {
      grouped[key]!.sort((a, b) => ((b['attendanceRate'] ?? 0) as num).compareTo((a['attendanceRate'] ?? 0) as num));
      if (grouped[key]!.length > 5) {
        grouped[key] = grouped[key]!.sublist(0, 5);
      }
    }

    // Most absences & most lates across all faculty
    final sortedByAbsent = List<Map<String, dynamic>>.from(_facultyPerf)
      ..sort((a, b) => ((b['absentCount'] ?? 0) as num).compareTo((a['absentCount'] ?? 0) as num));
    final sortedByLate = List<Map<String, dynamic>>.from(_facultyPerf)
      ..sort((a, b) => ((b['lateCount'] ?? 0) as num).compareTo((a['lateCount'] ?? 0) as num));
    final topAbsent = sortedByAbsent.take(5).toList();
    final topLate = sortedByLate.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Most Absences & Most Lates side by side
        LayoutBuilder(builder: (context, constraints) {
          final halfWidth = (constraints.maxWidth - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: halfWidth.clamp(300.0, double.infinity),
                child: _buildTopListCard(
                  'Most Absences',
                  Icons.cancel_outlined,
                  Colors.red,
                  topAbsent,
                  (f) => '${f['absentCount'] ?? 0} absences',
                ),
              ),
              SizedBox(
                width: halfWidth.clamp(300.0, double.infinity),
                child: _buildTopListCard(
                  'Most Lates',
                  Icons.access_time,
                  Colors.orange,
                  topLate,
                  (f) => '${f['lateCount'] ?? 0} lates',
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 16),
        // Per-department top 5 cards
        const Text('Faculty Performance by Department (Top 5)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: grouped.entries.map<Widget>((entry) {
              return SizedBox(
                width: cardWidth.clamp(400.0, double.infinity),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowHeight: 36,
                          dataRowMinHeight: 36,
                          dataRowMaxHeight: 40,
                          columns: const [
                            DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('Faculty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('Late', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('Absent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: entry.value.asMap().entries.map((e) {
                            final idx = e.key + 1;
                            final f = e.value;
                            final rate = (f['attendanceRate'] ?? 0).toDouble();
                            return DataRow(cells: [
                              DataCell(Text('$idx', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(f['FacultyName'] ?? '', style: const TextStyle(fontSize: 12))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: rate >= 80 ? Colors.green[50] : rate >= 50 ? Colors.orange[50] : Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rate >= 80 ? Colors.green : rate >= 50 ? Colors.orange : Colors.red)),
                              )),
                              DataCell(Text('${f['lateCount'] ?? 0}', style: TextStyle(fontSize: 12, color: (f['lateCount'] ?? 0) > 0 ? Colors.orange : Colors.grey))),
                              DataCell(Text('${f['absentCount'] ?? 0}', style: TextStyle(fontSize: 12, color: (f['absentCount'] ?? 0) > 0 ? Colors.red : Colors.grey))),
                            ]);
                          }).toList(),
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
    );
  }

  Widget _buildTopListCard(String title, IconData icon, Color color, List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) subtitle) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('No data', style: TextStyle(color: Colors.grey)))
            else
              ...items.asMap().entries.map((e) {
                final idx = e.key + 1;
                final f = e.value;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text('$idx', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ),
                  title: Text(f['FacultyName'] ?? '', style: const TextStyle(fontSize: 13)),
                  subtitle: Text(f['DepartmentName'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  trailing: Text(subtitle(f), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                );
              }),
          ],
        ),
      ),
    );
  }
}
