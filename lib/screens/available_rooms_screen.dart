// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../screens/room_screen.dart';
import '../screens/create_room_screen.dart';

class AvailableRoomsScreen extends StatefulWidget {
  final String loggedInUserEmail;
  final String loggedInUserName;

  const AvailableRoomsScreen({super.key, 
    required this.loggedInUserEmail,
    required this.loggedInUserName,
  });
  @override
  _AvailableRoomsScreenState createState() => _AvailableRoomsScreenState();
}

class _AvailableRoomsScreenState extends State<AvailableRoomsScreen> {
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final rooms = await DatabaseHelper.instance.getRooms();
    setState(() {
      _rooms = rooms;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salas Disponíveis'),
      ),
      body: _rooms.isEmpty
          ? const Center(child: Text('Nenhuma sala disponível.'))
          : ListView.builder(
              itemCount: _rooms.length,
              itemBuilder: (context, index) {
                final room = _rooms[index];
                final dateTime = DateTime.parse(room['dateTime']);
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.videogame_asset),
                    title: Text(room['gameName']),
                    subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)} - ${room['address']}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RoomScreen(roomId: room['id'], loggedInUserEmail: widget.loggedInUserEmail, loggedInUserName: widget.loggedInUserName,)),
                      ).then((value) {
                        // Reload rooms after returning from room details
                        _loadRooms();
                      });
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to CreateRoomScreen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateRoomScreen(loggedInUserEmail: widget.loggedInUserEmail, loggedInUserName: widget.loggedInUserName)),
          ).then((value) {
            // Reload rooms after creating a new one
            _loadRooms();
          });
        },
        tooltip: 'Criar nova sala',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}