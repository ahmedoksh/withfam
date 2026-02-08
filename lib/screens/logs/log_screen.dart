import 'package:flutter/material.dart';

import '../../services/log_service.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: 'Clear logs',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await LogService.instance.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Logs cleared')));
              }
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<LogEntry>>(
        valueListenable: LogService.instance.logs,
        builder: (context, entries, _) {
          if (entries.isEmpty) {
            return const Center(child: Text('No logs yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              // Show newest first.
              final entry = entries[entries.length - 1 - index];
              return _LogTile(entry: entry);
            },
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activityColor = _activityColor(cs, entry.activity);
    final movingColor = entry.isMoving == true ? Colors.green : Colors.red;
    final tripColor = cs.primary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (entry.tripIndex != null)
                  _ChipText('Trip ${entry.tripIndex}', tripColor),
                if (entry.activity != null)
                  _ChipText(entry.activity!, activityColor),
                if (entry.isMoving != null)
                  _ChipText(entry.isMoving! ? 'Moving' : 'Still', movingColor),
                _ChipText(_fmtTime(entry.timestamp), cs.secondary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.message.isNotEmpty ? entry.message : 'No message',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (entry.lat != null && entry.lng != null)
              Text(
                'Lat: ${entry.lat!.toStringAsFixed(5)}, Lng: ${entry.lng!.toStringAsFixed(5)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (entry.lat == null || entry.lng == null)
              const Text('No coordinates recorded'),
          ],
        ),
      ),
    );
  }

  Color _activityColor(ColorScheme cs, String? activity) {
    if (activity == null) return cs.secondary;
    switch (activity.toLowerCase()) {
      case 'walking':
        return Colors.teal;
      case 'running':
        return Colors.orange;
      case 'in_vehicle':
        return Colors.indigo;
      case 'on_bicycle':
        return Colors.purple;
      default:
        return cs.secondary;
    }
  }

  String _fmtTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day} ${hour.toString().padLeft(2, '0')}:$minute:$second $ampm';
  }
}

class _ChipText extends StatelessWidget {
  const _ChipText(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
