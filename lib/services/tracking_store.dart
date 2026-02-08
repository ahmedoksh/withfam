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
    final normalizedActivity = activityType?.toLowerCase();
    final resolvedIsMoving = _resolveIsMoving(
      isMoving,
      normalizedActivity,
      isMovingFlag,
    );

    if (resolvedIsMoving) {
      _appendToTrip(
        point,
        at,
        activityType: normalizedActivity,
        speed: speed,
        isMovingFlag: resolvedIsMoving,
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
    if (_activeTrip != null &&
        activityType != null &&
        _activeTrip!.activityType != null &&
        _activeTrip!.activityType != activityType) {
      // End the existing trip when activity changes.
      _closeTrip(at);
    }

    if (_activeTrip == null) {
      _activeTrip = TripSegment(points: [], activityType: activityType);
      trips.value = [...trips.value, _activeTrip!];
      LogService.instance.log(
        "Starting new trip ${trips.value.length + 1} at $at with point ${_fmtLatLng(point)}",
        activity: activityType,
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
      activityType: activityType,
      speed: speed,
      isMoving: isMovingFlag,
    );
    LogService.instance.log(
      "Adding to trip ${trips.value.length} point ${_fmtLatLng(point)} at $at",
      activity: activityType,
      isMoving: isMovingFlag,
      tripIndex: trips.value.length,
      at: at,
      lat: point.latitude,
      lng: point.longitude,
    );
  }

  bool _resolveIsMoving(
    bool isMoving,
    String? activityType,
    bool? isMovingFlag,
  ) {
    final fromActivity = _activityImpliesMoving(activityType);
    if (fromActivity != null) return fromActivity;
    if (isMovingFlag != null) return isMovingFlag;
    return isMoving;
  }

  bool? _activityImpliesMoving(String? activityType) {
    if (activityType == null) return null;
    switch (activityType) {
      case 'still':
      case 'stationary':
        return false;
      case 'unknown':
        return null;
      default:
        return true;
    }
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
        "Starting new visit ${visits.value.length + 1} at ${_fmtLocal(at)} with point ${_fmtLatLng(point)}",
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
      LogService.instance.log(
        "Updating last visit ${visits.value.length} end time to ${_fmtLocal(at)}",
        isMoving: false,
        at: at,
        lat: point.latitude,
        lng: point.longitude,
      );
      _activeVisit!.updateMostRecentTime(at);
      unawaited(_persistVisits());
    }
  }

  void _closeVisit(DateTime at) {
    if (_activeVisit != null) {
      LogService.instance.log(
        "Closing visit ${visits.value.length} at ${_fmtLocal(at)}",
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

  String _fmtLocal(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${hour12.toString().padLeft(2, '0')}:$minute:$second $ampm';
  }

  String _fmtLatLng(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
}
