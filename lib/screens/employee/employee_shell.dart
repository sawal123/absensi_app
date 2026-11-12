import 'package:flutter/material.dart';

import '../../widgets/app_bottom_nav.dart';
import '../shared/profile_tab.dart';
import 'history_tab.dart';
import 'home_tab.dart';
import 'requests_tab.dart';
import 'schedule_tab.dart';

class EmployeeShell extends StatefulWidget {
  const EmployeeShell({super.key});

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  int _index = 0;

  static const _destinations = [
    NavDestination(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Beranda',
    ),
    NavDestination(
      icon: Icons.history_rounded,
      activeIcon: Icons.history_rounded,
      label: 'Riwayat',
    ),
    NavDestination(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Jadwal',
    ),
    NavDestination(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: 'Pengajuan',
    ),
    NavDestination(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
    ),
  ];

  void _openTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeTab(onOpenTab: _openTab),
          const HistoryTab(),
          const ScheduleTab(),
          const RequestsTab(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        destinations: _destinations,
        index: _index,
        onTap: _openTab,
      ),
    );
  }
}
