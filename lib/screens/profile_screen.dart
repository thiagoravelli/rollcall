// File: lib/screens/profile_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId;
  final String loggedInUserEmail;
  final String loggedInUserName;

  const ProfileScreen({super.key, 
    this.userId,
    required this.loggedInUserEmail,
    required this.loggedInUserName,
  });

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isFriend = false;
  bool _requestSent = false;
  int? _loggedInUserId;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    int loggedInUserId = await _getLoggedInUserId();
    setState(() {
      _loggedInUserId = loggedInUserId;
    });

    // Determinar qual usuário exibir
    int displayUserId = widget.userId ?? loggedInUserId;

    final user = await DatabaseHelper.instance.getUserById(displayUserId);
    bool isFriend = await DatabaseHelper.instance.areFriends(loggedInUserId, displayUserId);
    bool requestSent = false;

    if (widget.userId != null) {
      requestSent = await DatabaseHelper.instance.isFriendRequestSent(loggedInUserId, displayUserId);
    }

    setState(() {
      _user = user;
      _isFriend = isFriend;
      _requestSent = requestSent;
    });
  }

  Future<int> _getLoggedInUserId() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [widget.loggedInUserEmail]);
    return result.isNotEmpty ? result.first['id'] as int : 0;
  }

  Future<void> _handleFriendRequest() async {
    if (_loggedInUserId == null || widget.userId == null) return;

    await DatabaseHelper.instance.sendFriendRequest(_loggedInUserId!, widget.userId!);
    
    // Enviar notificação para o usuário solicitado
    await DatabaseHelper.instance.addNotification({
      'user_id': widget.userId!,
      'type': 'friend_request',
      'content': '${widget.loggedInUserName} enviou uma solicitação de amizade',
      'data': _loggedInUserId.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': 0,
    });
    setState(() {
      _requestSent = true;
    });


  }

  Future<void> _cancelFriendRequest() async {
    if (_loggedInUserId == null || widget.userId == null) return;

    bool confirm = await _showConfirmationDialog('Cancelar Solicitação', 'Deseja cancelar a solicitação de amizade?');
    if (confirm) {
      await DatabaseHelper.instance.cancelFriendRequest(_loggedInUserId!, widget.userId!);
      setState(() {
        _requestSent = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  child: const Text('Não'),
                  onPressed: () => Navigator.pop(context, false),
                ),
                TextButton(
                  child: const Text('Sim'),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null || _loggedInUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final userName = _user!['name'];
    final userEmail = _user!['email'];
    const userPhoto = 'https://via.placeholder.com/150';

    // Determinar se é o perfil do usuário logado ou de outro
    bool isOwnProfile = widget.userId == null || widget.userId == _loggedInUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(userPhoto),
              radius: 50,
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: const TextStyle(fontSize: 24),
            ),
            Text(
              userEmail,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            // Detalhes adicionais do perfil podem ser adicionados aqui
            if (!isOwnProfile)
              _isFriend
                  ? const Text('Vocês são amigos')
                  : _requestSent
                      ? ElevatedButton(
                          onPressed: _cancelFriendRequest,
                          child: const Text('Cancelar Solicitação'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        )
                      : ElevatedButton(
                          onPressed: _handleFriendRequest,
                          child: const Text('Solicitar Amizade'),
                        ),
          ],
        ),
      ),
    );
  }
}
