// File: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'rooms_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class MyHomePage extends StatefulWidget {
  final String loggedInUserName;
  final String loggedInUserEmail;
  final VoidCallback onLogout;

  MyHomePage({
    required this.loggedInUserName,
    required this.loggedInUserEmail,
    required this.onLogout,
  });

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

// State of the home page with bottom navigation
class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  // List of screens to be displayed based on the bottom navigation selection
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      RoomsScreen(loggedInUserEmail: widget.loggedInUserEmail, loggedInUserName: widget.loggedInUserName),
      NotificationsScreen(loggedInUserEmail: widget.loggedInUserEmail, loggedInUserName: widget.loggedInUserName),
      ProfileScreen(loggedInUserEmail: widget.loggedInUserEmail, loggedInUserName: widget.loggedInUserName), // Displays own profile
      SettingsScreen(onLogout: widget.onLogout),
    ];
  }

  // Called when a bottom navigation item is selected
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Build method that constructs the UI
  @override
  Widget build(BuildContext context) {
    print('MyHomePage build method called');
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Salas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notificações',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configurações',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
