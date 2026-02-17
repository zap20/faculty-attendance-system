import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/department_head_provider.dart';
import 'screens/login_screen.dart';
import 'screens/faculty/faculty_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/officer/officer_dashboard_screen.dart';
import 'screens/department_head/department_head_dashboard_screen.dart';
import 'config/app_config.dart';
import 'services/offline/offline_initializer.dart';
import 'services/offline/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline-first services (Sqflite, connectivity, sync)
  if (!kIsWeb) {
    await OfflineInitializer.initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => DepartmentHeadProvider()),
        if (!kIsWeb) ChangeNotifierProvider(create: (_) => SyncService()),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        routes: {
          '/dept-head': (context) => const AuthWrapper(),
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
          cardTheme: const CardThemeData(
            elevation: 2,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading while checking auth status
        if (authProvider.status == AuthStatus.initial ||
            authProvider.status == AuthStatus.loading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // Not authenticated - show login
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        // Authenticated - route based on role
        final user = authProvider.user;
        if (user == null) {
          return const LoginScreen();
        }

        // Admin -> Admin Dashboard
        if (user.isAdmin) {
          return const AdminDashboardScreen();
        }

        // AttendanceOfficer -> Officer Dashboard with QR Scanner
        if (user.isAttendanceOfficer) {
          return const OfficerDashboardScreen();
        }

        if (user.isDepartmentHead) {
          return const DepartmentHeadDashboardScreen();
        }

        // Faculty -> Faculty Dashboard
        return const FacultyDashboardScreen();
      },
    );
  }
}
