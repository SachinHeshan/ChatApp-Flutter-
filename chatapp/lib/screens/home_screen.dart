import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../services/chat_service.dart';
import '../services/debug_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final Logger _logger = Logger();
  late TabController _tabController;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chatService.updateUserStatus(true);

    // Auto-initialize sample data if needed after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      _autoInitializeSampleData();
    });
  }

  /// Automatically create sample data if no chats exist
  void _autoInitializeSampleData() async {
    try {
      final user = _chatService.currentUser;
      if (user == null) return;

      // Check if user has any chat rooms
      final snapshot =
          await FirebaseFirestore.instance
              .collection('chat_rooms')
              .where('users', arrayContains: user.uid)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        _logger.i('No existing chats found, creating sample data...');
        await DebugHelper.testAndCreateSampleData();
        if (mounted) {
          setState(() {}); // Refresh the UI
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '🎉 Welcome! Sample chat created to get you started.',
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Auto-initialization failed: $e');
      // Fail silently, user can manually create chats
    }
  }

  @override
  void dispose() {
    _chatService.updateUserStatus(false);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.grey.shade900 : Colors.white,
      appBar: AppBar(
        backgroundColor:
            _isDarkMode ? Colors.grey.shade800 : Colors.blue.shade600,
        elevation: 0,
        title: const Text(
          'ChatApp',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search feature coming soon')),
              );
            },
          ),
          GestureDetector(
            onTap: _showProfileMenu,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [Tab(text: 'Chats'), Tab(text: 'Status')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatsTab(), _buildStatusTab()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor:
            _isDarkMode ? Colors.grey.shade700 : Colors.blue.shade600,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  Widget _buildChatsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getChatRoomsStream(),
      builder: (context, snapshot) {
        _logger.d('StreamBuilder state: ${snapshot.connectionState}');
        _logger.d('Has data: ${snapshot.hasData}');
        _logger.d('Data length: ${snapshot.data?.docs.length ?? 0}');
        if (snapshot.hasError) _logger.e('Error: ${snapshot.error}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading chats...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          _logger.e('Chat stream error: ${snapshot.error}');
          // Enhanced error handling with more debugging info
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading chats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Error: ${snapshot.error.toString()}',
                    style: TextStyle(fontSize: 14, color: Colors.red.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _logger.i('Retrying connection...');
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry Connection'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _showDebugInfo,
                  child: const Text('Show Debug Info'),
                ),
              ],
            ),
          );
        }

        // Check if we have data but no documents
        if (!snapshot.hasData) {
          _logger.w('No snapshot data available');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No data available',
                  style: TextStyle(
                    fontSize: 18,
                    color: _isDarkMode ? Colors.white : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        final chatRooms = snapshot.data!.docs;
        _logger.d('Chat rooms found: ${chatRooms.length}');

        if (chatRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No chats yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: _isDarkMode ? Colors.white : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a new conversation by tapping the + button',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        _isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _showNewChatDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Start New Chat'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🔄 Refreshing...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          await DebugHelper.testAndCreateSampleData();
                          setState(() {});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Refresh failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              _logger.d('Building chat room item ${index}: ${chatRoom.id}');
              return _buildChatRoomItem(chatRoom);
            },
          ),
        );
      },
    );
  }

  Widget _buildChatRoomItem(DocumentSnapshot chatRoomDoc) {
    try {
      _logger.d('Building chat room: ${chatRoomDoc.id}');
      final data = chatRoomDoc.data() as Map<String, dynamic>?;
      _logger.d('Chat room data: $data');

      if (data == null) {
        _logger.w('Chat room data is null for ${chatRoomDoc.id}');
        return const ListTile(
          title: Text('Invalid chat room data'),
          leading: Icon(Icons.error, color: Colors.red),
        );
      }

      final users = List<String>.from(data['users'] ?? []);
      final lastMessage = data['lastMessage'] ?? 'No messages yet';
      final lastMessageTime = data['lastMessageTime'] as Timestamp?;

      _logger.d('Users in chat: $users');
      _logger.d('Last message: $lastMessage');

      final currentUserId = _chatService.currentUser?.uid;
      if (currentUserId == null) {
        _logger.e('Current user is null');
        return const ListTile(
          title: Text('Authentication error'),
          leading: Icon(Icons.error, color: Colors.red),
        );
      }

      _logger.d('Current user ID: $currentUserId');

      final otherUserId = users.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      _logger.d('Other user ID: $otherUserId');

      if (otherUserId.isEmpty) {
        _logger.w('No other user found in chat room ${chatRoomDoc.id}');
        return ListTile(
          title: Text('Chat room: ${chatRoomDoc.id}'),
          subtitle: Text('Users: ${users.join(", ")}'),
          leading: const Icon(Icons.warning, color: Colors.orange),
          onTap: () {
            // Try to navigate anyway with minimal data
            if (mounted) {
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'userId': users.isNotEmpty ? users.first : '',
                  'userName': 'Unknown User',
                },
              );
            }
          },
        );
      }

      return FutureBuilder<DocumentSnapshot>(
        future: _chatService.getUserDocument(otherUserId),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              title: const Text('Loading...'),
              subtitle: Text('Chat ID: ${chatRoomDoc.id}'),
            );
          }

          if (userSnapshot.hasError) {
            _logger.e('Error loading user $otherUserId: ${userSnapshot.error}');
            return ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: Text('Error loading user: $otherUserId'),
              subtitle: Text(userSnapshot.error.toString()),
              onTap: () {
                // Navigate with minimal info
                if (mounted) {
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {'userId': otherUserId, 'userName': 'User'},
                  );
                }
              },
            );
          }

          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
          final userName =
              userData?['name'] ??
              userData?['email']?.split('@')[0] ??
              'User $otherUserId';
          final isOnline = userData?['isOnline'] ?? false;

          _logger.d('User data for $otherUserId: $userData');
          _logger.d('User name: $userName');

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _logger.d('Navigating to chat with $otherUserId ($userName)');
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {'userId': otherUserId, 'userName': userName},
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isOnline)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        _isDarkMode
                                            ? Colors.grey.shade900
                                            : Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      lastMessageTime != null
                                          ? _formatTimestamp(lastMessageTime)
                                          : '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            _isDarkMode
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    StreamBuilder<int>(
                                      stream: _chatService
                                          .getUnreadMessageCountStream(
                                            chatRoomDoc.id,
                                          ),
                                      builder: (context, unreadSnapshot) {
                                        final unreadCount =
                                            unreadSnapshot.data ?? 0;
                                        if (unreadCount == 0)
                                          return const SizedBox.shrink();

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    _isDarkMode
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      _logger.e('Error in _buildChatRoomItem: $e');
      // Fallback for any unexpected errors
      return ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: Text('Error displaying chat: ${chatRoomDoc.id}'),
        subtitle: Text(e.toString()),
        onTap: () {
          // Still try to navigate with chat room ID
          Navigator.pushNamed(
            context,
            '/chat',
            arguments: {'userId': '', 'userName': 'Chat ${chatRoomDoc.id}'},
          );
        },
      );
    }
  }

  Widget _buildStatusTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.update, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Status feature coming soon',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your status updates with friends',
            style: TextStyle(
              fontSize: 14,
              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Start New Chat'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getAllUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No users available'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final userDoc = snapshot.data!.docs[index];
                      final userData = userDoc.data() as Map<String, dynamic>;
                      final userName = userData['name'] ?? 'Unknown';
                      final userEmail = userData['email'] ?? '';
                      final isOnline = userData['isOnline'] ?? false;

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              child: Text(userName[0].toUpperCase()),
                            ),
                            if (isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(userName),
                        subtitle: Text(userEmail),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          navigator.pop();
                          try {
                            await _chatService.createOrGetChatRoom(userDoc.id);
                            if (mounted) {
                              navigator.pushNamed(
                                '/chat',
                                arguments: {
                                  'userId': userDoc.id,
                                  'userName': userName,
                                },
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error starting chat: $e'),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Debug Information'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current User: ${_chatService.currentUser?.uid ?? "Not signed in"}',
                  ),
                  Text(
                    'Email: ${_chatService.currentUser?.email ?? "No email"}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chat Rooms Stream Test:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getChatRoomsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('⏳ Loading chat rooms...');
                      }
                      if (snapshot.hasError) {
                        return Text('❌ Error: ${snapshot.error}');
                      }
                      if (!snapshot.hasData) {
                        return const Text('❌ No data received');
                      }
                      final docs = snapshot.data!.docs;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✅ Found ${docs.length} chat rooms'),
                          if (docs.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            const Text('Chat Room IDs:'),
                            ...docs.map((doc) => Text('• ${doc.id}')),
                            const SizedBox(height: 4),
                            const Text('Sample chat room data:'),
                            Text('${docs.first.data()}'),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Users Collection Test:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getAllUsersStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('⏳ Loading users...');
                      }
                      if (snapshot.hasError) {
                        return Text('❌ Error: ${snapshot.error}');
                      }
                      if (!snapshot.hasData) {
                        return const Text('❌ No user data received');
                      }
                      final docs = snapshot.data!.docs;
                      return Text('✅ Found ${docs.length} users');
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Troubleshooting:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('1. Check internet connection'),
                  const Text('2. Verify Firebase configuration'),
                  const Text('3. Check Firestore security rules'),
                  const Text('4. Ensure user is authenticated'),
                  const Text('5. Try creating a new chat first'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _testFirebaseConnection();
                },
                child: const Text('Test Connection'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showNewChatDialog();
                },
                child: const Text('Create Chat'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔍 Running Firebase debug test...'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                    await DebugHelper.testAndCreateSampleData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '✅ Debug test completed! Check console for details.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      setState(() {}); // Refresh the chat list
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Debug test failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Debug Test'),
              ),
            ],
          ),
    );
  }

  void _testFirebaseConnection() async {
    try {
      // Test user authentication
      final user = _chatService.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ User not authenticated. Please sign in again.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacementNamed(context, '/signin');
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Firebase connection test successful'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Firebase test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey.shade800 : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        _isDarkMode
                            ? Colors.grey.shade600
                            : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(
                    Icons.person_outline,
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                  title: Text(
                    'Profile',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile feature coming soon'),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.settings_outlined,
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                  title: Text(
                    'Settings',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings feature coming soon'),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text(
                    'Debug Info',
                    style: TextStyle(color: Colors.orange),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDebugInfo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    await _chatService.signOutUser();
                    if (mounted) {
                      navigator.pushReplacementNamed('/signin');
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime now = DateTime.now();
    final DateTime messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[messageTime.weekday - 1];
    } else {
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }
  }
}
