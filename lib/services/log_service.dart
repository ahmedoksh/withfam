import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LogEntry {
  const LogEntry({
    required this.message,
    required this.timestamp,
    this.activity,
    this.isMoving,
    this.tripIndex,
    this.lat,
    this.lng,
  });

  final String message;
  final DateTime timestamp;
  final String? activity;
  final bool? isMoving;
  final int? tripIndex;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toMap() => {
    'message': message,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'activity': activity,
    'isMoving': isMoving,
    'tripIndex': tripIndex,
    'lat': lat,
    'lng': lng,
  };

  factory LogEntry.fromMap(Map map) => LogEntry(
    message: (map['message'] as String?) ?? '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    ),
    activity: map['activity'] as String?,
    isMoving: map['isMoving'] as bool?,
    tripIndex: (map['tripIndex'] as num?)?.toInt(),
    lat: (map['lat'] as num?)?.toDouble(),
    lng: (map['lng'] as num?)?.toDouble(),
  );
}

class LogService {
  LogService._();

  static final LogService instance = LogService._();

  final ValueNotifier<List<LogEntry>> logs = ValueNotifier<List<LogEntry>>([]);
  Box<dynamic>? _box;

  static const _boxName = 'logs_box';
  static const _itemsKey = 'items';
  static const _maxEntries = 500;

  Future<void> load() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
    final raw = (_box!.get(_itemsKey) as List?) ?? <dynamic>[];
    logs.value = raw
        .map((e) => LogEntry.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  void log(
    String message, {
    String? activity,
    bool? isMoving,
    int? tripIndex,
    DateTime? at,
    double? lat,
    double? lng,
  }) {
    final entry = LogEntry(
      message: message,
      timestamp: at ?? DateTime.now(),
      activity: activity,
      isMoving: isMoving,
      tripIndex: tripIndex,
      lat: lat,
      lng: lng,
    );

    final updated = [...logs.value, entry];
    if (updated.length > _maxEntries) {
      updated.removeRange(0, updated.length - _maxEntries);
    }
    logs.value = updated;
    unawaited(_persist());
    debugPrint(message);
  }

  Future<void> clear() async {
    logs.value = [];
    await _persist();
  }

  Future<void> _persist() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
    await _box!.put(_itemsKey, logs.value.map((e) => e.toMap()).toList());
  }
}
