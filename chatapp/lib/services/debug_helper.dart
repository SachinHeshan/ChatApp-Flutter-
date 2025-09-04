import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class DebugHelper {
  static final Logger _logger = Logger();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Test Firebase connection and create sample data if needed
  static Future<void> testAndCreateSampleData() async {
    try {
      _logger.i('🔍 Starting Firebase debug test...');

      // Test 1: Check authentication
      final user = _auth.currentUser;
      if (user == null) {
        _logger.e('❌ No user is currently signed in');
        return;
      }

      _logger.i('✅ User authenticated: ${user.uid}');
      _logger.i('📧 User email: ${user.email}');

      // Test 2: Test Firestore read access
      _logger.i('🔍 Testing Firestore read access...');

      try {
        final usersSnapshot =
            await _firestore.collection('users').limit(1).get();
        _logger.i(
          '✅ Users collection readable, found ${usersSnapshot.docs.length} documents',
        );
      } catch (e) {
        _logger.e('❌ Cannot read users collection: $e');
      }

      try {
        final chatRoomsSnapshot =
            await _firestore.collection('chat_rooms').limit(1).get();
        _logger.i(
          '✅ Chat rooms collection readable, found ${chatRoomsSnapshot.docs.length} documents',
        );
      } catch (e) {
        _logger.e('❌ Cannot read chat_rooms collection: $e');
      }

      // Test 3: Ensure current user document exists
      _logger.i('🔍 Checking/creating user document...');
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        _logger.i('🔧 Creating user document...');
        await userDocRef.set({
          'email': user.email ?? 'unknown@example.com',
          'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
        _logger.i('✅ User document created');
      } else {
        _logger.i('✅ User document exists');
        await userDocRef.update({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }

      // Test 4: Check for chat rooms
      _logger.i('🔍 Checking for existing chat rooms...');
      final chatRoomsQuery =
          await _firestore
              .collection('chat_rooms')
              .where('users', arrayContains: user.uid)
              .get();

      _logger.i(
        '💬 Found ${chatRoomsQuery.docs.length} chat rooms for current user',
      );

      if (chatRoomsQuery.docs.isEmpty) {
        _logger.i('🔧 No chat rooms found. Creating a sample chat room...');
        await _createSampleChatRoom(user.uid);
      } else {
        for (final doc in chatRoomsQuery.docs) {
          final data = doc.data();
          _logger.i('💬 Chat room ${doc.id}: $data');
        }
      }

      _logger.i('🎉 Firebase debug test completed successfully!');
    } catch (e) {
      _logger.e('❌ Firebase debug test failed: $e');
      rethrow;
    }
  }

  /// Create a sample chat room for testing
  static Future<void> _createSampleChatRoom(String currentUserId) async {
    try {
      // Create a sample user first
      const sampleUserId = 'sample_user_test';
      const sampleUserName = 'Test User';
      const sampleUserEmail = 'test@example.com';

      await _firestore.collection('users').doc(sampleUserId).set({
        'email': sampleUserEmail,
        'name': sampleUserName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': false,
      });

      // Create chat room ID
      final users = [currentUserId, sampleUserId];
      users.sort();
      final chatRoomId = '${users[0]}_${users[1]}';

      // Create chat room
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'users': users,
        'lastMessage': 'Welcome to ChatApp! This is a test message.',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': sampleUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add a sample message
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
            'text': 'Welcome to ChatApp! This is a test message.',
            'senderId': sampleUserId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'delivered',
          });

      _logger.i('✅ Sample chat room created: $chatRoomId');
    } catch (e) {
      _logger.e('❌ Failed to create sample chat room: $e');
      rethrow;
    }
  }

  /// Clear all sample data
  static Future<void> clearSampleData() async {
    try {
      _logger.i('🧹 Clearing sample data...');

      // Delete sample user
      await _firestore.collection('users').doc('sample_user_test').delete();

      // Find and delete chat rooms with sample user
      final chatRoomsSnapshot =
          await _firestore
              .collection('chat_rooms')
              .where('users', arrayContains: 'sample_user_test')
              .get();

      final batch = _firestore.batch();
      for (final doc in chatRoomsSnapshot.docs) {
        // Delete messages subcollection
        final messagesSnapshot =
            await doc.reference.collection('messages').get();
        for (final messageDoc in messagesSnapshot.docs) {
          batch.delete(messageDoc.reference);
        }
        // Delete chat room
        batch.delete(doc.reference);
      }

      await batch.commit();
      _logger.i('✅ Sample data cleared');
    } catch (e) {
      _logger.e('❌ Failed to clear sample data: $e');
    }
  }
}
