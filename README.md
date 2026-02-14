# Faculty Attendance and Monitoring System

A full-stack attendance management system for educational institutions with a Flutter frontend and PHP REST API backend.

## Features

- **Role-based Access Control**: Admin, Attendance Officer, Department Head, Faculty
- **Real-time Attendance Verification**: Validates time in/out against schedules, rooms, and device status
- **Faculty Mobile App**: Time in/out, view schedules, attendance history
- **Admin Web Dashboard**: Manage faculty, departments, subjects, rooms, schedules, devices, and reports
- **Late Detection**: Automatic late marking with configurable grace period (10 minutes)

## Tech Stack

### Backend
- PHP 8 (no framework, simple MVC pattern)
- MariaDB (XAMPP)
- Token-based authentication

### Frontend
- Flutter (Dart)
- Provider for state management
- HTTP package for API calls
- Shared Preferences for token storage

## Project Structure

```
faculty-attendance-system/
├── backend/
│   ├── api/
│   │   └── index.php          # Main API router
│   ├── config/
│   │   ├── config.php         # App configuration
│   │   └── database.php       # Database connection
│   ├── controllers/           # API controllers
│   ├── helpers/               # Auth, Response, Validator
│   ├── models/                # Database models
│   └── .htaccess              # URL rewriting
├── database/
│   └── schema.sql             # Database schema and seed data
├── frontend/
│   ├── lib/
│   │   ├── config/            # App configuration
│   │   ├── models/            # Data models
│   │   ├── providers/         # State management
│   │   ├── screens/           # UI screens
│   │   ├── services/          # API services
│   │   └── main.dart          # App entry point
│   └── pubspec.yaml           # Flutter dependencies
└── README.md
```

## Setup Instructions

### Prerequisites

- XAMPP (PHP 8+, MariaDB)
- Flutter SDK (3.0+)
- Android Studio or VS Code with Flutter extension

### Backend Setup

1. **Start XAMPP**
   - Start Apache and MySQL services

2. **Create Database**
   ```sql
   CREATE DATABASE faculty_attendance_db;
   ```

3. **Import Schema**
   - Open phpMyAdmin (http://localhost/phpmyadmin)
   - Select `faculty_attendance_db` database
   - Import `database/schema.sql`

4. **Apply DepartmentHead Migration**
   - Import `database/add_department_head_userid.sql`

5. **Link a DepartmentHead user to a department**
   - Example (Computer Science head = `john.smith`):
   ```sql
   UPDATE departments
   SET DepartmentHeadUserID = (SELECT UserID FROM useraccounts WHERE Username = 'john.smith')
   WHERE DepartmentID = 1;
   ```

6. **Configure Backend**
   - Update database credentials in `backend/config/database.php` if needed:
     ```php
     define('DB_HOST', 'localhost');
     define('DB_NAME', 'faculty_attendance_db');
     define('DB_USER', 'root');
     define('DB_PASS', '');
     ```

7. **Run API**
   - From the project root:
   ```bash
   php -S localhost:8000 -t backend
   ```

8. **Test API**
   - Open browser: http://localhost:8000/api/index.php
   - Should return a JSON success response

### Frontend Setup

1. **Navigate to Frontend**
   ```bash
   cd frontend
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API URL** (if needed)
   - Edit `lib/config/app_config.dart`
   - Update `apiBaseUrl` for your environment:
     - Web: `http://localhost:8000/api/index.php`
     - Android Emulator: `http://10.0.2.2:8000/api/index.php`
     - Physical Device: Use your computer's IP address

4. **Run the App**
   ```bash
   # For web
   flutter run -d chrome
   
   # For Android
   flutter run -d android
   
   # Build APK
   flutter build apk
   ```

## Default Credentials

| Role | Username | Password |
|------|----------|----------|
| Admin | admin | password123 |
| Attendance Officer | officer1 | password123 |
| Department Head | john.smith | password123 |
| Department Head | sarah.williams | password123 |
| Faculty | maria.garcia | password123 |

## DepartmentHead Quick Test

1. **Run migration**
   - Import `database/add_department_head_userid.sql`

2. **Link a department to a DepartmentHead user**
   - Example: link Computer Science (DepartmentID=1) to `john.smith`
   ```sql
   UPDATE departments
   SET DepartmentHeadUserID = (SELECT UserID FROM useraccounts WHERE Username = 'john.smith')
   WHERE DepartmentID = 1;
   ```

3. **Login as DepartmentHead**
   - Username: `john.smith`
   - Password: `password123`
   - You should land on the DepartmentHead dashboard.

4. **Create Faculty (auto user)**
   - Open `Faculty` in the sidebar.
   - Fill out the form (Faculty Name, Position, Employment Status, Username).
   - The API returns generated credentials if you leave temp password blank.

5. **Create Schedule**
   - Open `Schedules` in the sidebar.
   - Pick a faculty, subject, room, day, start/end time.
   - Conflicts (faculty/time overlap or room/time overlap) return `409`.

6. **View Analytics**
   - Open `Attendance Analytics` in the sidebar.
   - The dashboard loads department-scoped breakdown and trend.

## API Endpoints

### Authentication
- `POST /auth/login` - Login
- `POST /auth/logout` - Logout
- `GET /me` - Get current user
- `PUT /auth/password` - Change password

### Faculty
- `GET /faculties` - List all faculty
- `GET /faculties/{id}` - Get faculty by ID
- `POST /faculties` - Create faculty
- `PUT /faculties/{id}` - Update faculty
- `DELETE /faculties/{id}` - Delete faculty

### Departments
- `GET /departments` - List all departments
- `GET /departments/{id}` - Get department by ID
- `POST /departments` - Create department
- `PUT /departments/{id}` - Update department
- `DELETE /departments/{id}` - Delete department

### Subjects
- `GET /subjects` - List all subjects
- `GET /subjects/{id}` - Get subject by ID
- `POST /subjects` - Create subject
- `PUT /subjects/{id}` - Update subject
- `DELETE /subjects/{id}` - Delete subject

### Rooms
- `GET /rooms` - List all rooms
- `GET /rooms/{id}` - Get room by ID
- `POST /rooms` - Create room
- `PUT /rooms/{id}` - Update room
- `DELETE /rooms/{id}` - Delete room

### Schedules
- `GET /schedules` - List all schedules
- `GET /schedules/today` - Get today's schedules
- `GET /schedules/{id}` - Get schedule by ID
- `POST /schedules` - Create schedule
- `PUT /schedules/{id}` - Update schedule
- `DELETE /schedules/{id}` - Delete schedule

### Devices
- `GET /devices` - List all devices
- `GET /devices/{id}` - Get device by ID
- `POST /devices` - Create device
- `PUT /devices/{id}` - Update device
- `DELETE /devices/{id}` - Delete device

### Attendance
- `GET /attendance` - List attendance records
- `GET /attendance/today` - Get today's attendance
- `POST /attendance/time-in` - Record time in
- `POST /attendance/time-out` - Record time out
- `GET /attendance/history` - Get attendance history

### Reports
- `GET /reports/summary` - Attendance summary
- `GET /reports/department/{id}` - Department report
- `GET /reports/dashboard` - Dashboard statistics

### DepartmentHead
- `GET /department-head/dashboard/summary` - Department KPIs and summary
- `GET /department-head/analytics` - Department analytics (supports `from`, `to`, `facultyId`, `subjectId`, `roomId`)
- `GET /department-head/faculties` - List department faculty
- `POST /department-head/faculties` - Create faculty and auto-create user account
- `GET /department-head/schedules` - List schedules (optional `facultyId`)
- `POST /department-head/schedules` - Create schedule (conflict-checked)
- `PUT /department-head/schedules/{id}` - Update schedule (conflict-checked)
- `DELETE /department-head/schedules/{id}` - Delete schedule

## Attendance Verification Logic

When a faculty member times in:
1. Check if device is active
2. Find matching schedule for current day/time
3. Verify device is in the correct room for the schedule
4. Calculate if late (>10 minutes after schedule start)
5. Record attendance with appropriate status

Status values:
- **Present**: On time, correct room
- **Late**: After grace period, correct room
- **Wrong Room**: Device not in scheduled room
- **No Schedule**: No matching schedule found

## License

MIT License
