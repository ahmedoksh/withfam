import 'package:flutter/material.dart';

import '../../services/tracking_store.dart';
import 'history_list.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TrackingStore.instance;

    return ValueListenableBuilder(
      valueListenable: store.visits,
      builder: (context, visits, _) {
        return ValueListenableBuilder(
          valueListenable: store.trips,
          builder: (context, trips, __) {
            return HistoryList(visits: visits, trips: trips);
          },
        );
      },
    );
  }
}
