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

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 120;
  }

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
      _scrollToBottom(animate: false);
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
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) => _handleRealtimeMessage(payload.newRecord),
        )
        .subscribe();
  }

  void _handleRealtimeMessage(Map<String, dynamic> record) {
    final conversation = _conversation;
    if (conversation == null) return;

    final incoming = ChatMessage.fromMap(record);
    if (incoming.id.isEmpty ||
        incoming.conversationId != conversation.id ||
        _messages.any((message) => message.id == incoming.id)) {
      return;
    }

    final shouldScroll = _isNearBottom;
    final nextMessages = normalizeChatMessages([..._messages, incoming]);
    if (!mounted) return;
    setState(() => _messages = nextMessages);
    if (shouldScroll) _scrollToBottom();
    if (!incoming.isUser) {
      ChatService.markReadByCustomer(conversation.id).catchError((_) {});
    }
  }

  Future<void> _reloadMessages({
    bool markRead = false,
    bool forceScroll = false,
  }) async {
    final conversation = _conversation;
    if (conversation == null) return;
    final shouldScroll = forceScroll || _isNearBottom;
    final messages = await ChatService.fetchMessages(conversation.id);
    if (markRead) {
      await ChatService.markReadByCustomer(conversation.id);
    }
    if (!mounted) return;
    setState(() {
      _messages = normalizeChatMessages([..._messages, ...messages]);
    });
    if (shouldScroll) {
      _scrollToBottom();
    }
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
      await _reloadMessages(forceScroll: true);
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

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lastMessageId = _messages.isEmpty ? null : _messages.last.id;

    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppTheme.surfaceAltColor,
              child: Icon(
                Icons.support_agent_rounded,
                color: AppTheme.goldColor,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hải Tín hỗ trợ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Thường phản hồi nhanh',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                  : _CustomerChatThread(
                      messages: _messages,
                      scrollController: _scrollController,
                      timeFormat: _timeFormat,
                      lastMessageId: lastMessageId,
                      onQuickReply: _handleQuickReply,
                    ),
            ),
            _ChatComposer(
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

class _CustomerChatThread extends StatelessWidget {
  const _CustomerChatThread({
    required this.messages,
    required this.scrollController,
    required this.timeFormat,
    required this.lastMessageId,
    required this.onQuickReply,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final DateFormat timeFormat;
  final String? lastMessageId;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      // Chừa khoảng trống đủ lớn để bong bóng cuối không bị thanh nhập che.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index == 0 ? null : messages[index - 1];
        final next = index == messages.length - 1 ? null : messages[index + 1];
        final compact = previous?.senderType == message.senderType;
        final lastInGroup = next?.senderType != message.senderType;
        final quickReplies = message.id == lastMessageId && message.isBot
            ? ChatbotService.quickRepliesForBotText(message.content)
            : const <String>[];

        return KeyedSubtree(
          key: ValueKey<String>(message.id),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: _MessageBubble(
                message: message,
                timeText: message.createdAt == null
                    ? ''
                    : timeFormat.format(message.createdAt!),
                quickReplies: quickReplies,
                onQuickReply: onQuickReply,
                compact: compact,
                lastInGroup: lastInGroup,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.timeText,
    required this.quickReplies,
    required this.onQuickReply,
    required this.compact,
    required this.lastInGroup,
  });

  final ChatMessage message;
  final String timeText;
  final List<String> quickReplies;
  final ValueChanged<String> onQuickReply;
  final bool compact;
  final bool lastInGroup;

  @override
  Widget build(BuildContext context) {
    final mine = message.isUser;
    final avatar = message.isBot
        ? Icons.local_fire_department_rounded
        : message.isAdmin
        ? Icons.support_agent_rounded
        : Icons.person_rounded;

    final showAvatar = !mine && lastInGroup;
    final bubbleColor = message.isBot
        ? AppTheme.surfaceColor
        : AppTheme.surfaceRaisedColor;

    return Padding(
      padding: EdgeInsets.only(top: compact ? 3 : 10),
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
              if (!mine) ...[
                showAvatar ? _Avatar(icon: avatar) : const SizedBox(width: 30),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: mine ? AppTheme.flameGradient : null,
                        color: mine ? null : bubbleColor,
                        border: mine
                            ? null
                            : Border.all(color: AppTheme.lineColor),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(
                            mine || !lastInGroup ? 20 : 7,
                          ),
                          bottomRight: Radius.circular(
                            mine && lastInGroup ? 7 : 20,
                          ),
                        ),
                      ),
                      child: Text(
                        message.content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: mine
                              ? AppTheme.charColor
                              : AppTheme.creamColor,
                          fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (lastInGroup && timeText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: mine ? 0 : 42, right: 0),
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

class _ChatComposer extends _Composer {
  const _ChatComposer({
    required super.controller,
    required super.isSending,
    required super.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.charColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: 'Nhap tin nhan...',
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.surfaceAltColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.lineColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.lineColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.goldColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: DecoratedBox(
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
                          : const Icon(
                              Icons.send_rounded,
                              color: AppTheme.charColor,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
