import 'package:flutter/material.dart';

import 'package:withfam/widgets/rounded_nav_bar.dart';

import '../ads/ads_screen.dart';
import '../history/history_screen.dart';
import '../logs/log_screen.dart';
import '../map/map_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    NavItem(title: 'Map', icon: Icons.map_rounded, child: MapScreen()),
    NavItem(title: 'History', icon: Icons.history, child: HistoryScreen()),
    NavItem(title: 'Logs', icon: Icons.list_alt_rounded, child: LogScreen()),
    NavItem(title: 'Ads', icon: Icons.ad_units, child: AdsScreen()),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final current = _navItems[_selectedIndex];
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: _navItems
                  .map((item) => item.child)
                  .toList(growable: false),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(15, 10, 15, bottomInset / 2),
              child: RoundedNavBar(
                items: _navItems,
                selectedIndex: _selectedIndex,
                onItemSelected: _onItemTapped,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
