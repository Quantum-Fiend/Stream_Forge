import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/cluster_health_page.dart';
import 'pages/job_metrics_page.dart';
import 'pages/job_management_page.dart';
import 'services/api_service.dart';

void main() {
  runApp(const StreamForgeApp());
}

class StreamForgeApp extends StatelessWidget {
  const StreamForgeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (_) => ApiService(baseUrl: 'http://localhost:8080'),
      child: MaterialApp(
        title: 'StreamForge Dashboard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          // Inter font removed — was declared in pubspec but files don't exist.
          // Flutter falls back to a clean system sans-serif automatically.
        ),
        home: const DashboardHome(),
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  const DashboardHome({Key? key}) : super(key: key);

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    ClusterHealthPage(),
    JobMetricsPage(),
    JobManagementPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    if (isNarrow) {
      // Compact bottom-nav layout for narrow / mobile widths
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: _pages[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          backgroundColor: const Color(0xFF1E293B),
          indicatorColor: const Color(0xFF6366F1).withOpacity(0.25),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: Color(0xFF6366F1)),
              label: 'Cluster',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics, color: Color(0xFF6366F1)),
              label: 'Metrics',
            ),
            NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work, color: Color(0xFF6366F1)),
              label: 'Jobs',
            ),
          ],
        ),
      );
    }

    // Wide layout — sidebar rail
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            backgroundColor: const Color(0xFF1E293B),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme:
                const IconThemeData(color: Color(0xFF6366F1)),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
            indicatorColor: const Color(0xFF6366F1).withOpacity(0.15),
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'StreamForge',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: Text('Cluster'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics_rounded),
                label: Text('Metrics'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.work_outline_rounded),
                selectedIcon: Icon(Icons.work_rounded),
                label: Text('Jobs'),
              ),
            ],
          ),
          // Subtle divider line
          Container(width: 1, color: Colors.white.withOpacity(0.06)),
          // Page content
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
