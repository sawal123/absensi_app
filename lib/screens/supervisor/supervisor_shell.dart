import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/approval_provider.dart';
import '../../widgets/app_bottom_nav.dart';
import '../shared/profile_tab.dart';
import 'approvals_tab.dart';
import 'dashboard_tab.dart';
import 'schedule_management_tab.dart';
import 'team_tab.dart';

class SupervisorShell extends StatefulWidget {
  const SupervisorShell({super.key});

  @override
  State<SupervisorShell> createState() => _SupervisorShellState();
}

class _SupervisorShellState extends State<SupervisorShell> {
  int _index = 0;

  static const _destinations = [
    NavDestination(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Beranda',
    ),
    NavDestination(
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2_rounded,
      label: 'Tim',
    ),
    NavDestination(
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      label: 'Persetujuan',
    ),
    NavDestination(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Jadwal',
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
    final approvals = context.watch<ApprovalProvider>();
    final destinations = [
      _destinations[0],
      _destinations[1],
      NavDestination(
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check_rounded,
        label: 'Persetujuan',
        badge: approvals.pendingCount,
      ),
      _destinations[3],
      _destinations[4],
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardTab(onOpenTab: _openTab),
          const TeamTab(),
          const ApprovalsTab(),
          const ScheduleManagementTab(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        destinations: destinations,
        index: _index,
        onTap: _openTab,
      ),
    );
  }
}
