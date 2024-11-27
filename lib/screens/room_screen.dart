// File: lib/screens/room_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rollcall/screens/profile_screen.dart';
import '../services/database_helper.dart';

// Placeholder image for games
String _gameImageURL = 'https://via.placeholder.com/150';

class RoomScreen extends StatefulWidget {
  final int roomId;
  final String loggedInUserEmail;
  final String loggedInUserName;

  const RoomScreen({
    Key? key,
    required this.roomId,
    required this.loggedInUserEmail,
    required this.loggedInUserName,
  }) : super(key: key);

  @override
  _RoomScreenState createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  Map<String, dynamic>? _room;
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isCreator = false;
  bool _isParticipant = false;
  bool _hasPendingJoinRequest = false;
  List<Map<String, dynamic>> _joinRequests = [];

  final _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoomDetails();
  }

  Future<void> _loadRoomDetails() async {
    // Fetch room details
    final room = await DatabaseHelper.instance.getRoomById(widget.roomId);
    if (!mounted) return;
    if (room == null) {
      // If the room doesn't exist, return
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sala não encontrada.')),
      );
      Navigator.pop(context);
      return;
    }

    // Check if the logged-in user is the creator
    _isCreator = (room['creatorName'] == widget.loggedInUserName);

    // Get the user ID of the logged-in user
    int userId = await _getLoggedInUserId();

    // Load participants
    final participants = await DatabaseHelper.instance.getRoomParticipants(widget.roomId);

    // Check if the logged-in user is a participant
    _isParticipant = participants.any((participant) => participant['user_id'] == userId);

    // Check if user has a pending join request
    final pendingRequests = await DatabaseHelper.instance.getRoomJoinRequestsForUser(widget.roomId, userId);

    // Load chat messages
    final chatMessages = await DatabaseHelper.instance.getChatMessages(widget.roomId);

    // If user is the creator, load pending join requests
    List<Map<String, dynamic>> joinRequests = [];
    if (_isCreator) {
      joinRequests = await DatabaseHelper.instance.getRoomJoinRequests(widget.roomId);
    }

    setState(() {
      _room = room;
      _participants = participants;
      _chatMessages = chatMessages;
      _hasPendingJoinRequest = pendingRequests.isNotEmpty;
      _joinRequests = joinRequests;
    });
  }

  // Helper function to get the logged-in user's ID
  Future<int> _getLoggedInUserId() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [widget.loggedInUserEmail]);
    return result.isNotEmpty ? result.first['id'] as int : 0;
  }

  // Handles the user's request to join the room
  Future<void> _handleJoinRoom() async {
    int userId = await _getLoggedInUserId();
    // Send a join request
    await DatabaseHelper.instance.sendRoomJoinRequest(widget.roomId, userId);

    // Send notification to the room creator
    final creator = await DatabaseHelper.instance.getUserByName(_room!['creatorName']);
    if (creator != null) {
      await DatabaseHelper.instance.addNotification({
        'user_id': creator['id'],
        'type': 'room_join_request',
        'content': '${widget.loggedInUserName} solicitou para entrar na sua sala',
        'data': '${widget.roomId},$userId',
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
      });
    }

    if (!mounted) return;
    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitação enviada ao criador da sala.')),
    );

    _loadRoomDetails();
  }

  // Handles the user leaving the room
  Future<void> _handleLeaveRoom() async {
    bool confirmLeave = await _showConfirmationDialog('Sair da Sala', 'Você realmente deseja sair da sala?');
    if (confirmLeave) {
      int userId = await _getLoggedInUserId();
      await DatabaseHelper.instance.removeParticipant(widget.roomId, userId);
      // Add system message to chat about the user leaving
      await _addSystemMessage('${widget.loggedInUserName} saiu da sala...');
      _loadRoomDetails();
    }
  }

  // Handles removing a participant (only by the creator)
  Future<void> _handleRemoveParticipant(int userId) async {
    bool confirmRemove = await _showConfirmationDialog('Remover Participante', 'Você realmente deseja remover este participante?');
    if (confirmRemove) {
      final user = await DatabaseHelper.instance.getUserById(userId);
      await DatabaseHelper.instance.removeParticipant(widget.roomId, userId);
      // Add system message to chat about the user being removed
      if (user != null) {
        await _addSystemMessage('${user['name']} foi expulso da sala...');
      }
      _loadRoomDetails();
    }
  }

  // Handles deleting the room (only by the creator)
  Future<void> _handleDeleteRoom() async {
    bool confirmDelete = await _showConfirmationDialog('Excluir Sala', 'Você realmente deseja excluir esta sala?');
    if (confirmDelete) {
      await DatabaseHelper.instance.deleteRoom(widget.roomId);
      if (!mounted) return;
      Navigator.pop(context);
    }
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

  // Handles sending a chat message
  Future<void> _handleSendMessage() async {
    if (_chatController.text.trim().isEmpty) return;

    final message = {
      'room_id': widget.roomId,
      'user_name': widget.loggedInUserName,
      'message': _chatController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    await DatabaseHelper.instance.addChatMessage(message);
    _chatController.clear();
    _loadRoomDetails();
  }

  // Adds a system message to the chat
  Future<void> _addSystemMessage(String content) async {
    final message = {
      'room_id': widget.roomId,
      'user_name': 'Sistema',
      'message': content,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await DatabaseHelper.instance.addChatMessage(message);
  }

  // Handles inviting a friend
  Future<void> _handleInviteFriend() async {
    int userId = await _getLoggedInUserId();
    // Fetch the user's friends
    final friends = await DatabaseHelper.instance.getUserFriends(userId);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Convidar Amigos'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return ListTile(
                  title: Text(friend['name']),
                  trailing: IconButton(
                    icon: const Icon(Icons.email),
                    onPressed: () async {
                      // Send invitation
                      await DatabaseHelper.instance.sendRoomInvitation(
                        widget.roomId,
                        userId,
                        friend['id'] as int,
                      );
                      // Send notification to the friend
                      await DatabaseHelper.instance.addNotification({
                        'user_id': friend['id'],
                        'type': 'room_invitation',
                        'content': '${widget.loggedInUserName} convidou você para uma sala',
                        'data': widget.roomId.toString(),
                        'timestamp': DateTime.now().toIso8601String(),
                        'is_read': 0,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Convite enviado para ${friend['name']}')),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Fechar'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sala')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final gameName = _room!['gameName'];
    final creatorName = _room!['creatorName'];
    final dateTime = DateTime.parse(_room!['dateTime']);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sala: $gameName'),
      ),
      body: Column(
        children: [
          // Game details
          Container(
  padding: const EdgeInsets.all(16.0),
  child: Column(
    children: [
      // Display game thumbnail if available
      if (_room!['thumbnailUrl'] != null && _room!['thumbnailUrl'].isNotEmpty)
        Image.network(_room!['thumbnailUrl'], width: 150, height: 150, fit: BoxFit.cover)
      else
        Image.network(_gameImageURL, width: 150, height: 150, fit: BoxFit.cover),
      const SizedBox(height: 8),
      Text('Jogo: ${_room!['gameName']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text('Autor da sala: ${_room!['creatorName']}', style: const TextStyle(fontSize: 16)),
      Text('Data e hora: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_room!['dateTime']))}', style: const TextStyle(fontSize: 16)),
      // Display min and max players
      if (_room!['minPlayers'] != null && _room!['maxPlayers'] != null)
        Text('Jogadores: ${_room!['minPlayers']} - ${_room!['maxPlayers']}'),
      // Display playing time
      if (_room!['playingTime'] != null)
        Text('Tempo de jogo: ${_room!['playingTime']} minutos'),
    ],
  ),
),
          const Divider(),
          // Participants and Chat
          Expanded(
            child: Row(
              children: [
                // Participants List
                Container(
                  width: MediaQuery.of(context).size.width * 0.4, // Two fifths of the screen
                  child: Column(
                    children: [
                      // Seats info and Invite button
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Text('Participantes (${_participants.length})'),
                            Spacer(),
                            if (_isParticipant || _isCreator)
                              IconButton(
                                icon: const Icon(Icons.person_add),
                                onPressed: _handleInviteFriend,
                              ),
                          ],
                        ),
                      ),
                      // Participants List
                      Expanded(
                        child: ListView(
                          children: _participants.map((participant) {
                            return FutureBuilder<Map<String, dynamic>?>(
                              future: DatabaseHelper.instance.getUserById(participant['user_id'] as int),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const ListTile(title: Text('Carregando participante...'));
                                }
                                final user = snapshot.data!;
                                return ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(user['name']),
                                  subtitle: Text(user['email']),
                                  trailing: _isCreator && user['name'] != creatorName
                                      ? IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          onPressed: () => _handleRemoveParticipant(user['id'] as int),
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileScreen(
                                          userId: user['id'] as int,
                                          loggedInUserEmail: widget.loggedInUserEmail,
                                          loggedInUserName: widget.loggedInUserName,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                VerticalDivider(),
                // Chat log
                Expanded(
                  child: ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Chat:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      _chatMessages.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text('Nenhuma mensagem no chat.'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _chatMessages.length,
                              itemBuilder: (context, chatIndex) {
                                final chatMessage = _chatMessages[chatIndex];
                                final timestamp = DateTime.parse(chatMessage['timestamp']);
                                return ListTile(
                                  leading: chatMessage['user_name'] == 'Sistema'
                                      ? const Icon(Icons.info, color: Colors.grey)
                                      : const Icon(Icons.chat_bubble),
                                  title: Text('${chatMessage['user_name']}: ${chatMessage['message']}'),
                                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp)),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // Builds the bottom bar depending on the user's relationship with the room
  Widget _buildBottomBar() {
    if (!_isParticipant && !_isCreator) {
      // User is not participating
      if (_hasPendingJoinRequest) {
        // User has already sent a join request
        return const BottomAppBar(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Solicitação pendente', textAlign: TextAlign.center),
          ),
        );
      } else {
        return BottomAppBar(
          child: ElevatedButton(
            onPressed: _handleJoinRoom,
            child: const Text('Solicitar'),
          ),
        );
      }
    } else if (_isParticipant && !_isCreator) {
      // User is participating but not the creator
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChatInput(),
          const Divider(height: 1),
          BottomAppBar(
            child: ElevatedButton(
              onPressed: _handleLeaveRoom,
              child: const Text('Sair da Sala'),
            ),
          ),
        ],
      );
    } else {
      // User is the creator
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChatInput(),
          const Divider(height: 1),
          BottomAppBar(
            child: ElevatedButton(
              onPressed: _handleDeleteRoom,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Excluir Sala'),
            ),
          ),
        ],
      );
    }
  }

  // Widget for the chat input field and send button
  Widget _buildChatInput() {
    if (!_isParticipant && !_isCreator) {
      return Container();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: const InputDecoration(hintText: 'Digite sua mensagem...'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _handleSendMessage,
          ),
        ],
      ),
    );
  }
}
