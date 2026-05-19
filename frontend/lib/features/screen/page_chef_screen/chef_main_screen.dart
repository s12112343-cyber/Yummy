import 'package:flutter/material.dart';

import 'chef_dashboard_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class ChefMainScreen extends StatefulWidget {
  const ChefMainScreen({super.key});

  @override
  State<ChefMainScreen> createState() => _ChefMainScreenState();
}

class _ChefMainScreenState extends State<ChefMainScreen> {
  int _index = 0; // ✅ بداية من 0

  final List<Widget> _pages = const [
    ChefDashboardScreen(),
    ChefOrdersScreen(),
    ChefProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: const Color(0xFF1C4D8D),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // ✅ أضف هذا للسلس
        onTap: (i) {
          setState(() => _index = i);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: "Orders",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
