// File: lib/screens/notifications_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:rollcall/screens/profile_screen.dart';
import '../services/database_helper.dart';
import 'room_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String loggedInUserEmail;
  final String loggedInUserName;
  final VoidCallback? onNotificationsUpdated;

  const NotificationsScreen({
    super.key,
    required this.loggedInUserEmail,
    required this.loggedInUserName,
    this.onNotificationsUpdated,
  });

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

Future<void> _loadNotifications() async {
  int userId = await _getLoggedInUserId();
  final notifications = await DatabaseHelper.instance.getUnreadNotifications(userId);
  setState(() {
    _notifications = notifications;
  });
  // Notify HomeScreen about the update
  if (widget.onNotificationsUpdated != null) {
    widget.onNotificationsUpdated!();
  }
}


  Future<int> _getLoggedInUserId() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [widget.loggedInUserEmail]);
    return result.isNotEmpty ? result.first['id'] as int : 0;
  }

  Future<void> _handleNotificationAction(Map<String, dynamic> notification) async {
    if (notification['type'] == 'room_invitation' ||
        notification['type'] == 'room_join_request_accepted' ||
        notification['type'] == 'room_invitation_accepted') {
      int roomId = int.parse(notification['data'] as String);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomScreen(
            roomId: roomId,
            loggedInUserEmail: widget.loggedInUserEmail,
            loggedInUserName: widget.loggedInUserName,
          ),
        ),
      ).then((value) {
        _loadNotifications();
      });
    } else if (notification['type'] == 'friend_request' ||
        notification['type'] == 'friend_request_accepted') {
      int userId = int.parse(notification['data'] as String);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            userId: userId,
            loggedInUserEmail: widget.loggedInUserEmail,
            loggedInUserName: widget.loggedInUserName,
          ),
        ),
      ).then((value) {
        _loadNotifications();
      });
    }
  }

  Future<void> _acceptNotification(Map<String, dynamic> notification) async {
    int notificationId = notification['id'] as int;
    if (notification['type'] == 'room_invitation') {
      int invitationId = await DatabaseHelper.instance.getRoomInvitationId(notification);
      await DatabaseHelper.instance.acceptRoomInvitation(invitationId);
      // Notify the inviter
      int inviterId = await DatabaseHelper.instance.getInviterIdForInvitation(invitationId);
      await DatabaseHelper.instance.addNotification({
        'user_id': inviterId,
        'type': 'room_invitation_accepted',
        'content': 'Seu convite para entrar na sala foi aceito',
        'data': notification['data'],
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
      });
    } else if (notification['type'] == 'friend_request') {
      int requestId = await DatabaseHelper.instance.getFriendRequestId(notification);
      await DatabaseHelper.instance.acceptFriendRequest(requestId);
      // Notify the sender
      int senderId = await DatabaseHelper.instance.getSenderIdForFriendRequest(requestId);
      await DatabaseHelper.instance.addNotification({
        'user_id': senderId,
        'type': 'friend_request_accepted',
        'content': 'Seu pedido de amizade foi aceito',
        'data': (await _getLoggedInUserId()).toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
      });
    } else if (notification['type'] == 'room_join_request') {
      int requestId = await DatabaseHelper.instance.getRoomJoinRequestId(notification);
      await DatabaseHelper.instance.acceptRoomJoinRequest(requestId);
      // Notify the requester
      int requesterId = await DatabaseHelper.instance.getRequesterIdForJoinRequest(requestId);
      await DatabaseHelper.instance.addNotification({
        'user_id': requesterId,
        'type': 'room_join_request_accepted',
        'content': 'Sua solicitação para entrar na sala foi aceita',
        'data': notification['data'],
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
      });
    }
    await DatabaseHelper.instance.markNotificationAsRead(notificationId);
    _loadNotifications();
  }

  Future<void> _declineNotification(Map<String, dynamic> notification) async {
    int notificationId = notification['id'] as int;
    if (notification['type'] == 'room_invitation') {
      int invitationId = await DatabaseHelper.instance.getRoomInvitationId(notification);
      await DatabaseHelper.instance.declineRoomInvitation(invitationId);
      // Notify the inviter
      int inviterId = await DatabaseHelper.instance.getInviterIdForInvitation(invitationId);
      await DatabaseHelper.instance.addNotification({
        'user_id': inviterId,
        'type': 'room_invitation_declined',
        'content': 'Seu convite para entrar na sala foi recusado',
        'data': notification['data'],
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
      });
    } else if (notification['type'] == 'friend_request') {
      int requestId = await DatabaseHelper.instance.getFriendRequestId(notification);
      await DatabaseHelper.instance.declineFriendRequest(requestId);
      // Notify the sender
      int senderId = await DatabaseHelper.instance.getSenderIdForFriendRequest(requestId);
      await DatabaseHelper.instance.addNotification({
        'user_id': senderId,
        'type': 'friend_request_declined',
        'content': 'Seu pedido de amizade foi recusado',
        'data': (await _getLoggedInUserId()).toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
      });
    } else if (notification['type'] == 'room_join_request') {
      int requestId = await DatabaseHelper.instance.getRoomJoinRequestId(notification);
      await DatabaseHelper.instance.declineRoomJoinRequest(requestId);
      // Notify the requester
      int requesterId = await DatabaseHelper.instance.getRequesterIdForJoinRequest(requestId);
      await DatabaseHelper.instance.addNotification({
        'user_id': requesterId,
        'type': 'room_join_request_declined',
        'content': 'Sua solicitação para entrar na sala foi recusada',
        'data': notification['data'],
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
      });
    }
    await DatabaseHelper.instance.markNotificationAsRead(notificationId);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
      ),
      body: _notifications.isEmpty
          ? const Center(child: Text('Sem notificações.'))
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return ListTile(
                  title: Text(notification['content']),
                  trailing: (notification['type'] == 'room_invitation' ||
                          notification['type'] == 'friend_request' ||
                          notification['type'] == 'room_join_request') &&
                      notification['is_read'] == 0 // Hide buttons if answered
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () async {
                                await _acceptNotification(notification);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                await _declineNotification(notification);
                              },
                            ),
                          ],
                        )
                      : null,
                  onTap: () async {
  // Check if the notification requires user action
  if (notification['type'] != 'room_invitation' &&
      notification['type'] != 'friend_request' &&
      notification['type'] != 'room_join_request') {
    // Mark system notification as read
    await DatabaseHelper.instance.markNotificationAsRead(notification['id'] as int);
    _loadNotifications();
  }

  // Handle the notification action
  await _handleNotificationAction(notification);
},

                );
              },
            ),
    );
  }
}
