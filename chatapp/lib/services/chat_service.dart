import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

// Helper class for creating a sorted QuerySnapshot
class _SortedQuerySnapshot implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;
  final SnapshotMetadata _metadata;

  _SortedQuerySnapshot(this._docs, this._metadata);

  @override
  List<QueryDocumentSnapshot> get docs => _docs;

  @override
  List<DocumentChange> get docChanges => [];

  @override
  SnapshotMetadata get metadata => _metadata;

  @override
  int get size => _docs.length;
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Create or get chat room between two users
  Future<String> createOrGetChatRoom(String otherUserId) async {
    try {
      final currentUserId = currentUser?.uid;
      if (currentUserId == null) throw 'User not authenticated';

      // Create chat room ID by sorting user IDs
      final chatRoomId = _getChatRoomId(currentUserId, otherUserId);

      final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
      final chatRoom = await chatRoomRef.get();

      if (!chatRoom.exists) {
        // Create new chat room
        await chatRoomRef.set({
          'users': [currentUserId, otherUserId],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSender': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _logger.i('Created new chat room: $chatRoomId');
      }

      return chatRoomId;
    } catch (e) {
      _logger.e('Error creating chat room: $e');
      rethrow;
    }
  }

  // Generate consistent chat room ID
  String _getChatRoomId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Send message with automatic delivery tracking
  Future<void> sendMessage(String chatRoomId, String message) async {
    try {
      final currentUserId = currentUser?.uid;
      if (currentUserId == null) throw 'User not authenticated';

      final messagesRef = _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages');

      // Add message with auto-generated ID
      final messageDoc = await messagesRef.add({
        'text': message,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent', // sent, delivered, read
        'deliveredAt': null,
        'readAt': null,
      });

      // Update chat room last message
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
      });

      // Automatically mark as delivered after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        markMessageAsDelivered(chatRoomId, messageDoc.id);
      });

      _logger.i('Message sent successfully');
    } catch (e) {
      _logger.e('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages stream for real-time updates
  Stream<QuerySnapshot> getMessagesStream(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get chat rooms for current user with better error handling
  Stream<QuerySnapshot> getChatRoomsStream() {
    final currentUserId = currentUser?.uid;
    if (currentUserId == null) {
      _logger.e('User not authenticated for chat rooms stream');
      return const Stream.empty();
    }

    _logger.i('Getting chat rooms for user: $currentUserId');

    // First try with ordering, if that fails, try without ordering
    return _firestore
        .collection('chat_rooms')
        .where('users', arrayContains: currentUserId)
        .snapshots()
        .handleError((error) {
          _logger.e('Error in chat rooms stream: $error');
        })
        .map((snapshot) {
          // Sort manually by lastMessageTime if it exists
          final docs = snapshot.docs.toList();
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;

            final aTime = aData?['lastMessageTime'] as Timestamp?;
            final bTime = bData?['lastMessageTime'] as Timestamp?;

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.compareTo(aTime); // Most recent first
          });

          // Create a new QuerySnapshot with sorted docs
          return _SortedQuerySnapshot(docs, snapshot.metadata);
        });
  }

  // Get user document with enhanced error handling
  Future<DocumentSnapshot> getUserDocument(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        // For real users, create user document if it doesn't exist
        if (!userId.startsWith('sample_user_')) {
          await _firestore.collection('users').doc(userId).set({
            'email': currentUser?.email ?? 'Unknown',
            'name': currentUser?.displayName ?? 'User',
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
            'isOnline': true,
          });

          // Return the newly created document
          return await _firestore.collection('users').doc(userId).get();
        } else {
          // For sample users, log warning but continue
          _logger.w('Sample user document not found: $userId');
        }
      }

      return userDoc;
    } catch (e) {
      _logger.e('Error getting user document: $e');
      rethrow;
    }
  }

  // Enhanced user presence tracking with last seen
  Future<void> updateUserStatus(bool isOnline) async {
    try {
      final currentUserId = currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('users').doc(currentUserId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // If going online, also update profile if needed
      if (isOnline) {
        await _ensureUserDocumentExists();
      }
    } catch (e) {
      _logger.e('Error updating user status: $e');
    }
  }

  // Ensure user document exists with current user info
  Future<void> _ensureUserDocumentExists() async {
    try {
      final currentUserId = currentUser?.uid;
      if (currentUserId == null) return;

      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(currentUserId).set({
          'email': currentUser?.email ?? 'Unknown',
          'name': currentUser?.displayName ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      }
    } catch (e) {
      _logger.e('Error ensuring user document exists: $e');
    }
  }

  // Typing indicators
  Future<void> setTyping(String chatRoomId, bool isTyping) async {
    try {
      final currentUserId = currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'typing.$currentUserId':
            isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } catch (e) {
      _logger.e('Error updating typing status: $e');
    }
  }

  // Get typing users stream
  Stream<List<String>> getTypingUsers(String chatRoomId) {
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return <String>[];

      final data = snapshot.data();
      final typing = data?['typing'] as Map<String, dynamic>?;

      if (typing == null) return <String>[];

      final now = DateTime.now();
      final typingUsers = <String>[];

      typing.forEach((userId, timestamp) {
        if (timestamp is Timestamp) {
          final typingTime = timestamp.toDate();
          // Consider user typing if last typing update was within 3 seconds
          if (now.difference(typingTime).inSeconds < 3 &&
              userId != currentUser?.uid) {
            typingUsers.add(userId);
          }
        }
      });

      return typingUsers;
    });
  }

  // Mark message as delivered
  Future<void> markMessageAsDelivered(
    String chatRoomId,
    String messageId,
  ) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
            'status': 'delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      _logger.e('Error marking message as delivered: $e');
    }
  }

  // Mark messages as read for a chat room
  Future<void> markChatMessagesAsRead(String chatRoomId) async {
    try {
      final currentUserId = currentUser?.uid;
      if (currentUserId == null) return;

      final messagesQuery =
          await _firestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
              .where('senderId', isNotEqualTo: currentUserId)
              .where('status', whereIn: ['sent', 'delivered'])
              .get();

      // Batch update all unread messages
      final batch = _firestore.batch();
      for (final doc in messagesQuery.docs) {
        batch.update(doc.reference, {
          'status': 'read',
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      _logger.e('Error marking messages as read: $e');
    }
  }

  // Get all users for new chat
  Stream<QuerySnapshot> getAllUsersStream() {
    final currentUserId = currentUser?.uid;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .where(FieldPath.documentId, isNotEqualTo: currentUserId)
        .snapshots();
  }

  // Get user status stream for real-time presence
  Stream<DocumentSnapshot> getUserStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Check if user is online (considering last seen)
  bool isUserOnline(Map<String, dynamic>? userData) {
    if (userData == null) return false;

    final isOnline = userData['isOnline'] ?? false;
    final lastSeen = userData['lastSeen'] as Timestamp?;

    if (isOnline) return true;

    // Consider user online if last seen within 5 minutes
    if (lastSeen != null) {
      final now = DateTime.now();
      final lastSeenTime = lastSeen.toDate();
      return now.difference(lastSeenTime).inMinutes < 5;
    }

    return false;
  }

  // Get formatted last seen text
  String getLastSeenText(Map<String, dynamic>? userData) {
    if (userData == null) return 'Unknown';

    final isOnline = userData['isOnline'] ?? false;
    if (isOnline) return 'Online';

    final lastSeen = userData['lastSeen'] as Timestamp?;
    if (lastSeen == null) return 'Last seen unknown';

    final now = DateTime.now();
    final lastSeenTime = lastSeen.toDate();
    final difference = now.difference(lastSeenTime);

    if (difference.inMinutes < 1) {
      return 'Last seen just now';
    } else if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours} hours ago';
    } else {
      return 'Last seen ${difference.inDays} days ago';
    }
  }

  // Get unread message count for a chat room
  Future<int> getUnreadMessageCount(String chatRoomId) async {
    try {
      final currentUserId = currentUser?.uid;
      if (currentUserId == null) return 0;

      final unreadQuery =
          await _firestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
              .where('senderId', isNotEqualTo: currentUserId)
              .where('status', whereIn: ['sent', 'delivered'])
              .get();

      return unreadQuery.docs.length;
    } catch (e) {
      _logger.e('Error getting unread count: $e');
      return 0;
    }
  }

  // Get unread message count stream for real-time updates
  Stream<int> getUnreadMessageCountStream(String chatRoomId) {
    final currentUserId = currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('status', whereIn: ['sent', 'delivered'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Create user account with enhanced error handling
  Future<void> createUserAccount(
    String email,
    String password,
    String name,
  ) async {
    try {
      _logger.i('Starting account creation for: $email');

      // Validate inputs
      if (!RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(email)) {
        throw 'Invalid email format';
      }

      if (password.length < 6) {
        throw 'Password must be at least 6 characters';
      }

      // Retry logic for network issues
      UserCredential? credential;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          _logger.i(
            'Attempt ${retryCount + 1} of $maxRetries: Creating Firebase Auth account...',
          );

          credential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) {
            rethrow; // Max retries reached
          }

          _logger.w(
            'Network retry $retryCount/$maxRetries failed, waiting 2 seconds...',
          );
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (credential?.user == null) {
        throw 'Failed to create user account after $maxRetries attempts';
      }

      _logger.i('Firebase account created: ${credential!.user!.uid}');

      // Update display name with error handling
      try {
        await credential.user!.updateDisplayName(name);
        _logger.i('Display name updated successfully');
      } catch (e) {
        _logger.w('Failed to update display name (non-critical): $e');
        // Continue without failing - not critical
      }

      // Create user document in Firestore with merge option to prevent overwrites
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));

      _logger.i('User document created successfully: ${credential.user?.uid}');
    } catch (e) {
      _logger.e('Error creating user account: $e');

      // Provide specific, user-friendly error messages
      if (e.toString().contains('network-request-failed')) {
        throw 'Network connection failed. Please check your internet connection and try again.';
      } else if (e.toString().contains('email-already-in-use')) {
        throw 'An account with this email already exists. Please sign in instead.';
      } else if (e.toString().contains('weak-password')) {
        throw 'Password is too weak. Please use a stronger password.';
      } else if (e.toString().contains('invalid-email')) {
        throw 'Invalid email address format.';
      } else if (e.toString().contains('operation-not-allowed')) {
        throw 'Email/password accounts are not enabled. Please contact support.';
      } else {
        throw 'Account creation failed: ${e.toString().replaceAll('Exception: ', '')}';
      }
    }
  }

  // Sign in user with enhanced error handling
  Future<void> signInUser(String email, String password) async {
    try {
      _logger.i('Attempting sign in for: $email');

      // Validate inputs
      if (!RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(email)) {
        throw 'Invalid email format';
      }

      // Retry logic for network issues
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          _logger.i('Sign-in attempt ${retryCount + 1} of $maxRetries...');

          await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) {
            rethrow; // Max retries reached
          }

          _logger.w(
            'Sign-in retry $retryCount/$maxRetries failed, waiting 2 seconds...',
          );
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // Update online status
      await updateUserStatus(true);

      _logger.i('User signed in successfully');
    } catch (e) {
      _logger.e('Error signing in: $e');

      // Provide specific error messages
      if (e.toString().contains('network-request-failed')) {
        throw 'Network connection failed. Please check your internet connection and try again.';
      } else if (e.toString().contains('user-not-found')) {
        throw 'No account found with this email. Please sign up first.';
      } else if (e.toString().contains('wrong-password')) {
        throw 'Incorrect password. Please try again.';
      } else if (e.toString().contains('invalid-email')) {
        throw 'Invalid email address format.';
      } else if (e.toString().contains('user-disabled')) {
        throw 'This account has been disabled. Please contact support.';
      } else {
        throw 'Sign in failed: ${e.toString().replaceAll('Exception: ', '')}';
      }
    }
  }

  // Sign out user
  Future<void> signOutUser() async {
    try {
      // Update offline status
      await updateUserStatus(false);

      // Sign out
      await _auth.signOut();

      _logger.i('User signed out successfully');
    } catch (e) {
      _logger.e('Error signing out: $e');
      rethrow;
    }
  }
}
