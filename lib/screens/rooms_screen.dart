// File: lib/screens/rooms_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import 'room_screen.dart';
import 'create_room_screen.dart';

class RoomsScreen extends StatefulWidget {
  final String loggedInUserEmail;
  final String loggedInUserName;

  const RoomsScreen({super.key, 
    required this.loggedInUserEmail,
    required this.loggedInUserName,
  });
  @override
  _RoomsScreenState createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _availableRooms = [];
  List<Map<String, dynamic>> _participatingRooms = [];
  List<Map<String, dynamic>> _friendsRooms = [];


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRooms();
  }

Future<void> _loadRooms() async {
  final rooms = await DatabaseHelper.instance.getRooms();

  // Load participating rooms
  int userId = await _getLoggedInUserId();
  final participants = await DatabaseHelper.instance.getRoomParticipantsWithUserId(userId);

  List<Map<String, dynamic>> participatingRooms = [];
  for (var participant in participants) {
    final room = await DatabaseHelper.instance.getRoomById(participant['room_id']);
    if (room != null) {
      participatingRooms.add(room);
    }
  }

  // Load rooms created by friends
  List<Map<String, dynamic>> friends = await DatabaseHelper.instance.getUserFriendsByEmail(widget.loggedInUserEmail);
  List<String> friendsEmails = friends.map((friend) => friend['email'] as String).toList();

  List<Map<String, dynamic>> friendsRooms = [];
  for (var room in rooms) {
    String creatorEmail = room['creatorEmail'] as String;
    if (friendsEmails.contains(creatorEmail)) {
      friendsRooms.add(room);
    }
  }

  setState(() {
    _availableRooms = rooms;
    _participatingRooms = participatingRooms;
    _friendsRooms = friendsRooms;
  });
}


  Future<int> _getLoggedInUserId() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [widget.loggedInUserEmail]);
    return result.isNotEmpty ? result.first['id'] as int : 0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Método build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Disponíveis'),
            Tab(text: 'Participando'),
            Tab(text: 'Amigos'),
          ],
        ),
      ),
      body: TabBarView(
  controller: _tabController,
  children: [
    // Disponíveis Tab
    _availableRooms.isEmpty
        ? const Center(child: Text('Nenhuma sala disponível.'))
        : ListView.builder(
            itemCount: _availableRooms.length,
            itemBuilder: (context, index) {
              final room = _availableRooms[index];
              final dateTime = DateTime.parse(room['dateTime']);
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: const Icon(Icons.videogame_asset),
                  title: Text(room['gameName']),
                  subtitle: Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)} - ${room['address']}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomScreen(
                          roomId: room['id'],
                          loggedInUserEmail: widget.loggedInUserEmail,
                          loggedInUserName: widget.loggedInUserName,
                        ),
                      ),
                    ).then((value) {
                      _loadRooms();
                    });
                  },
                ),
              );
            },
          ),
    // Participando Tab
    _participatingRooms.isEmpty
        ? const Center(child: Text('Você não está participando de nenhuma sala.'))
        : ListView.builder(
            itemCount: _participatingRooms.length,
            itemBuilder: (context, index) {
              final room = _participatingRooms[index];
              final dateTime = DateTime.parse(room['dateTime']);
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: const Icon(Icons.videogame_asset),
                  title: Text(room['gameName']),
                  subtitle: Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)} - ${room['address']}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomScreen(
                          roomId: room['id'],
                          loggedInUserEmail: widget.loggedInUserEmail,
                          loggedInUserName: widget.loggedInUserName,
                        ),
                      ),
                    ).then((value) {
                      _loadRooms();
                    });
                  },
                ),
              );
            },
          ),
    // Amigos Tab
    _friendsRooms.isEmpty
        ? const Center(child: Text('Nenhuma sala de amigos disponível.'))
        : ListView.builder(
            itemCount: _friendsRooms.length,
            itemBuilder: (context, index) {
              final room = _friendsRooms[index];
              final dateTime = DateTime.parse(room['dateTime']);
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: const Icon(Icons.videogame_asset),
                  title: Text(room['gameName']),
                  subtitle: Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)} - ${room['address']}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomScreen(
                          roomId: room['id'],
                          loggedInUserEmail: widget.loggedInUserEmail,
                          loggedInUserName: widget.loggedInUserName,
                        ),
                      ),
                    ).then((value) {
                      _loadRooms();
                    });
                  },
                ),
              );
            },
          ),
  ],
),

      floatingActionButton: _tabController.index == 0
    ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateRoomScreen(
                loggedInUserEmail: widget.loggedInUserEmail,
                loggedInUserName: widget.loggedInUserName,
              ),
            ),
          ).then((value) {
            _loadRooms();
          });
        },
        tooltip: 'Criar nova sala',
        child: const Icon(Icons.add),
      )
    : null,
    );
  }
}
