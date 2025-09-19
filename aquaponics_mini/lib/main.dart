import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/mqtt_service.dart';
import 'services/api_service.dart';
import 'screens/dashboard.dart';
import 'screens/status_page.dart';
import 'screens/ai_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MqttService(broker: 'broker.hivemq.com', clientId: 'aquaponics_mini'),
        ),
        Provider(create: (_) => ApiService(baseUrl: 'https://aquaponics-mini.onrender.com')),
      ],
      child: AquaponicsApp(),
    ),
  );
}

class AquaponicsApp extends StatelessWidget {
  const AquaponicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aquaponics Mini',
      theme: ThemeData(primarySwatch: Colors.green),
      home: MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [DashboardPage(), StatusPage(), AIPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey[500],
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'Status'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }
}
