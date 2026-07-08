import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat_models.dart';
import '../../../services/chat_service.dart';
import '../../../services/chatbot_service.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/theme.dart';
import '../catalog/category_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DateFormat _timeFormat = DateFormat('HH:mm', 'vi_VN');

  ChatConversation? _conversation;
  List<ChatMessage> _messages = const [];
  RealtimeChannel? _messagesChannel;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openConversation();
  }

  @override
  void dispose() {
    final channel = _messagesChannel;
    if (channel != null) {
      SupabaseService.client.removeChannel(channel);
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openConversation() async {
    if (SupabaseService.currentUser == null) {
      setState(() {
        _isLoading = false;
        _error = 'Bạn cần đăng nhập để chat với Hải Tín';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conversation = await ChatService.getOrCreateCustomerConversation();
      final messages = await ChatService.fetchMessages(conversation.id);
      await ChatService.markReadByCustomer(conversation.id);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _messages = messages;
        _isLoading = false;
      });
      _subscribeMessages(conversation.id);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  // Lắng nghe realtime tin nhắn của conversation hiện tại.
  void _subscribeMessages(String conversationId) {
    final oldChannel = _messagesChannel;
    if (oldChannel != null) {
      SupabaseService.client.removeChannel(oldChannel);
    }

    _messagesChannel = SupabaseService.client
        .channel('customer_messages_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) => _reloadMessages(markRead: true),
        )
        .subscribe();
  }

  Future<void> _reloadMessages({bool markRead = false}) async {
    final conversation = _conversation;
    if (conversation == null) return;
    final messages = await ChatService.fetchMessages(conversation.id);
    if (markRead) {
      await ChatService.markReadByCustomer(conversation.id);
    }
    if (!mounted) return;
    setState(() => _messages = messages);
    _scrollToBottom();
  }

  Future<void> _sendText(String text) async {
    final conversation = _conversation;
    final message = text.trim();
    if (conversation == null || message.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _controller.clear();
    try {
      await ChatService.sendCustomerMessage(
        conversationId: conversation.id,
        content: message,
      );
      await ChatbotService.chatbotReply(
        conversationId: conversation.id,
        userMessage: message,
      );
      await ChatService.markReadByCustomer(conversation.id);
      await _reloadMessages();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppTheme.blazeColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _handleQuickReply(String label) {
    if (label == 'Xem danh mục') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CategoryScreen()));
      return;
    }
    _sendText(label);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lastMessageId = _messages.isEmpty ? null : _messages.last.id;

    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(title: const Text('Chat Hải Tín'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.goldColor,
                      ),
                    )
                  : _error != null
                  ? _ErrorState(message: _error!, onRetry: _openConversation)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final quickReplies =
                            message.id == lastMessageId && message.isBot
                            ? ChatbotService.quickRepliesForBotText(
                                message.content,
                              )
                            : const <String>[];
                        return _MessageBubble(
                          message: message,
                          timeText: message.createdAt == null
                              ? ''
                              : _timeFormat.format(message.createdAt!),
                          quickReplies: quickReplies,
                          onQuickReply: _handleQuickReply,
                        );
                      },
                    ),
            ),
            _Composer(
              controller: _controller,
              isSending: _isSending,
              onSend: () => _sendText(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.timeText,
    required this.quickReplies,
    required this.onQuickReply,
  });

  final ChatMessage message;
  final String timeText;
  final List<String> quickReplies;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final mine = message.isUser;
    final avatar = message.isBot
        ? Icons.local_fire_department_rounded
        : message.isAdmin
        ? Icons.support_agent_rounded
        : Icons.person_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) _Avatar(icon: avatar),
              if (!mine) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 310),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    gradient: mine ? AppTheme.flameGradient : null,
                    color: mine ? null : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 18),
                    ),
                    border: mine ? null : Border.all(color: AppTheme.lineColor),
                  ),
                  child: Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: mine ? AppTheme.charColor : AppTheme.creamColor,
                      fontWeight: mine ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (mine) const SizedBox(width: 8),
              if (mine) _Avatar(icon: avatar),
            ],
          ),
          if (timeText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(
                left: mine ? 0 : 42,
                right: mine ? 42 : 0,
              ),
              child: Text(
                timeText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedColor,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          if (quickReplies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickReplies
                    .map(
                      (reply) => ActionChip(
                        label: Text(reply),
                        onPressed: () => onQuickReply(reply),
                        backgroundColor: AppTheme.surfaceAltColor,
                        side: const BorderSide(color: AppTheme.lineColor),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 15,
      backgroundColor: AppTheme.surfaceAltColor,
      child: Icon(icon, color: AppTheme.goldColor, size: 17),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.lineColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Nhập tin nhắn...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              gradient: AppTheme.flameGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: AppTheme.charColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppTheme.goldColor,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
