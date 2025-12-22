import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/cluster_health_page.dart';
import 'pages/job_metrics_page.dart';
import 'pages/job_management_page.dart';
import 'services/websocket_service.dart';
import 'services/api_service.dart';

void main() {
  runApp(const StreamForgeApp());
}

class StreamForgeApp extends StatelessWidget {
  const StreamForgeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService(baseUrl: 'http://localhost:8080')),
        Provider(create: (_) => WebSocketService(url: 'ws://localhost:8080/ws')),
      ],
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
          fontFamily: 'Inter',
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
    return Scaffold(
      body: Row(
        children: [
          // Sidebar navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: const Color(0xFF1E293B),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'StreamForge',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Cluster'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Metrics'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.work_outline),
                selectedIcon: Icon(Icons.work),
                label: Text('Jobs'),
              ),
            ],
          ),
          
          // Main content
          Expanded(
            child: Container(
              color: const Color(0xFF0F172A),
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
