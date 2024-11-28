import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class DatabaseHelper {
  // Current Version
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();

  // Private constructor
  DatabaseHelper._init();

  // Database reference
  static Database? _database;

  // Getter for the database
  Future<Database> get database async {
    if (_database != null) return _database!;

    // Initialize the database if it's not already
    _database = await _initDB('board_game_hub.db');
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDB(String filePath) async {
    // Get the default databases location
    final dbPath = await getDatabasesPath();
    // Create the full path to the database
    final path = join(dbPath, filePath);

    // Open the database, creating it if it doesn't exist
    return await openDatabase(
      path,
      version: 7, // Incremented version number
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Create the database schema
  Future<void> _createDB(Database db, int version) async {
    // Create 'users' table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    // Create 'friend_requests' table
    await db.execute('''
      CREATE TABLE friend_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_id INTEGER NOT NULL,
        receiver_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(sender_id) REFERENCES users(id),
        FOREIGN KEY(receiver_id) REFERENCES users(id)
      )
    ''');

    // Create 'friends' table
    await db.execute('''
      CREATE TABLE friends (
        user_id INTEGER NOT NULL,
        friend_id INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(friend_id) REFERENCES users(id)
      )
    ''');

    // Create 'notifications' table
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        data TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');

    // Create 'rooms' table
    await db.execute('''
    CREATE TABLE rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      gameName TEXT NOT NULL,
      gameId INTEGER,
      thumbnailUrl TEXT,
      minPlayers INTEGER,
      maxPlayers INTEGER,
      playingTime INTEGER,
      dateTime TEXT NOT NULL,
      address TEXT NOT NULL,
      playerSlots INTEGER NOT NULL,
      waitlistSlots INTEGER NOT NULL,
      creatorId INTEGER NOT NULL,
      creatorName TEXT NOT NULL,
      creatorEmail TEXT NOT NULL,
      FOREIGN KEY(creatorId) REFERENCES users(id)
    )
  ''');


    // Create 'room_participants' table
    await db.execute('''
      CREATE TABLE room_participants (
        room_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        FOREIGN KEY(room_id) REFERENCES rooms(id),
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');

    // Create 'chat_messages' table
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY(room_id) REFERENCES rooms(id)
      )
    ''');

    // Create 'room_invitations' table
    await db.execute('''
      CREATE TABLE room_invitations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        inviter_id INTEGER NOT NULL,
        invitee_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(room_id) REFERENCES rooms(id),
        FOREIGN KEY(inviter_id) REFERENCES users(id),
        FOREIGN KEY(invitee_id) REFERENCES users(id)
      )
    ''');

    // Create 'room_join_requests' table
    await db.execute('''
      CREATE TABLE room_join_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        requester_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(room_id) REFERENCES rooms(id),
        FOREIGN KEY(requester_id) REFERENCES users(id)
      )
    ''');
  }

  // Upgrade the database if the version number has changed
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      // For simplicity, drop existing tables and recreate them
      // In production, you should handle migrations properly
      await db.execute('DROP TABLE IF EXISTS chat_messages');
      await db.execute('DROP TABLE IF EXISTS room_participants');
      await db.execute('DROP TABLE IF EXISTS room_invitations');
      await db.execute('DROP TABLE IF EXISTS room_join_requests');
      await db.execute('DROP TABLE IF EXISTS rooms');
      await db.execute('DROP TABLE IF EXISTS notifications');
      await db.execute('DROP TABLE IF EXISTS friends');
      await db.execute('DROP TABLE IF EXISTS friend_requests');
      await db.execute('DROP TABLE IF EXISTS users');
      // Recreate the database
      await _createDB(db, newVersion);
    }
  }

  // Insert a new user (Sign Up)
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    return await db.insert('users', user);
  }

  // Check user credentials for login
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      columns: ['id', 'email', 'name'],
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Insert a new room
  Future<int> insertRoom(Map<String, dynamic> room) async {
  final db = await database;
  return await db.insert('rooms', room);
}


  // Update room details (e.g., adding an image URL column in the future)
  Future<int> updateRoom(int roomId, Map<String, dynamic> updatedFields) async {
    final db = await instance.database;
    return await db.update('rooms', updatedFields, where: 'id = ?', whereArgs: [roomId]);
  }

  // Delete a room
  Future<int> deleteRoom(int roomId) async {
    final db = await instance.database;
    // Delete room participants and messages first due to foreign key constraints
    await db.delete('room_participants', where: 'room_id = ?', whereArgs: [roomId]);
    await db.delete('chat_messages', where: 'room_id = ?', whereArgs: [roomId]);
    return await db.delete('rooms', where: 'id = ?', whereArgs: [roomId]);
  }

  // Get all rooms
  Future<List<Map<String, dynamic>>> getRooms() async {
    final db = await instance.database;
    return await db.query('rooms');
  }

  // Get a specific room by ID
  Future<Map<String, dynamic>?> getRoomById(int id) async {
    final db = await database;
    final result = await db.query('rooms', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }


  // Add a participant to a room
  Future<void> addParticipant(int roomId, int userId) async {
    final db = await database;
      await db.insert('room_participants', {
        'room_id': roomId,
        'user_id': userId,
      });
  }


  // Remove a participant from a room
  Future<int> removeParticipant(int roomId, int userId) async {
    final db = await instance.database;
    return await db.delete(
      'room_participants',
      where: 'room_id = ? AND user_id = ?',
      whereArgs: [roomId, userId],
    );
  }

  // Get participants for a room
  Future<List<Map<String, dynamic>>> getRoomParticipants(int roomId) async {
    final db = await instance.database;
    return await db.query('room_participants', where: 'room_id = ?', whereArgs: [roomId]);
  }

  // Check if a user is a participant of a room
  Future<bool> isUserParticipant(int roomId, int userId) async {
    final db = await instance.database;
    final result = await db.query(
      'room_participants',
      where: 'room_id = ? AND user_id = ?',
      whereArgs: [roomId, userId],
    );
    return result.isNotEmpty;
  }

  // Get room participants by user ID
  Future<List<Map<String, dynamic>>> getRoomParticipantsWithUserId(int userId) async {
    final db = await instance.database;
    return await db.query('room_participants', where: 'user_id = ?', whereArgs: [userId]);
  }

  // Add a chat message to a room
  Future<int> addChatMessage(Map<String, dynamic> message) async {
    final db = await instance.database;
    return await db.insert('chat_messages', message);
  }

  // Get chat messages for a room
  Future<List<Map<String, dynamic>>> getChatMessages(int roomId) async {
    final db = await instance.database;
    return await db.query(
      'chat_messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp ASC',
    );
  }

  // Get a user by ID
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await instance.database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    return result.isNotEmpty ? result.first : null;
  }

  // Friend Requests
  Future<int> sendFriendRequest(int senderId, int receiverId) async {
    final db = await instance.database;
    return await db.insert('friend_requests', {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getFriendRequests(int userId) async {
    final db = await instance.database;
    return await db.query('friend_requests',
        where: 'receiver_id = ? AND status = ?', whereArgs: [userId, 'pending']);
  }

  Future<void> acceptFriendRequest(int requestId) async {
    final db = await instance.database;
    // Get the request details
    final result = await db.query('friend_requests', where: 'id = ?', whereArgs: [requestId]);
    if (result.isNotEmpty) {
      final request = result.first;
      int senderId = request['sender_id'] as int;
      int receiverId = request['receiver_id'] as int;
      // Update the request status
      await db.update('friend_requests', {'status': 'accepted'}, where: 'id = ?', whereArgs: [requestId]);
      // Add both users to friends table
      await db.insert('friends', {'user_id': senderId, 'friend_id': receiverId});
      await db.insert('friends', {'user_id': receiverId, 'friend_id': senderId});
    }
  }

  Future<void> declineFriendRequest(int requestId) async {
    final db = await instance.database;
    await db.update('friend_requests', {'status': 'declined'}, where: 'id = ?', whereArgs: [requestId]);
  }

  Future<void> cancelFriendRequest(int senderId, int receiverId) async {
    final db = await instance.database;
    await db.delete('friend_requests',
        where: 'sender_id = ? AND receiver_id = ? AND status = ?',
        whereArgs: [senderId, receiverId, 'pending']);
  }

  Future<bool> areFriends(int userId, int otherUserId) async {
    final db = await instance.database;
    final result = await db.query('friends',
        where: 'user_id = ? AND friend_id = ?', whereArgs: [userId, otherUserId]);
    return result.isNotEmpty;
  }

  Future<bool> isFriendRequestSent(int senderId, int receiverId) async {
    final db = await instance.database;
    final result = await db.query('friend_requests',
        where: 'sender_id = ? AND receiver_id = ? AND status = ?',
        whereArgs: [senderId, receiverId, 'pending']);
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getUserFriends(int userId) async {
    final db = await instance.database;
    final result = await db.query('friends', where: 'user_id = ?', whereArgs: [userId]);
    List<int> friendIds = result.map((row) => row['friend_id'] as int).toList();

    // Now get user details for each friend
    List<Map<String, dynamic>> friends = [];
    for (int friendId in friendIds) {
      final user = await getUserById(friendId);
      if (user != null) {
        friends.add(user);
      }
    }
    return friends;
  }

  // Notifications
  Future<int> addNotification(Map<String, dynamic> notification) async {
    final db = await instance.database;
    return await db.insert('notifications', notification);
  }

  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final db = await instance.database;
    return await db.query('notifications',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'timestamp DESC');
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    final db = await instance.database;
    await db.update('notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [notificationId]);
  }

  // Room Invitations
  Future<int> sendRoomInvitation(int roomId, int inviterId, int inviteeId) async {
    final db = await instance.database;
    return await db.insert('room_invitations', {
      'room_id': roomId,
      'inviter_id': inviterId,
      'invitee_id': inviteeId,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getRoomInvitations(int userId) async {
    final db = await instance.database;
    return await db.query('room_invitations',
        where: 'invitee_id = ? AND status = ?', whereArgs: [userId, 'pending']);
  }

// In DatabaseHelper class
Future<void> acceptRoomInvitation(int invitationId) async {
  final db = await database;

  // Get the invitation details
  final invitation = await db.query(
    'room_invitations',
    where: 'id = ?',
    whereArgs: [invitationId],
  );

  if (invitation.isNotEmpty) {
    final roomId = invitation.first['room_id'] as int;
    final inviteeId = invitation.first['invitee_id'] as int;

    // Add the invitee as a participant in the room
    await addParticipant(roomId, inviteeId);

    // Update the invitation status to 'accepted'
    await db.update(
      'room_invitations',
      {'status': 'accepted'},
      where: 'id = ?',
      whereArgs: [invitationId],
    );
  }
}

  Future<void> declineRoomInvitation(int invitationId) async {
    final db = await instance.database;
    await db.update('room_invitations', {'status': 'declined'}, where: 'id = ?', whereArgs: [invitationId]);
  }

  Future<List<Map<String, dynamic>>> getRoomInvitationsForRoomAndInvitee(int roomId, int inviteeId) async {
    final db = await instance.database;
    return await db.query('room_invitations',
        where: 'room_id = ? AND invitee_id = ? AND status = ?',
        whereArgs: [roomId, inviteeId, 'pending']);
  }

  Future<int> getRoomInvitationId(Map<String, dynamic> notification) async {
    final db = await instance.database;
    int userId = notification['user_id'] as int;
    int roomId = int.parse(notification['data'] as String);
    final result = await db.query('room_invitations',
        where: 'invitee_id = ? AND room_id = ? AND status = ?',
        whereArgs: [userId, roomId, 'pending']);
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
    return 0;
  }

  Future<int> getFriendRequestId(Map<String, dynamic> notification) async {
    final db = await instance.database;
    int receiverId = notification['user_id'] as int;
    int senderId = int.parse(notification['data'] as String);
    final result = await db.query('friend_requests',
        where: 'receiver_id = ? AND sender_id = ? AND status = ?',
        whereArgs: [receiverId, senderId, 'pending']);
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
    return 0;
  }

  // Room Join Requests
  Future<int> sendRoomJoinRequest(int roomId, int requesterId) async {
    final db = await instance.database;
    return await db.insert('room_join_requests', {
      'room_id': roomId,
      'requester_id': requesterId,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getRoomJoinRequests(int roomId) async {
    final db = await instance.database;
    return await db.query('room_join_requests',
        where: 'room_id = ? AND status = ?', whereArgs: [roomId, 'pending']);
  }

  Future<void> acceptRoomJoinRequest(int requestId) async {
    final db = await instance.database;
      // Get request details
      final result = await db.query('room_join_requests', where: 'id = ?', whereArgs: [requestId]);
      if (result.isNotEmpty) {
        final request = result.first;
        int roomId = request['room_id'] as int;
        int requesterId = request['requester_id'] as int;
        // Update request status
        await db.update('room_join_requests', {'status': 'accepted'}, where: 'id = ?', whereArgs: [requestId]);
        // Add the user to room participants
        await addParticipant(roomId, requesterId);
      }
  }

  Future<void> declineRoomJoinRequest(int requestId) async {
    final db = await instance.database;
    await db.update('room_join_requests', {'status': 'declined'}, where: 'id = ?', whereArgs: [requestId]);
  }

  Future<List<Map<String, dynamic>>> getRoomJoinRequestsForUser(int roomId, int userId) async {
    final db = await instance.database;
    return await db.query('room_join_requests',
        where: 'room_id = ? AND requester_id = ? AND status = ?',
        whereArgs: [roomId, userId, 'pending']);
  }

  Future<int> getRoomJoinRequestId(Map<String, dynamic> notification) async {
    final db = await instance.database;
    String dataString = notification['data'] as String;
    List<String> parts = dataString.split(',');
    if (parts.length != 2) {
      throw Exception('Invalid data in notification');
    }
    int roomId = int.parse(parts[0]);
    int requesterId = int.parse(parts[1]);
    final result = await db.query('room_join_requests',
        where: 'requester_id = ? AND room_id = ? AND status = ?',
        whereArgs: [requesterId, roomId, 'pending']);
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
    return 0;
  }

  Future<int> getRequesterIdForJoinRequest(int requestId) async {
    final db = await instance.database;
    final result = await db.query('room_join_requests', where: 'id = ?', whereArgs: [requestId]);
    if (result.isNotEmpty) {
      return result.first['requester_id'] as int;
    }
    return 0;
  }

  Future<Map<String, dynamic>?> getUserByName(String name) async {
    final db = await instance.database;
    final result = await db.query('users', where: 'name = ?', whereArgs: [name]);
    return result.isNotEmpty ? result.first : null;
  }

  // Close the database
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }

  // Retrieves the sender ID for a given friend request ID
  Future<int> getSenderIdForFriendRequest(int requestId) async {
    final db = await instance.database;
    final result = await db.query(
      'friend_requests',
      columns: ['sender_id'],
      where: 'id = ?',
      whereArgs: [requestId],
    );
    if (result.isNotEmpty) {
      return result.first['sender_id'] as int;
    }
    return 0;
  }

  // Retrieves the inviter ID for a given room invitation ID
  Future<int> getInviterIdForInvitation(int invitationId) async {
    final db = await instance.database;
    final result = await db.query(
      'room_invitations',
      columns: ['inviter_id'],
      where: 'id = ?',
      whereArgs: [invitationId],
    );
    if (result.isNotEmpty) {
      return result.first['inviter_id'] as int;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getUnreadNotifications(int userId) async {
    final db = await instance.database;
    return await db.query(
      'notifications',
      where: 'user_id = ? AND is_read = 0',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<String>> getFriendsEmails(String userEmail) async {
  // Replace with actual database query to get friends' emails
  // For example, from a 'friends' table
  final db = await database;
  List<Map> results = await db.query('friends', where: 'userEmail = ?', whereArgs: [userEmail]);
  return results.map((result) => result['friendEmail'] as String).toList();
}


// Get User ID by Email
Future<int?> getUserIdByEmail(String email) async {
  final db = await instance.database;
  final result = await db.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
  return result.isNotEmpty ? result.first['id'] as int : null;
}

// Get Friends' IDs
Future<List<int>> getFriendsIds(int userId) async {
  final db = await instance.database;
  final result = await db.query('friends', where: 'user_id = ?', whereArgs: [userId]);
  return result.map((row) => row['friend_id'] as int).toList();
}

// Check if User is Participating in a Room
Future<bool> isUserParticipatingInRoom(String userEmail, int roomId) async {
  final db = await instance.database;

  // Get user ID by email
  final userResult = await db.query('users', where: 'email = ?', whereArgs: [userEmail], limit: 1);
  if (userResult.isEmpty) {
    return false;
  }
  final userId = userResult.first['id'] as int;

  final result = await db.query(
    'room_participants',
    where: 'user_id = ? AND room_id = ?',
    whereArgs: [userId, roomId],
  );
  return result.isNotEmpty;
}


Future<List<Map<String, dynamic>>> getUserFriendsByEmail(String userEmail) async {
  final db = await instance.database;
  // Get the user's ID
  int? userId = await getUserIdByEmail(userEmail);
  if (userId == null) {
    return [];
  }

  final result = await db.query('friends', where: 'user_id = ?', whereArgs: [userId]);
  List<int> friendIds = result.map((row) => row['friend_id'] as int).toList();

  // Now get user details for each friend
  List<Map<String, dynamic>> friends = [];
  for (int friendId in friendIds) {
    final user = await getUserById(friendId);
    if (user != null) {
      friends.add(user);
    }
  }
  return friends;
}

// Remove a friend relationship
Future<void> removeFriend(int userId, int friendId) async {
  final db = await instance.database;
  await db.delete('friends', where: 'user_id = ? AND friend_id = ?', whereArgs: [userId, friendId]);
  await db.delete('friends', where: 'user_id = ? AND friend_id = ?', whereArgs: [friendId, userId]);
}

}
