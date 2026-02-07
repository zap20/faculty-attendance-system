import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  final String currentScreen;
  final Function(String)? onItemSelected;

  const AppDrawer({
    super.key,
    required this.currentScreen,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(user),
          const Divider(),
        if (user?.isAdmin == true) ...[
          ..._buildAdminDrawerItems(),
        ] else if (user?.isAttendanceOfficer == true) ...[
          ..._buildOfficerDrawerItems(),
        ] else ...[
          ..._buildFacultyDrawerItems(),
        ],
          const Divider(),
          ..._buildCommonDrawerItems(),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(dynamic user) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 30,
            child: Icon(
              Icons.person,
              size: 40,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.facultyName ?? user?.username ?? 'User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getRoleDisplay(user),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplay(dynamic user) {
    if (user?.isAdmin == true) return 'Administrator';
    if (user?.isAttendanceOfficer == true) return 'Attendance Officer';
    if (user?.isDepartmentHead == true) return 'Department Head';
    return 'Faculty';
  }

  List<Widget> _buildAdminDrawerItems() {
    return [
      _buildDrawerItem(
        'Dashboard',
        Icons.dashboard,
        currentScreen == 'admin_dashboard',
        () => onItemSelected?.call('admin_dashboard'),
      ),
      _buildDrawerItem(
        'Faculty Management',
        Icons.people,
        currentScreen == 'admin_faculty',
        () => onItemSelected?.call('admin_faculty'),
      ),
      _buildDrawerItem(
        'Departments',
        Icons.business,
        currentScreen == 'admin_departments',
        () => onItemSelected?.call('admin_departments'),
      ),
      _buildDrawerItem(
        'Subjects',
        Icons.book,
        currentScreen == 'admin_subjects',
        () => onItemSelected?.call('admin_subjects'),
      ),
      _buildDrawerItem(
        'Rooms',
        Icons.room,
        currentScreen == 'admin_rooms',
        () => onItemSelected?.call('admin_rooms'),
      ),
      _buildDrawerItem(
        'Schedules',
        Icons.schedule,
        currentScreen == 'admin_schedules',
        () => onItemSelected?.call('admin_schedules'),
      ),
      _buildDrawerItem(
        'Devices',
        Icons.devices,
        currentScreen == 'admin_devices',
        () => onItemSelected?.call('admin_devices'),
      ),
      _buildDrawerItem(
        'Reports',
        Icons.assessment,
        currentScreen == 'admin_reports',
        () => onItemSelected?.call('admin_reports'),
      ),
    ];
  }

  List<Widget> _buildOfficerDrawerItems() {
    return [
      _buildDrawerItem(
        'QR Scanner',
        Icons.qr_code_scanner,
        currentScreen == 'officer_scanner',
        () => onItemSelected?.call('officer_scanner'),
      ),
      _buildDrawerItem(
        'Today\'s Attendance',
        Icons.today,
        currentScreen == 'officer_today',
        () => onItemSelected?.call('officer_today'),
      ),
      _buildDrawerItem(
        'Reports',
        Icons.analytics,
        currentScreen == 'officer_reports',
        () => onItemSelected?.call('officer_reports'),
      ),
    ];
  }

  List<Widget> _buildFacultyDrawerItems() {
    return [
      _buildDrawerItem(
        'Home',
        Icons.home,
        currentScreen == 'faculty_home',
        () => onItemSelected?.call('faculty_home'),
      ),
      _buildDrawerItem(
        'My Schedule',
        Icons.schedule,
        currentScreen == 'faculty_schedule',
        () => onItemSelected?.call('faculty_schedule'),
      ),
      _buildDrawerItem(
        'Attendance History',
        Icons.history,
        currentScreen == 'faculty_history',
        () => onItemSelected?.call('faculty_history'),
      ),
    ];
  }

  List<Widget> _buildCommonDrawerItems() {
    return [
      _buildDrawerItem(
        'Profile',
        Icons.person,
        currentScreen == 'profile',
        () => onItemSelected?.call('profile'),
      ),
      _buildDrawerItem(
        'Settings',
        Icons.settings,
        currentScreen == 'settings',
        () => onItemSelected?.call('settings'),
      ),
      _buildDrawerItem(
        'Logout',
        Icons.logout,
        false,
        () => onItemSelected?.call('logout'),
        color: Colors.red,
      ),
    ];
  }

  Widget _buildDrawerItem(
    String title,
    IconData icon,
    bool isSelected,
    VoidCallback onTap, {
    Color color = Colors.black87,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.withValues(alpha: 0.1),
      onTap: onTap,
    );
  }
}
