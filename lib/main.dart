// File: lib/main.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure that the database is initialized before the app starts
  await DatabaseHelper.instance.database;

  runApp(const MyApp());
}

// Root widget of the application
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

// State for MyApp to manage login and routing
class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  String? _loggedInUserName;
  String? _loggedInUserEmail;

  // Methods to update login state
  void _updateLoginState(bool isLoggedIn, {String? userName, String? userEmail}) {
    setState(() {
      _isLoggedIn = isLoggedIn;
      _loggedInUserName = userName;
      _loggedInUserEmail = userEmail;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Board Game Hub',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _isLoggedIn
          ? MyHomePage(
              loggedInUserName: _loggedInUserName!,
              loggedInUserEmail: _loggedInUserEmail!,
              onLogout: () => _updateLoginState(false),
            )
          : LoginScreen(
              onLogin: (userName, userEmail) => _updateLoginState(true, userName: userName, userEmail: userEmail),
            ),
    );
  }
}
