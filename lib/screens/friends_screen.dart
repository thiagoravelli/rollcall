// File: lib/screens/friends_screen.dart

import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  final String loggedInUserEmail;
  final String loggedInUserName;

  const FriendsScreen({
    Key? key,
    required this.loggedInUserEmail,
    required this.loggedInUserName,
  }) : super(key: key);

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final friends = await DatabaseHelper.instance.getUserFriendsByEmail(widget.loggedInUserEmail);
    setState(() {
      _friends = friends;
    });
  }

  Future<void> _removeFriend(int friendId) async {
    int? userId = await DatabaseHelper.instance.getUserIdByEmail(widget.loggedInUserEmail);
    if (userId != null) {
      await DatabaseHelper.instance.removeFriend(userId, friendId);
      _loadFriends();
    }
  }

  Future<void> _searchUsers() async {
    // Navigate to the user search screen
    // Implement user search screen to send friend requests
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
      ),
      body: Column(
        children: [
          // Search bar or button to add new friends
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _searchUsers,
              icon: const Icon(Icons.person_add),
              label: const Text('Adicionar Amigo'),
            ),
          ),
          Expanded(
            child: _friends.isEmpty
                ? const Center(child: Text('Você ainda não tem amigos adicionados.'))
                : ListView.builder(
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(friend['name']),
                        subtitle: Text(friend['email']),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () async {
                            bool confirmRemove = await _showConfirmationDialog(
                                'Remover Amigo', 'Você realmente deseja remover este amigo?');
                            if (confirmRemove) {
                              await _removeFriend(friend['id'] as int);
                            }
                          },
                        ),
                        onTap: () {
                          // Navigate to friend's profile
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                userId: friend['id'] as int,
                                loggedInUserEmail: widget.loggedInUserEmail,
                                loggedInUserName: widget.loggedInUserName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Displays a confirmation dialog
  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context, false),
                ),
                TextButton(
                  child: const Text('Confirmar'),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
