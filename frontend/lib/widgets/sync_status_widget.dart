import 'package:flutter/material.dart';
import '../services/offline/sync_service.dart';
import '../services/offline/network_service.dart';

/// A compact widget that shows sync status and connectivity in the app bar.
/// Displays: online/offline indicator, pending count, sync button.
class SyncStatusWidget extends StatefulWidget {
  const SyncStatusWidget({super.key});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final SyncService _syncService = SyncService();
  final NetworkService _networkService = NetworkService();

  @override
  void initState() {
    super.initState();
    _syncService.addListener(_onSyncChanged);
    _networkService.onConnectionChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _onSyncChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _showSyncOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sync Options', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('${_syncService.pendingCount} pending records', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.sync, color: Colors.blue),
                title: const Text('Retry Sync'),
                subtitle: const Text('Push pending records to server'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _syncService.syncAll();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_syncService.lastMessage), backgroundColor: _syncService.status == SyncStatus.success ? Colors.green : Colors.red),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.orange),
                title: const Text('Full Resync'),
                subtitle: const Text('Push pending, clear local data, re-download everything'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _syncService.fullResync();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_syncService.lastMessage), backgroundColor: _syncService.status == SyncStatus.success ? Colors.green : Colors.red),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: const Text('Clear Stuck Pending'),
                subtitle: const Text('Mark all pending records as synced (use if stuck)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final cleared = await _syncService.clearStuckPending();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cleared $cleared stuck records'), backgroundColor: Colors.orange),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _networkService.isOnline;
    final pending = _syncService.pendingCount;
    final isSyncing = _syncService.isSyncing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Connection indicator
        Tooltip(
          message: isOnline ? 'Online' : 'Offline',
          child: Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: isOnline ? Colors.green : Colors.orange,
            size: 20,
          ),
        ),
        // Pending badge
        if (pending > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$pending',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        // Sync button
        const SizedBox(width: 4),
        GestureDetector(
          onLongPress: pending > 0
              ? () => _showSyncOptions(context)
              : null,
          child: IconButton(
            icon: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync, size: 20),
            tooltip: isSyncing ? 'Syncing...' : (pending > 0 ? 'Sync now (long-press for options)' : 'Sync now'),
            onPressed: isSyncing
                ? null
                : () async {
                    await _syncService.syncAll();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_syncService.lastMessage),
                        backgroundColor: _syncService.status == SyncStatus.success
                            ? Colors.green
                            : _syncService.status == SyncStatus.error
                                ? Colors.red
                                : Colors.blue,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
          ),
        ),
      ],
    );
  }
}

/// Full sync status panel for settings or debug screen
class SyncStatusPanel extends StatefulWidget {
  const SyncStatusPanel({super.key});

  @override
  State<SyncStatusPanel> createState() => _SyncStatusPanelState();
}

class _SyncStatusPanelState extends State<SyncStatusPanel> {
  final SyncService _syncService = SyncService();
  final NetworkService _networkService = NetworkService();

  @override
  void initState() {
    super.initState();
    _syncService.addListener(_refresh);
    _networkService.onConnectionChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _syncService.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _networkService.isOnline;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: isOnline ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Online' : 'Offline Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isOnline ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Status', _syncService.status.name.toUpperCase()),
            _buildInfoRow('Pending Records', '${_syncService.pendingCount}'),
            if (_syncService.lastMessage.isNotEmpty)
              _buildInfoRow('Last Result', _syncService.lastMessage),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _syncService.isSyncing
                        ? null
                        : () => _syncService.syncAll(),
                    icon: _syncService.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(_syncService.isSyncing ? 'Syncing...' : 'Sync Now'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _syncService.isSyncing || !isOnline
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Full Resync'),
                                content: const Text(
                                  'This will push pending changes, clear local data, and re-download everything from the server. Continue?',
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resync')),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await _syncService.fullResync();
                            }
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Full Resync'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
