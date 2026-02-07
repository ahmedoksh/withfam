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

    // Simple interleave: visits first, then trips (can be improved with ordering)
    for (final visit in visits) {
      cards.add(_VisitCard(visit: visit));
    }
    for (final trip in trips) {
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

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripSegment trip;

  @override
  Widget build(BuildContext context) {
    final start = trip.points.isNotEmpty ? trip.points.first : null;
    final end = trip.points.length > 1 ? trip.points.last : start;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trip'),
            if (trip.points.isNotEmpty) ...[
              const SizedBox(height: 8),
              TripMapPreview(points: trip.points),
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
            Text('Duration: ${_fmtDuration(trip.duration)}'),
            Text('Points: ${trip.points.length}'),
            if (trip.activityType != null)
              Text('Activity: ${trip.activityType}'),
          ],
        ),
      ),
    );
  }
}

String _timeRange(DateTime start, DateTime? end) {
  final endTime = end ?? DateTime.now();
  return '${_fmtDateTime(start)} - ${_fmtDateTime(endTime)}';
}

String _fmtTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _fmtDateTime(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d ${_fmtTime(dt)}';
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
