import 'package:flutter/material.dart';
import '../shared/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/monitor/monitor_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';

class HorusApp extends StatelessWidget {
  const HorusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horus',
      theme: AppTheme.rescueTheme,
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    MonitorScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF16213E),
        indicatorColor: const Color(0xFFFF6B35).withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors, color: Color(0xFFFF6B35)),
            label: 'Rescate',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart, color: Color(0xFF00E676)),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search, color: Color(0xFF00E676)),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Color(0xFF00E676)),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
