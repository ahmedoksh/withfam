import 'dart:async';

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/tracking_models.dart';
import 'log_service.dart';

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
    await LogService.instance.load();

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
    double? speed,
    bool? isMovingFlag,
  }) {
    if (isMoving) {
      _appendToTrip(
        point,
        at,
        activityType: activityType,
        speed: speed,
        isMovingFlag: isMovingFlag,
      );
      _closeVisit(at);
    } else {
      _appendToVisit(point, at);
      _closeTrip(at);
    }
  }

  void _appendToTrip(
    LatLng point,
    DateTime at, {
    String? activityType,
    double? speed,
    bool? isMovingFlag,
  }) {
    final normalizedActivity = activityType?.toLowerCase();

    if (_activeTrip != null &&
        normalizedActivity != null &&
        _activeTrip!.activityType != null &&
        _activeTrip!.activityType != normalizedActivity) {
      // End the existing trip when activity changes.
      _closeTrip(at);
    }

    if (_activeTrip == null) {
      _activeTrip = TripSegment(points: [], activityType: normalizedActivity);
      trips.value = [...trips.value, _activeTrip!];
      LogService.instance.log(
        "Starting new trip ${trips.value.length} at $at with point $point",
        activity: normalizedActivity,
        isMoving: true,
        tripIndex: trips.value.length,
        at: at,
        lat: point.latitude,
        lng: point.longitude,
      );
      unawaited(_persistTrips());
    }

    _activeTrip!.addPoint(
      point,
      at,
      activityType: normalizedActivity,
      speed: speed,
      isMoving: isMovingFlag,
    );
    LogService.instance.log(
      "Adding to trip ${trips.value.length} point $point at $at",
      activity: normalizedActivity,
      isMoving: isMovingFlag,
      tripIndex: trips.value.length,
      at: at,
      lat: point.latitude,
      lng: point.longitude,
    );
  }

  void _closeTrip(DateTime at) {
    if (_activeTrip != null) {
      LogService.instance.log(
        "Closing trip ${trips.value.length} at $at",
        activity: _activeTrip!.activityType,
        isMoving: false,
        tripIndex: trips.value.length,
        at: at,
        lat: _activeTrip!.points.isNotEmpty
            ? _activeTrip!.points.last.point.latitude
            : null,
        lng: _activeTrip!.points.isNotEmpty
            ? _activeTrip!.points.last.point.longitude
            : null,
      );
      trips.value = [...trips.value];
      unawaited(_persistTrips());
      _activeTrip = null;
    }
  }

  void _appendToVisit(LatLng point, DateTime at) {
    void startVisit() {
      LogService.instance.log(
        "Starting new visit ${visits.value.length} at $at with point $point",
        isMoving: false,
        at: at,
        lat: point.latitude,
        lng: point.longitude,
      );
      _activeVisit = Visit(place: point, arrivedAt: at);
      visits.value = [...visits.value, _activeVisit!];
      unawaited(_persistVisits());
    }

    if (_activeVisit == null) {
      startVisit();
    } else if (fastDistanceMeters(_activeVisit!.place, point) > 15) {
      // End the existing visit and start a new one.
      _closeVisit(at);
      startVisit();
    } else {
      _activeVisit!.updateMostRecentTime(at);
      unawaited(_persistVisits());
    }
  }

  void _closeVisit(DateTime at) {
    if (_activeVisit != null) {
      LogService.instance.log(
        "Closing visit ${visits.value.length} at $at",
        isMoving: true,
        at: at,
        lat: _activeVisit!.place.latitude,
        lng: _activeVisit!.place.longitude,
      );
      _activeVisit!.updateMostRecentTime(at);
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
