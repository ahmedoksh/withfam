import 'package:apple_maps_flutter/apple_maps_flutter.dart';

class Visit {
  Visit({required this.place, required this.arrivedAt, this.departedAt});

  final LatLng place;
  final DateTime arrivedAt;
  DateTime? departedAt;

  Duration get duration =>
      (departedAt ?? DateTime.now()).difference(arrivedAt).abs();

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

class TripSegment {
  TripSegment({
    required this.points,
    required this.startedAt,
    this.endedAt,
    this.activityType,
  });

  final List<LatLng> points;
  final DateTime startedAt;
  DateTime? endedAt;
  String? activityType;

  Duration get duration =>
      (endedAt ?? DateTime.now()).difference(startedAt).abs();

  Map<String, dynamic> toMap() {
    return {
      'points': points.map(_latLngToMap).toList(),
      'startedAt': startedAt.millisecondsSinceEpoch,
      'endedAt': endedAt?.millisecondsSinceEpoch,
      'activityType': activityType,
    };
  }

  static TripSegment fromMap(Map map) {
    final rawPoints = (map['points'] as List?) ?? <dynamic>[];
    return TripSegment(
      points: rawPoints.map((p) => _latLngFromMap(p as Map)).toList(),
      startedAt: _ts(map['startedAt']),
      endedAt: map['endedAt'] != null ? _ts(map['endedAt']) : null,
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
