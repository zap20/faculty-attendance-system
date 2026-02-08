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
   CREATE DATABASE faculty_attendance;
   ```

3. **Import Schema**
   - Open phpMyAdmin (http://localhost/phpmyadmin)
   - Select `faculty_attendance` database
   - Import `database/schema.sql`

4. **Configure Backend**
   - Copy `backend` folder to `C:\xampp\htdocs\faculty-attendance-api`
   - Update database credentials in `backend/config/database.php` if needed:
     ```php
     define('DB_HOST', 'localhost');
     define('DB_NAME', 'faculty_attendance');
     define('DB_USER', 'root');
     define('DB_PASS', '');
     ```

5. **Test API**
   - Open browser: http://localhost/faculty-attendance-api/api/
   - Should return: `{"success":true,"message":"Faculty Attendance API"}`

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
     - Web: `http://localhost/faculty-attendance-api/api`
     - Android Emulator: `http://10.0.2.2/faculty-attendance-api/api`
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
| Department Head | dept.head | password123 |
| Faculty | maria.garcia | password123 |
| Faculty | john.smith | password123 |

## DepartmentHead Setup & Testing

### 1) Apply the DepartmentHeadUserID Migration (preferred mapping)

Import/run:

`database/add_department_head_userid.sql`

This adds `DEPARTMENTS.DepartmentHeadUserID` (FK -> `USERACCOUNTS.UserID`) which is used to reliably map a DepartmentHead account to exactly one department.

### 2) Create a DepartmentHead account

Insert a DepartmentHead user in `USERACCOUNTS` (example):

```sql
INSERT INTO USERACCOUNTS (Username, Password, Role, FacultyID, IsActive)
VALUES (
  'dept.head',
  -- Use password_hash('password123', PASSWORD_DEFAULT)
  '$2y$12$aaWMSr.HZ6ZdtWdxmDPbd.74dSZ65Xh4mDyWZIzFgy2Rm8NqhwhRW',
  'DepartmentHead',
  NULL,
  1
);
```

### 3) Link the DepartmentHead to a department

Set `DepartmentHeadUserID` on the department record:

```sql
UPDATE DEPARTMENTS
SET DepartmentHeadUserID = (SELECT UserID FROM USERACCOUNTS WHERE Username = 'dept.head')
WHERE DepartmentID = 1;
```

### 4) Login as DepartmentHead

Login from the Flutter web app using the DepartmentHead credentials.

### 5) Create Faculty (auto user creation)

In DepartmentHead Dashboard:

- Go to **Faculty**
- Click **Create Faculty**

This will:

- Create a `FACULTIES` row with `DepartmentID = your DepartmentID`
- Create a `USERACCOUNTS` row with `Role = 'Faculty'`
- Return generated credentials (shown once)

### 6) Add schedules + view analytics

- Go to **Schedules** to add schedules (conflicts are validated)
- Go to **Attendance Analytics** to view charts and apply filters

## API Endpoints

### Authentication
- `POST /auth/login` - Login
- `POST /auth/logout` - Logout
- `GET /auth/me` - Get current user
- `POST /auth/change-password` - Change password

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
- `GET /department-head/dashboard/summary?date=YYYY-MM-DD`
- `GET /department-head/analytics?from=YYYY-MM-DD&to=YYYY-MM-DD&facultyId=&subjectId=&roomId=`
- `POST /department-head/faculties` (one-click faculty + user creation)
- `GET /department-head/schedules?from=...&to=...&facultyId=...`
- `POST /department-head/schedules`
- `PUT /department-head/schedules/{id}`

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
