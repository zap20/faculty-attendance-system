# Offline-First Architecture

## Overview

The Faculty Attendance System supports **offline-first** operation on mobile devices using Sqflite for local storage. When the device is online, all operations go through the REST API (MariaDB). When offline, operations are stored locally and synced when connectivity returns.

## Architecture

```
┌─────────────────────────────────────────────┐
│                Flutter App                   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │         RepositoryProvider            │   │
│  │   (Smart Switch: Online/Offline)      │   │
│  └──────┬───────────────┬───────────────┘   │
│         │               │                    │
│  ┌──────▼──────┐ ┌──────▼──────┐            │
│  │   Online    │ │   Offline   │            │
│  │  Repository │ │  Repository │            │
│  │  (REST API) │ │  (Sqflite)  │            │
│  └──────┬──────┘ └──────┬──────┘            │
│         │               │                    │
│  ┌──────▼──────┐ ┌──────▼──────┐            │
│  │  MariaDB    │ │  Sqflite    │            │
│  │  (Remote)   │ │  (Local)    │            │
│  └─────────────┘ └─────────────┘            │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │           SyncService                 │   │
│  │  Push (local→server)                  │   │
│  │  Pull (server→local)                  │   │
│  │  Conflict Resolution (last-write-wins)│   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │         NetworkService                │   │
│  │  (connectivity_plus + API ping)       │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

## File Structure

```
lib/services/offline/
├── offline.dart                    # Barrel export
├── database_helper.dart            # Sqflite database setup & helpers
├── network_service.dart            # Connectivity detection
├── local_models.dart               # toMap/fromMap for all tables + sync fields
├── attendance_repository.dart      # Abstract repository interface
├── online_attendance_repository.dart   # REST API implementation
├── offline_attendance_repository.dart  # Sqflite implementation
├── repository_provider.dart        # Smart switch (online/offline)
├── sync_service.dart               # Push/pull sync engine
├── offline_initializer.dart        # App startup initialization
└── README_OFFLINE.md               # This file
```

## Offline Behavior

### When ONLINE:
- All operations go through the REST API (MariaDB)
- If an API call fails, it automatically falls back to local Sqflite
- Background sync runs every 5 minutes

### When OFFLINE:
- All operations are stored in local Sqflite
- Records are marked `isSynced = 0`
- Attendance time-in/time-out works using local schedule data
- Status calculations (Present, Late, Absent) are done locally

### When Connection Restores:
- `NetworkService` detects connectivity change
- `SyncService` automatically triggers a full sync
- Local unsynced records are pushed to the server
- Server updates are pulled to local database

## Sync Mechanism

### Push Phase (Local → Server)
1. Query all local `attendances` where `isSynced = 0`
2. Send batch to `POST /api/sync/push`
3. Server inserts/updates records using composite key (`FacultyID + Date + ScheduleID`)
4. Server returns `remoteId` for each synced record
5. Local records are updated: `isSynced = 1`, `remoteId` set

### Pull Phase (Server → Local)
1. For each table (in dependency order): `departments → faculties → rooms → subjects → schedules → devices → attendances`
2. Call `GET /api/sync/pull?table=X&since=lastPullTimestamp`
3. Server returns records updated since that timestamp
4. Local database is updated via upsert (insert or update)
5. `lastPullAt` timestamp is saved in `sync_log` table

### Conflict Resolution
- **Strategy**: Last-write-wins based on `UpdatedAt` / `localUpdatedAt` timestamps
- If local has unsynced changes (`isSynced = 0`) and remote has newer `UpdatedAt`, remote wins
- If local `localUpdatedAt` is newer than remote `UpdatedAt`, local wins (skip remote update)
- Soft deletes use `deletedAt` field — records are never physically deleted during sync

### Duplicate Prevention
- Unique composite index on `attendances(FacultyID, Date, ScheduleID)`
- Server checks for existing records before inserting
- Local checks for duplicates before creating offline records

## Sync Triggers
1. **App startup** — initial sync runs in background
2. **Connection restored** — automatic sync when going from offline to online
3. **Manual sync** — user taps sync button in UI
4. **Periodic** — every 5 minutes while online

## Local Database Tables

All tables mirror the remote MariaDB schema with these additional sync fields:

| Field | Type | Description |
|-------|------|-------------|
| `isSynced` | INTEGER | 0 = needs sync, 1 = synced |
| `localCreatedAt` | TEXT | ISO8601 timestamp of local creation |
| `localUpdatedAt` | TEXT | ISO8601 timestamp of last local update |
| `deletedAt` | TEXT | Soft delete timestamp (nullable) |
| `version` | INTEGER | Optimistic concurrency version |

The `attendances` table also has:
| `remoteId` | INTEGER | The server-side AttendanceID |

## Backend API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/sync/push` | Push local records to server |
| GET | `/api/sync/pull?table=X&since=T` | Pull records updated since timestamp |
| GET | `/api/sync/status` | Get record counts per table |

## UI Components

### SyncStatusWidget
Compact widget for the app bar showing:
- Online/offline icon (cloud)
- Pending record count badge
- Sync button with loading indicator

### SyncStatusPanel
Full panel for settings/debug showing:
- Connection status
- Sync status, pending count, last result
- "Sync Now" and "Full Resync" buttons

## Usage Example

```dart
// Smart time-in (auto-switches online/offline)
final repo = RepositoryProvider();
final result = await repo.smartExecute(
  (repo) => repo.timeIn(deviceId: 5),
  operationName: 'TimeIn',
);

// Direct offline access
final offlineRepo = repo.offline;
final schedules = await offlineRepo.getSchedules(facultyId: '2026-001');

// Manual sync
final syncService = SyncService();
await syncService.syncAll();

// Check connectivity
final network = NetworkService();
if (network.isOnline) {
  // do online stuff
}
```

## Testing Instructions

### Test Sync Pull:
```bash
curl -s "http://localhost:8000/api/index.php/sync/pull?table=departments" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Test Sync Push:
```bash
curl -s -X POST "http://localhost:8000/api/index.php/sync/push" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"table":"attendances","records":[{"FacultyID":"2026-001","Date":"2026-02-14","DayOfWeek":"Saturday","TimeIn":"08:00:00","AttendanceStatus":"Present","ScheduleID":1,"localId":99}]}'
```

### Test Sync Status:
```bash
curl -s "http://localhost:8000/api/index.php/sync/status" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Test Offline Mode:
1. Login on mobile while online (data syncs to local)
2. Turn off WiFi/data
3. Record attendance — stored locally
4. Turn WiFi back on
5. Observe automatic sync (check debug console for `[SyncService]` logs)

## Notes
- Sqflite is only used on mobile (Android/iOS). Web builds skip offline initialization (`kIsWeb` check in `main.dart`).
- The `DatabaseHelper` uses WAL journal mode for better concurrent read/write performance.
- Foreign keys are enabled via `PRAGMA foreign_keys = ON`.
- All sync operations use database transactions for atomicity.
