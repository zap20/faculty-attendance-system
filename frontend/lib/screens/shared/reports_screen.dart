import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'package:sqflite/sqflite.dart';
import '../../services/offline/database_helper.dart';
import '../../services/offline/network_service.dart';
import 'package:flutter/services.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _reportType = 'daily';
  late DateTime _fromDate;
  late DateTime _toDate;
  late DateTime _singleDate;
  String? _statusFilter;
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _reportData = {};

  // Pagination
  int _currentPage = 0;
  static const int _rowsPerPage = 15;

  // Sort
  int? _sortColumnIndex;
  bool _sortAscending = true;

  final _reportTypes = const [
    {'value': 'daily', 'label': 'Daily Attendance Report'},
    {'value': 'date-range', 'label': 'Date Range Summary'},
    {'value': 'faculty-performance', 'label': 'Faculty Performance'},
    {'value': 'room-utilization', 'label': 'Room Utilization'},
    {'value': 'exceptions', 'label': 'Exception Report'},
  ];

  final _statusOptions = const [
    'Late',
    'No Schedule',
    'Wrong Room',
  ];

  @override
  void initState() {
    super.initState();
    _toDate = DateTime.now();
    _fromDate = _toDate.subtract(const Duration(days: 30));
    _singleDate = DateTime.now();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 0;
      _sortColumnIndex = null;
    });

    try {
      final qp = <String, String>{};

      if (_reportType == 'daily') {
        qp['date'] = _fmt(_singleDate);
      } else {
        qp['from'] = _fmt(_fromDate);
        qp['to'] = _fmt(_toDate);
      }

      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        qp['status'] = _statusFilter!;
      }

      final network = NetworkService();
      if (!network.isOnline) {
        // Go straight to offline
        final data = await _generateOfflineReport();
        setState(() => _reportData = data);
        return;
      }

      final response = await ApiService.get('/reports/$_reportType', queryParams: qp);
      setState(() {
        _reportData = (response['data'] as Map<String, dynamic>?) ?? {};
      });
    } catch (e) {
      // API failed — try offline fallback
      try {
        final data = await _generateOfflineReport();
        setState(() => _reportData = data);
      } catch (e2) {
        setState(() => _error = 'Failed to generate report: $e2');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Generate report data from local Sqflite database
  Future<Map<String, dynamic>> _generateOfflineReport() async {
    final db = await DatabaseHelper().database;

    switch (_reportType) {
      case 'daily':
        return _offlineDailyReport(db);
      case 'date-range':
        return _offlineDateRangeReport(db);
      case 'faculty-performance':
        return _offlineFacultyPerformanceReport(db);
      case 'room-utilization':
        return _offlineRoomUtilizationReport(db);
      case 'exceptions':
        return _offlineExceptionsReport(db);
      default:
        return {};
    }
  }

  Future<Map<String, dynamic>> _offlineDailyReport(dynamic db) async {
    final date = _fmt(_singleDate);
    final where = <String>['a.Date = ?', 'a.deletedAt IS NULL'];
    final args = <dynamic>[date];

    if (_statusFilter != null && _statusFilter!.isNotEmpty) {
      where.add('a.AttendanceStatus = ?');
      args.add(_statusFilter);
    }

    final rows = await db.rawQuery('''
      SELECT a.*, f.FacultyName, f.DepartmentID,
             s.SubjectID, sub.SubjectName, sub.CourseCode,
             s.StartTime AS ScheduledStart, s.EndTime AS ScheduledEnd,
             r.RoomName, r.Building
      FROM attendances a
      LEFT JOIN faculties f ON a.FacultyID = f.FacultyID
      LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
      LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
      LEFT JOIN rooms r ON s.RoomID = r.RoomID
      WHERE ${where.join(' AND ')}
      ORDER BY a.TimeIn
    ''', args);

    return {
      'date': date,
      'totalRecords': rows.length,
      'records': rows,
      'offline': true,
    };
  }

  Future<Map<String, dynamic>> _offlineDateRangeReport(dynamic db) async {
    final from = _fmt(_fromDate);
    final to = _fmt(_toDate);

    final totalPresent = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM attendances WHERE Date >= ? AND Date <= ? AND deletedAt IS NULL',
      [from, to],
    )) ?? 0;

    final totalLate = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM attendances WHERE Date >= ? AND Date <= ? AND AttendanceStatus = 'Late' AND deletedAt IS NULL",
      [from, to],
    )) ?? 0;

    final totalExceptions = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM attendances WHERE Date >= ? AND Date <= ? AND AttendanceStatus IN ('No Schedule','Wrong Room') AND deletedAt IS NULL",
      [from, to],
    )) ?? 0;

    final totalScheduled = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM schedules WHERE deletedAt IS NULL',
    )) ?? 1;

    final rate = totalScheduled > 0 ? ((totalPresent / totalScheduled) * 100).round() : 0;

    return {
      'from': from,
      'to': to,
      'totalScheduledSessions': totalScheduled,
      'totalPresent': totalPresent,
      'totalLate': totalLate,
      'totalExceptions': totalExceptions,
      'attendanceRate': rate,
      'offline': true,
    };
  }

  Future<Map<String, dynamic>> _offlineFacultyPerformanceReport(dynamic db) async {
    final from = _fmt(_fromDate);
    final to = _fmt(_toDate);

    final rows = await db.rawQuery('''
      SELECT f.FacultyID, f.FacultyName, d.DepartmentName,
             COUNT(a.AttendanceID) as totalSessions,
             SUM(CASE WHEN a.AttendanceStatus IN ('Present','Late') THEN 1 ELSE 0 END) as presentCount,
             SUM(CASE WHEN a.AttendanceStatus = 'Late' THEN 1 ELSE 0 END) as lateCount,
             SUM(CASE WHEN a.AttendanceStatus IN ('No Schedule','Wrong Room') THEN 1 ELSE 0 END) as exceptionCount
      FROM faculties f
      LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
      LEFT JOIN attendances a ON a.FacultyID = f.FacultyID AND a.Date >= ? AND a.Date <= ? AND a.deletedAt IS NULL
      WHERE f.deletedAt IS NULL
      GROUP BY f.FacultyID
      ORDER BY f.FacultyName
    ''', [from, to]);

    final records = rows.map((r) {
      final total = (r['totalSessions'] as num?) ?? 0;
      final present = (r['presentCount'] as num?) ?? 0;
      final rate = total > 0 ? ((present / total) * 100) : 0.0;
      return {
        ...r,
        'attendanceRate': rate,
      };
    }).toList();

    return {
      'records': records,
      'offline': true,
    };
  }

  Future<Map<String, dynamic>> _offlineRoomUtilizationReport(dynamic db) async {
    final from = _fmt(_fromDate);
    final to = _fmt(_toDate);

    final rows = await db.rawQuery('''
      SELECT r.RoomID, r.RoomName, r.Building,
             COUNT(DISTINCT s.ScheduleID) as scheduledSessions,
             COUNT(DISTINCT a.AttendanceID) as validAttendanceCount
      FROM rooms r
      LEFT JOIN schedules s ON s.RoomID = r.RoomID AND s.deletedAt IS NULL
      LEFT JOIN attendances a ON a.ScheduleID = s.ScheduleID AND a.Date >= ? AND a.Date <= ? AND a.deletedAt IS NULL
      WHERE r.deletedAt IS NULL
      GROUP BY r.RoomID
      ORDER BY r.RoomName
    ''', [from, to]);

    final records = rows.map((r) {
      final scheduled = (r['scheduledSessions'] as num?) ?? 0;
      final valid = (r['validAttendanceCount'] as num?) ?? 0;
      final rate = scheduled > 0 ? ((valid / scheduled) * 100) : 0.0;
      return {
        ...r,
        'utilizationRate': rate,
      };
    }).toList();

    return {
      'records': records,
      'offline': true,
    };
  }

  Future<Map<String, dynamic>> _offlineExceptionsReport(dynamic db) async {
    final where = <String>["a.AttendanceStatus IN ('Late','No Schedule','Wrong Room')", 'a.deletedAt IS NULL'];
    final args = <dynamic>[];

    if (_reportType == 'daily') {
      where.add('a.Date = ?');
      args.add(_fmt(_singleDate));
    } else {
      where.add('a.Date >= ?');
      where.add('a.Date <= ?');
      args.add(_fmt(_fromDate));
      args.add(_fmt(_toDate));
    }

    if (_statusFilter != null && _statusFilter!.isNotEmpty) {
      where.add('a.AttendanceStatus = ?');
      args.add(_statusFilter);
    }

    final rows = await db.rawQuery('''
      SELECT a.Date, f.FacultyName, d.DepartmentName,
             sub.SubjectName, r.RoomName,
             a.AttendanceStatus, a.TimeIn, a.Remarks
      FROM attendances a
      LEFT JOIN faculties f ON a.FacultyID = f.FacultyID
      LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
      LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
      LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
      LEFT JOIN rooms r ON s.RoomID = r.RoomID
      WHERE ${where.join(' AND ')}
      ORDER BY a.Date DESC, a.TimeIn DESC
    ''', args);

    return {
      'totalRecords': rows.length,
      'records': rows,
      'offline': true,
    };
  }

  String _buildCsvFromData() {
    final buf = StringBuffer();
    if (_reportType == 'date-range') {
      buf.writeln('Metric,Value');
      buf.writeln('From,${_reportData['from'] ?? ''}');
      buf.writeln('To,${_reportData['to'] ?? ''}');
      buf.writeln('Total Scheduled Sessions,${_reportData['totalScheduledSessions'] ?? 0}');
      buf.writeln('Total Present,${_reportData['totalPresent'] ?? 0}');
      buf.writeln('Total Late,${_reportData['totalLate'] ?? 0}');
      buf.writeln('Total Exceptions,${_reportData['totalExceptions'] ?? 0}');
      buf.writeln('Attendance Rate %,${_reportData['attendanceRate'] ?? 0}');
    } else {
      final records = (_reportData['records'] as List?) ?? [];
      if (records.isNotEmpty) {
        final first = records[0] as Map<String, dynamic>;
        buf.writeln(first.keys.join(','));
        for (final r in records) {
          final m = r as Map<String, dynamic>;
          buf.writeln(m.values.map((v) => '"${v?.toString().replaceAll('"', '""') ?? ''}"').join(','));
        }
      }
    }
    return buf.toString();
  }

  Future<void> _exportCsv() async {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate a report first'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final csv = _buildCsvFromData();
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV data copied to clipboard! Paste into a .csv file.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
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
    }
  }

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _singleDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _singleDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Type Selector + Filters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Generate Report', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      // Report type dropdown
                      SizedBox(
                        width: 280,
                        child: DropdownButtonFormField<String>(
                          value: _reportType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Report Type',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: _reportTypes.map((t) => DropdownMenuItem(
                            value: t['value'],
                            child: Text(t['label']!, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setState(() {
                            _reportType = v ?? 'daily';
                            _reportData = {};
                          }),
                        ),
                      ),

                      // Date picker
                      if (_reportType == 'daily')
                        SizedBox(
                          width: 220,
                          child: InkWell(
                            onTap: _pickSingleDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                suffixIcon: Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(DateFormat('MMM d, yyyy').format(_singleDate)),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: 300,
                          child: InkWell(
                            onTap: _pickDateRange,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date Range',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                suffixIcon: Icon(Icons.date_range, size: 18),
                              ),
                              child: Text('${DateFormat('MMM d').format(_fromDate)} — ${DateFormat('MMM d, yyyy').format(_toDate)}'),
                            ),
                          ),
                        ),

                      // Status filter (for daily & exceptions)
                      if (_reportType == 'daily' || _reportType == 'exceptions')
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Status Filter',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('All')),
                              ..._statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                            ],
                            onChanged: (v) => setState(() => _statusFilter = v),
                          ),
                        ),

                      // Generate button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _loadReport,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Generate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Loading / Error / Results
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            )
          else if (_reportData.isNotEmpty)
            _buildReportResults(),
        ],
      ),
    );
  }

  Widget _buildReportResults() {
    // Export buttons
    final exportRow = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            _reportTypes.firstWhere((t) => t['value'] == _reportType)['label'] ?? '',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export CSV'),
          ),
        ],
      ),
    );

    switch (_reportType) {
      case 'daily':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [exportRow, _buildDailyReport()]);
      case 'date-range':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [exportRow, _buildDateRangeReport()]);
      case 'faculty-performance':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [exportRow, _buildFacultyPerformanceReport()]);
      case 'room-utilization':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [exportRow, _buildRoomUtilizationReport()]);
      case 'exceptions':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [exportRow, _buildExceptionsReport()]);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Daily Report ───
  Widget _buildDailyReport() {
    final records = (_reportData['records'] as List?) ?? [];
    final total = _reportData['totalRecords'] ?? records.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${_reportData['date'] ?? ''} — $total records', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            if (records.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No attendance records found')))
            else
              _buildPaginatedTable(
                columns: const ['Faculty', 'Subject', 'Room', 'Scheduled', 'Time In', 'Time Out', 'Status', 'Remarks'],
                rows: records,
                cellBuilder: (r) => [
                  r['FacultyName']?.toString() ?? '',
                  r['SubjectName']?.toString() ?? '-',
                  r['RoomName'] != null ? '${r['RoomName']} (${r['Building'] ?? ''})' : '-',
                  r['ScheduledStart'] != null ? '${_fmtTime(r['ScheduledStart'])} - ${_fmtTime(r['ScheduledEnd'])}' : '-',
                  _fmtTime(r['TimeIn']),
                  _fmtTime(r['TimeOut']),
                  r['AttendanceStatus']?.toString() ?? '',
                  r['Remarks']?.toString() ?? '',
                ],
                statusIndex: 6,
              ),
          ],
        ),
      ),
    );
  }

  // ─── Date Range Summary ───
  Widget _buildDateRangeReport() {
    final d = _reportData;
    final items = [
      {'label': 'Period', 'value': '${d['from']} to ${d['to']}'},
      {'label': 'Total Scheduled Sessions', 'value': '${d['totalScheduledSessions'] ?? 0}'},
      {'label': 'Total Present', 'value': '${d['totalPresent'] ?? 0}'},
      {'label': 'Total Late', 'value': '${d['totalLate'] ?? 0}'},
      {'label': 'Total Exceptions', 'value': '${d['totalExceptions'] ?? 0}'},
      {'label': 'Attendance Rate', 'value': '${d['attendanceRate'] ?? 0}%'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(item['label']!, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text(item['value']!, style: const TextStyle(fontSize: 16))),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }

  // ─── Faculty Performance ───
  Widget _buildFacultyPerformanceReport() {
    final records = (_reportData['records'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: records.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No data')))
            : _buildPaginatedTable(
                columns: const ['Faculty', 'Department', 'Sessions', 'Present', 'Late', 'Exceptions', 'Rate'],
                rows: records,
                cellBuilder: (r) => [
                  r['FacultyName']?.toString() ?? '',
                  r['DepartmentName']?.toString() ?? '',
                  '${r['totalSessions'] ?? 0}',
                  '${r['presentCount'] ?? 0}',
                  '${r['lateCount'] ?? 0}',
                  '${r['exceptionCount'] ?? 0}',
                  '${((r['attendanceRate'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
                ],
                rateIndex: 6,
              ),
      ),
    );
  }

  // ─── Room Utilization ───
  Widget _buildRoomUtilizationReport() {
    final records = (_reportData['records'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: records.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No room data')))
            : _buildPaginatedTable(
                columns: const ['Room', 'Building', 'Scheduled', 'Recorded', 'Util. Rate'],
                rows: records,
                cellBuilder: (r) => [
                  r['RoomName']?.toString() ?? '',
                  r['Building']?.toString() ?? '',
                  '${r['scheduledSessions'] ?? 0}',
                  '${r['validAttendanceCount'] ?? 0}',
                  '${((r['utilizationRate'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
                ],
                rateIndex: 4,
              ),
      ),
    );
  }

  // ─── Exceptions ───
  Widget _buildExceptionsReport() {
    final records = (_reportData['records'] as List?) ?? [];
    final total = _reportData['totalRecords'] ?? records.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$total exception records', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            if (records.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No exceptions found')))
            else
              _buildPaginatedTable(
                columns: const ['Date', 'Faculty', 'Department', 'Subject', 'Room', 'Status', 'Time In', 'Remarks'],
                rows: records,
                cellBuilder: (r) => [
                  r['Date']?.toString() ?? '',
                  r['FacultyName']?.toString() ?? '',
                  r['DepartmentName']?.toString() ?? '',
                  r['SubjectName']?.toString() ?? '-',
                  r['RoomName']?.toString() ?? '-',
                  r['AttendanceStatus']?.toString() ?? '',
                  _fmtTime(r['TimeIn']),
                  r['Remarks']?.toString() ?? '',
                ],
                statusIndex: 5,
              ),
          ],
        ),
      ),
    );
  }

  // ─── Paginated Table Builder ───
  Widget _buildPaginatedTable({
    required List<String> columns,
    required List<dynamic> rows,
    required List<String> Function(Map<String, dynamic>) cellBuilder,
    int? statusIndex,
    int? rateIndex,
  }) {
    final totalPages = (rows.length / _rowsPerPage).ceil();
    final startIdx = _currentPage * _rowsPerPage;
    final endIdx = (startIdx + _rowsPerPage).clamp(0, rows.length);
    final pageRows = rows.sublist(startIdx, endIdx);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            columns: columns.asMap().entries.map((entry) {
              return DataColumn(
                label: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                onSort: (colIdx, asc) {
                  setState(() {
                    _sortColumnIndex = colIdx;
                    _sortAscending = asc;
                    // Sort the underlying list
                    final allCells = rows.map((r) => cellBuilder(r as Map<String, dynamic>)).toList();
                    final indices = List.generate(rows.length, (i) => i);
                    indices.sort((a, b) {
                      final va = allCells[a][colIdx];
                      final vb = allCells[b][colIdx];
                      return asc ? va.compareTo(vb) : vb.compareTo(va);
                    });
                    final sorted = indices.map((i) => rows[i]).toList();
                    rows.clear();
                    rows.addAll(sorted);
                    _currentPage = 0;
                  });
                },
              );
            }).toList(),
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            rows: pageRows.map((r) {
              final cells = cellBuilder(r as Map<String, dynamic>);
              return DataRow(
                cells: cells.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final val = entry.value;
                  TextStyle? style;

                  if (idx == statusIndex) {
                    style = TextStyle(
                      color: _statusColor(val),
                      fontWeight: FontWeight.w600,
                    );
                  } else if (idx == rateIndex) {
                    final numVal = double.tryParse(val.replaceAll('%', '')) ?? 0;
                    style = TextStyle(
                      color: numVal >= 80 ? Colors.green : (numVal >= 50 ? Colors.orange : Colors.red),
                      fontWeight: FontWeight.bold,
                    );
                  }

                  return DataCell(Text(val, style: style));
                }).toList(),
              );
            }).toList(),
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                ),
                Text('Page ${_currentPage + 1} of $totalPages', style: const TextStyle(fontWeight: FontWeight.w500)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                ),
                const SizedBox(width: 16),
                Text('${rows.length} total rows', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Present': return Colors.green;
      case 'Late': return Colors.orange;
      case 'No Schedule': return Colors.purple;
      case 'Wrong Room': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _fmtTime(dynamic time) {
    if (time == null) return '-';
    final s = time.toString();
    if (s.isEmpty) return '-';
    try {
      final parts = s.split(':');
      if (parts.length < 2) return s;
      int hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return s;
    }
  }
}
