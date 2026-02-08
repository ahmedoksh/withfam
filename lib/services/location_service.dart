import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import '../services/tracking_store.dart';
import '../services/log_service.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';

/// Simple service to initialize background geolocation and expose state.
/// This is an initial scaffold; trip segmentation and persistence will build on top of it.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  final ValueNotifier<bool> isMoving = ValueNotifier<bool>(false);
  final ValueNotifier<double?> batteryLevel = ValueNotifier<double?>(null);
  final ValueNotifier<bool?> isCharging = ValueNotifier<bool?>(null);
  final ValueNotifier<bool> locationServicesEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<int?> authorizationStatus = ValueNotifier<int?>(null);
  final StreamController<bg.Location> _locationStream =
      StreamController<bg.Location>.broadcast();

  bool _lastIsMoving = false;

  Stream<bg.Location> get locations => _locationStream.stream;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final state = await bg.BackgroundGeolocation.ready(
      bg.Config(
        geolocation: const bg.GeoConfig(
          desiredAccuracy: bg.DesiredAccuracy.high,
          distanceFilter: 30.0,
          stopTimeout: 3,
        ),
        app: const bg.AppConfig(stopOnTerminate: false, startOnBoot: true),
        logger: const bg.LoggerConfig(debug: true, logLevel: bg.LogLevel.error),
      ),
    );

    // Seed motion state and fetch an immediate fix so UI has data on launch.
    _lastIsMoving = state.isMoving ?? false;
    isMoving.value = state.isMoving ?? false;
    _fetchInitialLocation();

    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      // print the activity, stationary, in vehicle waking or what
      final at = _parseTimestamp(location.timestamp);
      debugPrint(
        'OnLocation at $at, isMoving: ${location.isMoving}, activity: ${_fmtActivity(location.activity)}',
      );

      LogService.instance.log(
        'onLocation',
        activity: location.activity?.type,
        isMoving: location.isMoving,
        at: at,
        lat: location.coords.latitude,
        lng: location.coords.longitude,
      );

      _updateBattery(location);
      _pushToStore(location);
      if (!_locationStream.isClosed) {
        _locationStream.add(location);
      }
    }, _handleLocationError);

    bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
      final at = _parseTimestamp(location.timestamp);
      debugPrint(
        'OnMotionChange at $at, isMoving: ${location.isMoving}, activity: ${_fmtActivity(location.activity)}',
      );

      LogService.instance.log(
        'onMotionChange',
        activity: location.activity?.type,
        isMoving: location.isMoving,
        at: at,
        lat: location.coords.latitude,
        lng: location.coords.longitude,
      );

      _updateBattery(location);
      if (location.isMoving != _lastIsMoving) {
        TrackingStore.instance.endActiveSession(at: at);
        _lastIsMoving = location.isMoving;
      }
      isMoving.value = location.isMoving;
      _pushToStore(location, atOverride: at);
      if (!_locationStream.isClosed) {
        _locationStream.add(location);
      }
    });

    bg.BackgroundGeolocation.onProviderChange((bg.ProviderChangeEvent event) {
      debugPrint('[onProviderChange: ${event}');

      switch (event.status) {
        case bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED:
          // iOS only
          debugPrint('- Location authorization not determined');
          break;
        case bg.ProviderChangeEvent.AUTHORIZATION_STATUS_RESTRICTED:
          // iOS only
          debugPrint('- Location authorization restricted');
          break;
        case bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED:
          // Android & iOS
          debugPrint('- Location authorization denied');
          break;
        case bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS:
          // Android & iOS
          debugPrint('- Location always granted');
          break;
        case bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE:
          // iOS only
          debugPrint('- Location WhenInUse granted');
          break;
      }

      locationServicesEnabled.value = event.enabled;
      authorizationStatus.value = event.status;
    });

    if (!state.enabled) {
      await bg.BackgroundGeolocation.start();
    }
  }

  void _handleLocationError(bg.LocationError error) {
    // Surface errors for debugging; consider routing to UI if needed.
    debugPrint(
      '[BackgroundGeolocation] onLocation error: ${error.code} ${error.message}',
    );
  }

  void _pushToStore(bg.Location location, {DateTime? atOverride}) {
    final coords = location.coords;
    final at = atOverride ?? _parseTimestamp(location.timestamp);
    final activityType = location.activity?.type;
    TrackingStore.instance.addLocation(
      LatLng(coords.latitude, coords.longitude),
      isMoving: location.isMoving,
      at: at,
      activityType: activityType,
      speed: coords.speed,
      isMovingFlag: location.isMoving,
    );
  }

  String _fmtActivity(bg.Activity? activity) {
    if (activity == null) return 'unknown';
    final type = activity.type;
    final conf = activity.confidence;
    if (conf != null) return '$type ($conf)';
    return type.toString();
  }

  DateTime _parseTimestamp(dynamic ts) {
    if (ts is num) {
      final millis = ts < 1000000000000 ? (ts * 1000).toInt() : ts.toInt();
      // Timestamps from the plugin are UTC epoch; keep as UTC.
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (ts is String) {
      final parsed = DateTime.tryParse(ts);
      if (parsed != null) return parsed.toUtc();
      final num? n = num.tryParse(ts);
      if (n != null) {
        final millis = n < 1000000000000 ? (n * 1000).toInt() : n.toInt();
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
    }
    return DateTime.now().toUtc();
  }

  Future<void> dispose() async {
    await _locationStream.close();
    isMoving.dispose();
    batteryLevel.dispose();
    isCharging.dispose();
    locationServicesEnabled.dispose();
    authorizationStatus.dispose();
  }

  void _updateBattery(bg.Location location) {
    final battery = location.battery;
    batteryLevel.value = battery.level;
    isCharging.value = battery.isCharging;
  }

  Future<void> _fetchInitialLocation() async {
    try {
      final loc = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 1,
        timeout: 20,
        persist: false,
      );
      final at = _parseTimestamp(loc.timestamp);
      _lastIsMoving = loc.isMoving;
      isMoving.value = loc.isMoving;
      _updateBattery(loc);
      LogService.instance.log(
        'fetchInitialLocation',
        activity: loc.activity?.type,
        isMoving: loc.isMoving,
        at: at,
        lat: loc.coords.latitude,
        lng: loc.coords.longitude,
      );
      _pushToStore(loc, atOverride: at);
    } catch (e) {
      debugPrint('Initial location fetch failed: $e');
    }
  }
}
