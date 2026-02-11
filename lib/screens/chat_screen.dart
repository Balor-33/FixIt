import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/chat_room_model.dart';
import '../config/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String issueTitle;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.issueTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _currentUserId;
  UserModel? _otherUser;
  ChatRoomModel? _chatRoom;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _typingDebounce;
  bool _lastTypingState = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadChatRoom();
  }

  Future<void> _loadChatRoom() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final chatRoom = await _service.getChatRoom(widget.chatRoomId);

      if (chatRoom == null) {
        setState(() {
          _errorMessage = 'Chat room not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _chatRoom = chatRoom;
      });

      final otherUserId = chatRoom.customerId == _currentUserId
          ? chatRoom.professionalId
          : chatRoom.customerId;

      final user = await _service.getUser(otherUserId);

      setState(() {
        _otherUser = user;
        _isLoading = false;
      });

      if (_currentUserId != null) {
        await _service.markMessagesAsRead(
          chatRoomId: widget.chatRoomId,
          userId: _currentUserId!,
        );
      }
    } catch (e) {
      debugPrint('Error loading chat room: $e');
      setState(() {
        _errorMessage = 'Error loading chat: $e';
        _isLoading = false;
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _currentUserId == null ||
        _chatRoom == null) {
      return;
    }

    final text = _messageController.text.trim();
    _messageController.clear();
    _updateTypingStatus(false);
    setState(() {});

    try {
      final receiverId = _chatRoom!.customerId == _currentUserId
          ? _chatRoom!.professionalId
          : _chatRoom!.customerId;

      await _service.sendMessage(
        chatRoomId: widget.chatRoomId,
        senderId: _currentUserId!,
        receiverId: receiverId,
        text: text,
      );

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  void _onInputChanged(String value) {
    final isTyping = value.trim().isNotEmpty;
    if (isTyping != _lastTypingState) {
      _lastTypingState = isTyping;
      _updateTypingStatus(isTyping);
    }

    _typingDebounce?.cancel();
    if (isTyping) {
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        _lastTypingState = false;
        _updateTypingStatus(false);
      });
    }

    setState(() {});
  }

  void _updateTypingStatus(bool isTyping) {
    final userId = _currentUserId;
    if (userId == null || _chatRoom == null) return;
    _service.setTypingStatus(
      chatRoomId: widget.chatRoomId,
      userId: userId,
      isTyping: isTyping,
    );
  }

  bool _isOtherUserTyping(Map<String, dynamic>? roomData) {
    if (roomData == null || _currentUserId == null) return false;
    final typingRaw = roomData['typingBy'];
    if (typingRaw is! Map) return false;
    for (final entry in typingRaw.entries) {
      if (entry.key.toString() != _currentUserId &&
          entry.value is bool &&
          entry.value == true) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherName = _otherUser?.displayName?.trim();
    final displayName =
        (otherName != null && otherName.isNotEmpty) ? otherName : 'Chat';
    final avatarChar = displayName.characters.first.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.sm,
        title: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AppTheme.electric,
              backgroundImage: _otherUser?.photoUrl != null
                  ? NetworkImage(_otherUser!.photoUrl!)
                  : null,
              child: _otherUser?.photoUrl == null
                  ? Text(
                      avatarChar,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.issueTitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEFFBFA),
              Colors.white,
              Color(0xFFF8FAFC),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading chat...'),
                  ],
                ),
              )
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadChatRoom,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<MessageModel>>(
                      stream: _service.getChatMessages(widget.chatRoomId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          debugPrint('Stream error: ${snapshot.error}');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading messages:\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          );
                        }

                        final messages = snapshot.data ?? [];

                        if (_currentUserId != null) {
                          _service.markMessagesAsRead(
                            chatRoomId: widget.chatRoomId,
                            userId: _currentUserId!,
                          );
                        }

                        if (messages.isEmpty) {
                          return const _EmptyChatState(
                            title: 'No messages yet',
                            subtitle: 'Start the conversation!',
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent,
                            );
                          }
                        });

                        final timelineItems = <Widget>[];
                        for (var i = 0; i < messages.length; i++) {
                          final message = messages[i];
                          final isMe = message.senderId == _currentUserId;

                          if (i == 0 ||
                              _isDifferentDay(
                                messages[i - 1].sentAt,
                                message.sentAt,
                              )) {
                            timelineItems.add(_DateSeparator(date: message.sentAt));
                          }

                          timelineItems.add(
                            _MessageBubble(message: message, isMe: isMe),
                          );
                        }

                        return ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          children: timelineItems,
                        );
                      },
                ),
                  ),
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: _service.getChatRoomStream(widget.chatRoomId),
                    builder: (context, snapshot) {
                      final showTyping = _isOtherUserTyping(snapshot.data);
                      if (!showTyping) return const SizedBox.shrink();
                      return const _TypingIndicatorBar();
                    },
                  ),
                  _buildMessageInput(),
                ],
              ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                onChanged: _onInputChanged,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF2563EB)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _messageController.text.trim().isEmpty
                    ? null
                    : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _updateTypingStatus(false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : Colors.white,
          border: isMe
              ? null
              : Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMe ? 0.14 : 0.05),
              blurRadius: isMe ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.sentAt),
              style: TextStyle(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.grey[600],
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  String _format(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    if (that == today) return 'Today';
    if (that == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _format(date),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyChatState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 62,
              width: 62,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE0F2FE),
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: AppTheme.electric,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicatorBar extends StatelessWidget {
  const _TypingIndicatorBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TypingDots(),
              SizedBox(width: 8),
              Text(
                'Typing...',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        Widget dot(int i) {
          final t = (_controller.value + i * 0.2) % 1.0;
          final scale = 0.7 + (0.5 - (t - 0.5).abs()) * 0.8;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
          );
        }

        return Row(
          children: [
            dot(0),
            const SizedBox(width: 3),
            dot(1),
            const SizedBox(width: 3),
            dot(2),
          ],
        );
      },
    );
  }
}
