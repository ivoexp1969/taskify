import 'package:flutter/material.dart';

import '../task/task_screen.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';
import '../../utils/localization.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = const [
    TaskScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // вече е обвързано с темата – работи и в светъл, и в тъмен режим
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: theme.colorScheme.surface,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBar(
              height: 64,
              // прозрачен фон – използваме контейнера отгоре
              backgroundColor: Colors.transparent,
              indicatorColor:
                  theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.12),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.checklist_rtl_outlined),
                  selectedIcon: const Icon(Icons.checklist_rtl),
                  label: t.tasks,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_today_outlined),
                  selectedIcon: const Icon(Icons.calendar_today),
                  label: t.calendar,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: t.settings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
