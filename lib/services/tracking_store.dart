import 'dart:async';

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/tracking_models.dart';

/// Very simple in-memory store for visits and trips.
/// Replace with persistent storage (Hive/SQLite) later.
class TrackingStore {
  TrackingStore._();

  static final TrackingStore instance = TrackingStore._();

  final ValueNotifier<List<Visit>> visits = ValueNotifier<List<Visit>>([]);
  final ValueNotifier<List<TripSegment>> trips =
      ValueNotifier<List<TripSegment>>([]);

  TripSegment? _activeTrip;
  Visit? _activeVisit;
  Box<dynamic>? _visitsBox;
  Box<dynamic>? _tripsBox;

  static const _visitsBoxName = 'visits_box';
  static const _tripsBoxName = 'trips_box';
  static const _itemsKey = 'items';

  Future<void> loadFromDisk() async {
    _visitsBox ??= await Hive.openBox<dynamic>(_visitsBoxName);
    _tripsBox ??= await Hive.openBox<dynamic>(_tripsBoxName);

    final rawVisits = (_visitsBox!.get(_itemsKey) as List?) ?? <dynamic>[];
    final rawTrips = (_tripsBox!.get(_itemsKey) as List?) ?? <dynamic>[];

    visits.value = rawVisits.map((v) => Visit.fromMap(v as Map)).toList();
    trips.value = rawTrips.map((t) => TripSegment.fromMap(t as Map)).toList();
  }

  void addLocation(
    LatLng point, {
    required bool isMoving,
    required DateTime at,
    String? activityType,
  }) {
    if (isMoving) {
      _appendToTrip(point, at, activityType: activityType);
      _closeVisit(at);
    } else {
      _appendToVisit(point, at);
      _closeTrip(at);
    }
  }

  void _appendToTrip(LatLng point, DateTime at, {String? activityType}) {
    final normalizedActivity = activityType?.toLowerCase();

    if (_activeTrip != null &&
        normalizedActivity != null &&
        _activeTrip!.activityType != null &&
        _activeTrip!.activityType != normalizedActivity) {
      // End the existing trip when activity changes.
      _closeTrip(at);
    }

    if (_activeTrip == null) {
      _activeTrip = TripSegment(
        points: [point],
        startedAt: at,
        activityType: normalizedActivity,
      );
      trips.value = [...trips.value, _activeTrip!];
      debugPrint(
        "Starting new trip ${trips.value.length} at $at with point $point",
      );
      unawaited(_persistTrips());
    } else {
      _activeTrip!.points.add(point);
      _activeTrip!.activityType ??= normalizedActivity;
      debugPrint("Adding to trip ${trips.value.length} point $point at $at");
    }
  }

  void _closeTrip(DateTime at) {
    if (_activeTrip != null && _activeTrip!.endedAt == null) {
      debugPrint("Closing trip ${trips.value.length} at $at");
      _activeTrip!.endedAt = at;
      trips.value = [...trips.value];
      unawaited(_persistTrips());
      _activeTrip = null;
    }
  }

  void _appendToVisit(LatLng point, DateTime at) {
    if (_activeVisit == null) {
      debugPrint(
        "Starting new visit ${visits.value.length} at $at with point $point",
      );
      _activeVisit = Visit(place: point, arrivedAt: at);
      visits.value = [...visits.value, _activeVisit!];
      unawaited(_persistVisits());
    }
  }

  void _closeVisit(DateTime at) {
    if (_activeVisit != null && _activeVisit!.departedAt == null) {
      debugPrint("Closing visit ${visits.value.length} at $at");
      _activeVisit!.departedAt = at;
      visits.value = [...visits.value];
      unawaited(_persistVisits());
      _activeVisit = null;
    }
  }

  void clear() {
    visits.value = [];
    trips.value = [];
    _activeTrip = null;
    _activeVisit = null;
    unawaited(_persistVisits());
    unawaited(_persistTrips());
  }

  void endActiveSession({DateTime? at}) {
    final now = at ?? DateTime.now();
    _closeTrip(now);
    _closeVisit(now);
  }

  Future<void> _persistVisits() async {
    _visitsBox ??= await Hive.openBox<dynamic>(_visitsBoxName);
    await _visitsBox!.put(
      _itemsKey,
      visits.value.map((v) => v.toMap()).toList(),
    );
  }

  Future<void> _persistTrips() async {
    _tripsBox ??= await Hive.openBox<dynamic>(_tripsBoxName);
    await _tripsBox!.put(_itemsKey, trips.value.map((t) => t.toMap()).toList());
  }
}
