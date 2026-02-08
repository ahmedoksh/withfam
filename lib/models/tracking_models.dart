import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';

class Visit {
  Visit({required this.place, required this.arrivedAt, DateTime? departedAt})
    : departedAt = departedAt ?? arrivedAt;

  final LatLng place;
  final DateTime arrivedAt;
  DateTime? departedAt;

  Duration get duration =>
      (departedAt ?? DateTime.now()).difference(arrivedAt).abs();

  DateTime get recentTime => departedAt ?? arrivedAt;

  void updateMostRecentTime(DateTime at) {
    if (at.isAfter(arrivedAt) &&
        (departedAt == null || at.isAfter(departedAt!))) {
      departedAt = at;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'place': _latLngToMap(place),
      'arrivedAt': arrivedAt.millisecondsSinceEpoch,
      'departedAt': departedAt?.millisecondsSinceEpoch,
    };
  }

  static Visit fromMap(Map map) {
    return Visit(
      place: _latLngFromMap(map['place'] as Map),
      arrivedAt: _ts(map['arrivedAt']),
      departedAt: map['departedAt'] != null ? _ts(map['departedAt']) : null,
    );
  }
}

class PointInfo {
  const PointInfo({
    required this.point,
    required this.timestamp,
    this.activityType,
    this.speed,
    this.isMoving,
  });

  final LatLng point;
  final DateTime timestamp;
  final String? activityType;
  final double? speed;
  final bool? isMoving;

  Map<String, dynamic> toMap() => {
    'point': _latLngToMap(point),
    'timestamp': timestamp.millisecondsSinceEpoch,
    'activityType': activityType,
    'speed': speed,
    'isMoving': isMoving,
  };

  factory PointInfo.fromMap(Map map) {
    return PointInfo(
      point: _latLngFromMap((map['point'] ?? map) as Map),
      timestamp: _ts(map['timestamp']),
      activityType: map['activityType'] as String?,
      speed: (map['speed'] as num?)?.toDouble(),
      isMoving: map['isMoving'] as bool?,
    );
  }
}

class TripSegment {
  TripSegment({List<PointInfo>? points, this.activityType})
    : points = points ?? [];

  final List<PointInfo> points;
  String? activityType;

  void addPoint(
    LatLng point,
    DateTime at, {
    String? activityType,
    double? speed,
    bool? isMoving,
  }) {
    points.add(
      PointInfo(
        point: point,
        timestamp: at,
        activityType: activityType,
        speed: speed,
        isMoving: isMoving,
      ),
    );
    this.activityType ??= activityType;
  }

  DateTime? get startedAt => points.isEmpty ? null : points.first.timestamp;
  DateTime? get endedAt => points.isEmpty ? null : points.last.timestamp;

  Duration? get duration {
    final start = startedAt;
    final end = endedAt;
    if (start == null || end == null) return null;
    return end.difference(start).abs();
  }

  double get distanceMeters {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += fastDistanceMeters(points[i - 1].point, points[i].point);
    }
    return total;
  }

  Map<String, dynamic> toMap() {
    return {
      'points': points.map((p) => p.toMap()).toList(),
      'activityType': activityType,
    };
  }

  static TripSegment fromMap(Map map) {
    final rawPoints = (map['points'] as List?) ?? <dynamic>[];
    final pts = rawPoints.map((p) => PointInfo.fromMap(p as Map)).toList();
    return TripSegment(
      points: pts,
      activityType: map['activityType'] as String?,
    );
  }
}

Map<String, double> _latLngToMap(LatLng latLng) => {
  'lat': latLng.latitude,
  'lng': latLng.longitude,
};

LatLng _latLngFromMap(Map map) {
  final lat = (map['lat'] as num).toDouble();
  final lng = (map['lng'] as num).toDouble();
  return LatLng(lat, lng);
}

DateTime _ts(dynamic value) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    final n = num.tryParse(value);
    if (n != null) return DateTime.fromMillisecondsSinceEpoch(n.toInt());
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

double fastDistanceMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0; // meters
  final x =
      _degToRad(b.longitude - a.longitude) *
      math.cos(_degToRad((a.latitude + b.latitude) / 2));
  final y = _degToRad(b.latitude - a.latitude);
  return earthRadius * math.sqrt(x * x + y * y);
}

double _degToRad(double deg) => deg * (math.pi / 180.0);
