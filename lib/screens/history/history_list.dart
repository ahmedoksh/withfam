import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';

import '../../models/tracking_models.dart';
import 'history_map_preview.dart';

class HistoryList extends StatelessWidget {
  const HistoryList({super.key, required this.visits, required this.trips});

  final List<Visit> visits;
  final List<TripSegment> trips;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];

    // Show most recent first.
    for (final visit in visits.reversed) {
      cards.add(_VisitCard(visit: visit));
    }
    for (final trip in trips.reversed) {
      cards.add(_TripCard(trip: trip));
    }

    if (cards.isEmpty) {
      return const Center(
        child: Text('No history yet. Move around to build trips.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => cards[index],
      separatorBuilder: (context, _) => const SizedBox(height: 12),
      itemCount: cards.length,
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stayed here'),
            const SizedBox(height: 8),
            VisitMapPreview(point: visit.place),
            const SizedBox(height: 8),
            Text(
              'Lat: ${visit.place.latitude.toStringAsFixed(5)}, Lng: ${visit.place.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 4),
            Text(_timeRange(visit.arrivedAt, visit.departedAt)),
            Text('Duration: ${_fmtDuration(visit.duration)}'),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatefulWidget {
  const _TripCard({required this.trip});

  final TripSegment trip;

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  int _refreshNonce = 0;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final start = trip.points.isNotEmpty ? trip.points.first.point : null;
    final end = trip.points.isNotEmpty ? trip.points.last.point : start;
    final latLngs = trip.points.map((p) => p.point).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trip'),
                TextButton.icon(
                  onPressed: () => setState(() => _refreshNonce++),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Recenter'),
                ),
              ],
            ),
            if (latLngs.isNotEmpty) ...[
              const SizedBox(height: 8),
              TripMapPreview(points: latLngs, refreshNonce: _refreshNonce),
            ],
            if (start != null && end != null) ...[
              const SizedBox(height: 8),
              Text(
                'From: ${start.latitude.toStringAsFixed(5)}, ${start.longitude.toStringAsFixed(5)}',
              ),
              Text(
                'To:   ${end.latitude.toStringAsFixed(5)}, ${end.longitude.toStringAsFixed(5)}',
              ),
            ],
            const SizedBox(height: 4),
            Text(_timeRange(trip.startedAt, trip.endedAt)),
            Text('Duration: ${_fmtDuration(trip.duration ?? Duration.zero)}'),
            Text('Points: ${trip.points.length}'),
            if (trip.activityType != null)
              Text('Activity: ${trip.activityType}'),
          ],
        ),
      ),
    );
  }
}

String _timeRange(DateTime? start, DateTime? end) {
  if (start == null) return 'Unknown time';
  String endTimeString;
  if (end == null) {
    endTimeString = 'Unkown end time';
  } else {
    endTimeString = _fmtDateTime(end);
  }
  return '${_fmtDateTime(start)} - $endTimeString';
}

String _fmtTime(DateTime dt) {
  final local = dt.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  return '${hour12.toString().padLeft(2, '0')}:$minute $ampm';
}

String _fmtDateTime(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d ${_fmtTime(local)}';
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
