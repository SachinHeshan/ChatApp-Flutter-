import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  
  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _chatRoomId;
  String? _otherUserName;
  String? _otherUserId;
  bool _isLoading = false;
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _otherUserId = widget.userId;
    _otherUserName = widget.userName;
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    if (_otherUserId == null) return;

    setState(() => _isLoading = true);
    try {
      _chatRoomId = await _chatService.createOrGetChatRoom(_otherUserId!);
      // Mark messages as read when entering chat
      if (_chatRoomId != null) {
        await _chatService.markChatMessagesAsRead(_chatRoomId!);
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error initializing chat: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatRoomId == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      await _chatService.sendMessage(_chatRoomId!, message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(DocumentSnapshot messageDoc) {
    final data = messageDoc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == _chatService.currentUser?.uid;
    final message = data['text'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final status = data['status'] ?? 'sent';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue.shade600 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timestamp != null
                      ? _formatTime(timestamp.toDate())
                      : 'Sending...',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.check, color: Colors.white70, size: 16);
      case 'delivered':
        return const Icon(Icons.done_all, color: Colors.white70, size: 16);
      case 'read':
        return const Icon(Icons.done_all, color: Colors.blue, size: 16);
      default:
        return const Icon(Icons.access_time, color: Colors.white70, size: 16);
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTypingIndicator() {
    if (_chatRoomId == null) return const SizedBox.shrink();
    
    return StreamBuilder<List<String>>(
      stream: _chatService.getTypingUsers(_chatRoomId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_otherUserName ?? 'User'} is typing',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onTyping() {
    if (!_isTyping && _chatRoomId != null) {
      _isTyping = true;
      _chatService.setTyping(_chatRoomId!, true);
    }
    
    // Reset the timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      if (_chatRoomId != null) {
        _chatService.setTyping(_chatRoomId!, false);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    // Stop typing when leaving
    if (_chatRoomId != null) {
      _chatService.setTyping(_chatRoomId!, false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: _otherUserId != null ? _chatService.getUserStatusStream(_otherUserId!) : null,
          builder: (context, snapshot) {
            final userData = snapshot.hasData ? snapshot.data!.data() as Map<String, dynamic>? : null;
            final isOnline = _chatService.isUserOnline(userData);
            final lastSeenText = _chatService.getLastSeenText(userData);
            
            return Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Text(
                        _otherUserName?.substring(0, 1).toUpperCase() ?? '?',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 16,
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
                              color: Colors.blue.shade600,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _otherUserName ?? 'Chat',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        lastSeenText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video call feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice call feature coming soon')),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Messages List
                  Expanded(
                    child:
                        _chatRoomId == null
                            ? const Center(child: Text('Loading chat...'))
                            : StreamBuilder<QuerySnapshot>(
                              stream: _chatService.getMessagesStream(
                                _chatRoomId!,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text('Error: ${snapshot.error}'),
                                  );
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'Start your conversation!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                }

                                final messages = snapshot.data!.docs;

                                // Auto-scroll to bottom when new messages arrive
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _scrollToBottom();
                                });

                                return ListView.builder(
                                  controller: _scrollController,
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    return _buildMessageBubble(messages[index]);
                                  },
                                );
                              },
                            ),
                  ),

                  // Typing Indicator
                  _buildTypingIndicator(),

                  // Message Input
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => _onTyping(),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade600,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
