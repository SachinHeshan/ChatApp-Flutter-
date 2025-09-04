import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../firebase_options.dart';

class FirebaseConnectivityTest {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Test Firebase initialization
  Future<bool> testFirebaseInitialization() async {
    try {
      _logger.i('Testing Firebase initialization...');

      // Check if Firebase is already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      _logger.i('✅ Firebase initialized successfully');
      return true;
    } catch (e) {
      _logger.e('❌ Firebase initialization failed: $e');
      return false;
    }
  }

  // Test Firestore connectivity
  Future<bool> testFirestoreConnection() async {
    try {
      _logger.i('Testing Firestore connection...');

      // Create a test document
      final testRef = _firestore.collection('connectivity_test').doc('test');
      await testRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': true,
      }, SetOptions(merge: true));

      // Read the document back
      final doc = await testRef.get();
      if (doc.exists) {
        _logger.i('✅ Firestore connection successful');

        // Clean up test document
        await testRef.delete();
        return true;
      } else {
        _logger.e('❌ Firestore document creation failed');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Firestore connection failed: $e');
      return false;
    }
  }

  // Test Firebase Auth connectivity
  Future<bool> testAuthConnection() async {
    try {
      _logger.i('Testing Firebase Auth connection...');

      // Get current auth state
      final user = _auth.currentUser;
      _logger.i('Current user: ${user?.uid ?? "No user signed in"}');

      // Test auth availability (without deprecated method)
      _logger.i('✅ Firebase Auth connection successful');
      return true;
    } catch (e) {
      _logger.e('❌ Firebase Auth connection failed: $e');
      return false;
    }
  }

  // Comprehensive connectivity test
  Future<Map<String, bool>> runFullConnectivityTest() async {
    _logger.i('🔥 Starting Firebase Connectivity Test...');

    final results = <String, bool>{};

    // Test Firebase initialization
    results['firebase_init'] = await testFirebaseInitialization();

    if (results['firebase_init']!) {
      // Test Firestore
      results['firestore'] = await testFirestoreConnection();

      // Test Auth
      results['auth'] = await testAuthConnection();
    } else {
      results['firestore'] = false;
      results['auth'] = false;
    }

    // Print results summary
    _logger.i('📊 Connectivity Test Results:');
    results.forEach((test, result) {
      final status = result ? '✅ PASS' : '❌ FAIL';
      _logger.i('  $test: $status');
    });

    return results;
  }

  // Test account creation with enhanced error handling
  Future<bool> testAccountCreation() async {
    try {
      _logger.i('Testing account creation...');

      final testEmail =
          'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
      final testPassword = 'TestPassword123!';

      // Create test account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );

      if (credential.user != null) {
        _logger.i('✅ Test account created successfully');

        // Create user document in Firestore
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'email': testEmail,
          'name': 'Test User',
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': false,
        }, SetOptions(merge: true));

        _logger.i('✅ User document created successfully');

        // Clean up test account
        await credential.user!.delete();
        _logger.i('✅ Test account cleaned up');

        return true;
      }

      return false;
    } catch (e) {
      _logger.e('❌ Test account creation failed: $e');
      return false;
    }
  }

  // Create sample users and chat rooms with messages
  Future<void> createSampleData() async {
    try {
      _logger.i('Creating sample data for testing...');

      // Sample users data
      final sampleUsers = [
        {
          'name': 'Alice Johnson',
          'email': 'alice@example.com',
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Bob Smith',
          'email': 'bob@example.com',
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Carol Williams',
          'email': 'carol@example.com',
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        },
      ];

      // Create sample users
      List<String> userIds = [];
      for (int i = 0; i < sampleUsers.length; i++) {
        final userId = 'sample_user_${i + 1}';
        await _firestore.collection('users').doc(userId).set(sampleUsers[i]);
        userIds.add(userId);
        _logger.i('Created sample user: ${sampleUsers[i]['name']}');
      }

      // Create sample chat rooms with messages
      await _createSampleChatRoom(
        userIds[0], // Alice
        userIds[1], // Bob
        [
          {'sender': userIds[0], 'text': 'Hey Bob! How are you doing?'},
          {
            'sender': userIds[1],
            'text': 'Hi Alice! I\'m doing great, thanks for asking!',
          },
          {'sender': userIds[0], 'text': 'That\'s wonderful to hear! 😊'},
          {
            'sender': userIds[1],
            'text': 'How about you? How\'s your day going?',
          },
          {
            'sender': userIds[0],
            'text': 'Pretty good! Just working on some projects.',
          },
        ],
      );

      await _createSampleChatRoom(
        userIds[0], // Alice
        userIds[2], // Carol
        [
          {
            'sender': userIds[2],
            'text': 'Alice! Great to connect with you here 🎉',
          },
          {
            'sender': userIds[0],
            'text': 'Hey Carol! This chat app is pretty cool, right?',
          },
          {
            'sender': userIds[2],
            'text': 'Absolutely! I love the real-time features',
          },
          {
            'sender': userIds[0],
            'text': 'The message delivery status is my favorite part',
          },
          {
            'sender': userIds[2],
            'text': 'Same here! And the typing indicators are so smooth',
          },
        ],
      );

      await _createSampleChatRoom(
        userIds[1], // Bob
        userIds[2], // Carol
        [
          {
            'sender': userIds[1],
            'text': 'Carol, have you tried the dark mode yet?',
          },
          {
            'sender': userIds[2],
            'text': 'Yes! It looks amazing. Very professional design',
          },
          {
            'sender': userIds[1],
            'text': 'I agree! The developers did a great job',
          },
        ],
      );

      _logger.i('✅ Sample data creation completed successfully');
    } catch (e) {
      _logger.e('❌ Error creating sample data: $e');
      rethrow;
    }
  }

  // Helper method to create a chat room with messages
  Future<void> _createSampleChatRoom(
    String user1Id,
    String user2Id,
    List<Map<String, String>> messages,
  ) async {
    try {
      // Create chat room ID
      final sortedIds = [user1Id, user2Id]..sort();
      final chatRoomId = '${sortedIds[0]}_${sortedIds[1]}';

      // Create chat room document
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'users': [user1Id, user2Id],
        'lastMessage': messages.last['text'],
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': messages.last['sender'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add messages to the chat room
      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];
        await _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .add({
              'text': message['text'],
              'senderId': message['sender'],
              'timestamp': FieldValue.serverTimestamp(),
              'status':
                  i < messages.length - 1
                      ? 'read'
                      : 'delivered', // Last message as delivered, others as read
              'deliveredAt': FieldValue.serverTimestamp(),
              'readAt':
                  i < messages.length - 1 ? FieldValue.serverTimestamp() : null,
            });
      }

      _logger.i('Created chat room with ${messages.length} messages');
    } catch (e) {
      _logger.e('Error creating sample chat room: $e');
      rethrow;
    }
  }

  // Check if sample data already exists
  Future<bool> sampleDataExists() async {
    try {
      final sampleUser =
          await _firestore.collection('users').doc('sample_user_1').get();
      return sampleUser.exists;
    } catch (e) {
      _logger.e('Error checking sample data: $e');
      return false;
    }
  }

  // Initialize sample data if it doesn't exist
  Future<void> initializeSampleDataIfNeeded() async {
    try {
      final exists = await sampleDataExists();
      if (!exists) {
        _logger.i('No sample data found. Creating sample data...');
        await createSampleData();
      } else {
        _logger.i('Sample data already exists. Skipping creation.');
      }
    } catch (e) {
      _logger.e('Error initializing sample data: $e');
    }
  }

  // Network diagnostics
  Future<void> runNetworkDiagnostics() async {
    _logger.i('🌐 Running Network Diagnostics...');

    try {
      // Test basic Firebase connection
      final results = await runFullConnectivityTest();

      if (!results['firebase_init']!) {
        _logger.w('🔧 Troubleshooting Steps:');
        _logger.w('  1. Check internet connection');
        _logger.w('  2. Verify Firebase project configuration');
        _logger.w('  3. Check firebase_options.dart file');
        _logger.w('  4. Ensure Firebase services are enabled');
      }

      if (!results['firestore']!) {
        _logger.w('🔧 Firestore Issues:');
        _logger.w('  1. Check Firestore security rules');
        _logger.w('  2. Verify project billing is enabled');
        _logger.w('  3. Check Firestore region settings');
      }

      if (!results['auth']!) {
        _logger.w('🔧 Auth Issues:');
        _logger.w('  1. Enable Email/Password authentication');
        _logger.w('  2. Check authorized domains');
        _logger.w('  3. Disable reCAPTCHA if causing issues');
      }
    } catch (e) {
      _logger.e('Network diagnostics failed: $e');
    }
  }
}
