// File: lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'friends_screen.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;
  final String loggedInUserEmail;
  final String loggedInUserName;

  const SettingsScreen({
    Key? key,
    required this.onLogout,
    required this.loggedInUserEmail,
    required this.loggedInUserName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Amigos'),
            onTap: () {
              // Navigate to FriendsScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FriendsScreen(
                    loggedInUserEmail: loggedInUserEmail,
                    loggedInUserName: loggedInUserName,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Sair'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
