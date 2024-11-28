import 'package:flutter/material.dart';
import 'package:rollcall/screens/rooms_screen.dart';
import 'package:rollcall/screens/notifications_screen.dart';
import 'package:rollcall/screens/profile_screen.dart';
import 'package:rollcall/screens/settings_screen.dart';
import 'package:badges/badges.dart' as badges;
import '../services/database_helper.dart';

class MyHomePage extends StatefulWidget {
  final String loggedInUserName;
  final String loggedInUserEmail;
  final VoidCallback onLogout;

  const MyHomePage({
    Key? key,
    required this.loggedInUserName,
    required this.loggedInUserEmail,
    required this.onLogout,
  }) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

// State of the home page with bottom navigation
class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  int _unreadNotificationsCount = 0; // To store the count of unread notifications

  // List of screens to be displayed based on the bottom navigation selection
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      RoomsScreen(
        loggedInUserEmail: widget.loggedInUserEmail,
        loggedInUserName: widget.loggedInUserName,
      ),
      NotificationsScreen(
        loggedInUserEmail: widget.loggedInUserEmail,
        loggedInUserName: widget.loggedInUserName,
        onNotificationsUpdated: _updateNotificationsCount,
      ),
      ProfileScreen(
        loggedInUserEmail: widget.loggedInUserEmail,
        loggedInUserName: widget.loggedInUserName,
      ), // Displays own profile
      SettingsScreen(onLogout: widget.onLogout,
      loggedInUserEmail: widget.loggedInUserEmail,
      loggedInUserName: widget.loggedInUserName,),
    ];

    // Load unread notifications count
    _loadUnreadNotificationsCount();
  }

  // Function to load unread notifications count
  Future<void> _loadUnreadNotificationsCount() async {
    int userId = await _getLoggedInUserId();
    final notifications = await DatabaseHelper.instance.getUnreadNotifications(userId);
    setState(() {
      _unreadNotificationsCount = notifications.length;
    });
  }

  // Helper function to get the logged-in user's ID
  Future<int> _getLoggedInUserId() async {
    final db = await DatabaseHelper.instance.database;
    final result =
        await db.query('users', where: 'email = ?', whereArgs: [widget.loggedInUserEmail]);
    return result.isNotEmpty ? result.first['id'] as int : 0;
  }

  // Called when a bottom navigation item is selected
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Function to update the unread notifications count
  void _updateNotificationsCount() {
    _loadUnreadNotificationsCount();
  }

  // Build method that constructs the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Salas',
          ),
          BottomNavigationBarItem(
            icon: badges.Badge(
              position: badges.BadgePosition.topEnd(top: -5, end: -5),
              showBadge: _unreadNotificationsCount > 0,
              badgeContent: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              child: const Icon(Icons.notifications),
            ),
            label: 'Notificações',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
          const BottomNavigationBarItem(
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
