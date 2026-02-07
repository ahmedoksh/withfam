import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'services/location_service.dart';
import 'services/tracking_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await TrackingStore.instance.loadFromDisk();
  await LocationService.instance.initialize();
  runApp(const WithFamApp());
}
