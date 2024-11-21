// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../screens/room_screen.dart';

class ParticipatingRoomsScreen extends StatefulWidget {
  final String loggedInUserEmail;
  final String loggedInUserName;

  const ParticipatingRoomsScreen({super.key, 
    required this.loggedInUserEmail,
    required this.loggedInUserName,
  });
  @override
  _ParticipatingRoomsScreenState createState() => _ParticipatingRoomsScreenState();
}

class _ParticipatingRoomsScreenState extends State<ParticipatingRoomsScreen> {
  List<Map<String, dynamic>> _participatingRooms = [];

  @override
  void initState() {
    super.initState();
    _loadParticipatingRooms();
  }

  Future<void> _loadParticipatingRooms() async {
    int userId = await _getLoggedInUserId();
    // Get all room participants
    final participants = await DatabaseHelper.instance.getRoomParticipantsWithUserId(userId);

    // For each participant, get room details
    List<Map<String, dynamic>> rooms = [];
    for (var participant in participants) {
      final room = await DatabaseHelper.instance.getRoomById(participant['room_id']);
      if (room != null) {
        rooms.add(room);
      }
    }

    setState(() {
      _participatingRooms = rooms;
    });
  }

  Future<int> _getLoggedInUserId() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [widget.loggedInUserEmail]);
    return result.isNotEmpty ? result.first['id'] as int : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salas Participando'),
      ),
      body: _participatingRooms.isEmpty
          ? const Center(child: Text('Você não está participando de nenhuma sala.'))
          : ListView.builder(
              itemCount: _participatingRooms.length,
              itemBuilder: (context, index) {
                final participatingRoom = _participatingRooms[index];
                final dateTime = DateTime.parse(participatingRoom['dateTime']);
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.videogame_asset),
                    title: Text(participatingRoom['gameName']),
                    subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)} - ${participatingRoom['address']}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RoomScreen(roomId: participatingRoom['id'], loggedInUserEmail: widget.loggedInUserEmail, loggedInUserName: widget.loggedInUserName,)),
                      ).then((value) {
                        // Reload participating rooms after returning from room details
                        _loadParticipatingRooms();
                      });
                    },
                  ),
                );
              },
            ),
    );
  }
}
