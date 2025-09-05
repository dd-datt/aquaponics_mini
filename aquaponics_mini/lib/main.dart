import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/mqtt_service.dart';
import 'services/api_service.dart';
import 'screens/dashboard.dart';
import 'screens/control_page.dart';
import 'screens/status_page.dart';
import 'screens/ai_page.dart';
import 'screens/settings_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MqttService(broker: 'broker.hivemq.com', clientId: 'aquaponics_mini'),
        ),
        Provider(create: (_) => ApiService(baseUrl: 'https://20b03eb96ea926.lhr.life')),
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
  final List<Widget> _pages = [DashboardPage(), ControlPage(), StatusPage(), AIPage(), SettingsPage()];

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
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Tổng quan'),
          BottomNavigationBarItem(icon: Icon(Icons.power), label: 'Điều khiển'),
          BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'Trạng thái'),
          BottomNavigationBarItem(icon: Icon(Icons.image), label: 'AI & Ảnh'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
    );
  }
}
