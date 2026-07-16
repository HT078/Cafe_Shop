import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat_models.dart';
import '../../../services/chat_service.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/theme.dart';

class ChatManageScreen extends StatefulWidget {
  const ChatManageScreen({super.key});

  @override
  State<ChatManageScreen> createState() => _ChatManageScreenState();
}

class _ChatManageScreenState extends State<ChatManageScreen> {
  List<ChatConversation> _conversations = const [];
  RealtimeChannel? _conversationChannel;
  Timer? _conversationRefreshTimer;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _subscribeConversations();
  }

  @override
  void dispose() {
    _conversationRefreshTimer?.cancel();
    final channel = _conversationChannel;
    if (channel != null) {
      SupabaseService.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await ChatService.fetchAdminConversations();
      if (!mounted) return;
      final changed = !_sameConversationList(_conversations, conversations);
      if (!mounted) return;
      if (changed || _isLoading || _error != null) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  // Realtime danh sách hội thoại để admin thấy khách mới ngay.
  bool _sameConversationList(
    List<ChatConversation> current,
    List<ChatConversation> next,
  ) {
    if (current.length != next.length) return false;
    for (var index = 0; index < current.length; index++) {
      final a = current[index];
      final b = next[index];
      if (a.id != b.id ||
          a.lastMessage != b.lastMessage ||
          a.lastMessageAt != b.lastMessageAt ||
          a.unreadByAdmin != b.unreadByAdmin ||
          a.status != b.status) {
        return false;
      }
    }
    return true;
  }

  void _scheduleConversationRefresh() {
    _conversationRefreshTimer?.cancel();
    _conversationRefreshTimer = Timer(
      const Duration(milliseconds: 280),
      _loadConversations,
    );
  }

  void _subscribeConversations() {
    _conversationChannel = SupabaseService.client
        .channel('admin_conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _scheduleConversationRefresh(),
        )
        .subscribe();
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminChatDetailScreen(conversation: conversation),
      ),
    );
    if (!mounted) return;
    _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.goldColor),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Không tải được hội thoại',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadConversations,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Text(
          'Chưa có hội thoại nào',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tin nhắn',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_conversations.length} cuộc trò chuyện',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Làm mới',
                onPressed: _loadConversations,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadConversations,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _conversations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                return _ConversationTile(
                  conversation: conversation,
                  onTap: () => _openConversation(conversation),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class AdminChatDetailScreen extends StatefulWidget {
  const AdminChatDetailScreen({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  State<AdminChatDetailScreen> createState() => _AdminChatDetailScreenState();
}

class _AdminChatDetailScreenState extends State<AdminChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DateFormat _timeFormat = DateFormat('HH:mm', 'vi_VN');

  List<ChatMessage> _messages = const [];
  RealtimeChannel? _messagesChannel;
  bool _isLoading = true;
  bool _isSending = false;

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 120;
  }

  @override
  void initState() {
    super.initState();
    _loadMessages(markRead: true);
    _subscribeMessages();
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

  Future<void> _loadMessages({
    bool markRead = false,
    bool forceScroll = false,
  }) async {
    final isInitialLoad = _isLoading;
    final shouldScroll = forceScroll || _isNearBottom;
    final messages = await ChatService.fetchMessages(widget.conversation.id);
    if (markRead) {
      await ChatService.markReadByAdmin(widget.conversation.id);
    }
    if (!mounted) return;
    setState(() {
      _messages = normalizeChatMessages([..._messages, ...messages]);
      _isLoading = false;
    });
    if (shouldScroll) {
      _scrollToBottom(animate: !isInitialLoad);
    }
  }

  // Realtime khung chat admin.
  void _subscribeMessages() {
    _messagesChannel = SupabaseService.client
        .channel('admin_messages_${widget.conversation.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversation.id,
          ),
          callback: (payload) => _handleRealtimeMessage(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _controller.clear();
    try {
      await ChatService.sendAdminMessage(
        conversationId: widget.conversation.id,
        content: text,
      );
      await _loadMessages(markRead: true, forceScroll: true);
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

  void _showCustomerInfo() {
    final conversation = widget.conversation;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversation.customerName ?? 'Khách hàng',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _CustomerInfoRow(
                icon: Icons.email_outlined,
                value: conversation.customerEmail ?? 'Chưa có email',
              ),
              const SizedBox(height: 10),
              _CustomerInfoRow(
                icon: Icons.phone_outlined,
                value: conversation.customerPhone ?? 'Chưa có số điện thoại',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.conversation.customerName?.trim().isNotEmpty == true
        ? widget.conversation.customerName!
        : widget.conversation.customerEmail ?? 'Khách hàng';

    return Scaffold(
      backgroundColor: AppTheme.pageColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 19,
              backgroundColor: AppTheme.surfaceAltColor,
              child: Icon(Icons.person_rounded, color: AppTheme.goldColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Text(
                    'Đang hoạt động',
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
        actions: [
          IconButton(
            tooltip: 'Thông tin khách',
            onPressed: _showCustomerInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
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
                  : _AdminChatThread(
                      messages: _messages,
                      scrollController: _scrollController,
                      timeFormat: _timeFormat,
                    ),
            ),
            _AdminChatComposer(
              controller: _controller,
              isSending: _isSending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  void _handleRealtimeMessage(Map<String, dynamic> record) {
    final incoming = ChatMessage.fromMap(record);
    if (incoming.id.isEmpty ||
        incoming.conversationId != widget.conversation.id ||
        _messages.any((message) => message.id == incoming.id)) {
      return;
    }

    final shouldScroll = _isNearBottom;
    final nextMessages = normalizeChatMessages([..._messages, incoming]);
    if (!mounted) return;
    setState(() => _messages = nextMessages);
    if (shouldScroll) _scrollToBottom();
    if (incoming.isUser) {
      ChatService.markReadByAdmin(widget.conversation.id).catchError((_) {});
    }
  }
}

class _AdminChatThread extends StatelessWidget {
  const _AdminChatThread({
    required this.messages,
    required this.scrollController,
    required this.timeFormat,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final DateFormat timeFormat;

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

        return KeyedSubtree(
          key: ValueKey<String>(message.id),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: _AdminMessageBubble(
                message: message,
                timeText: message.createdAt == null
                    ? ''
                    : timeFormat.format(message.createdAt!),
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = conversation.lastMessageAt == null
        ? ''
        : DateFormat(
            'dd/MM HH:mm',
            'vi_VN',
          ).format(conversation.lastMessageAt!);
    final name = conversation.customerName?.trim().isNotEmpty == true
        ? conversation.customerName!
        : conversation.customerEmail ?? 'Khách hàng';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.surfaceAltColor,
          child: const Icon(Icons.person_rounded, color: AppTheme.goldColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (conversation.status == 'waiting_admin') ...[
              const SizedBox(width: 8),
              const _WaitingBadge(),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            conversation.lastMessage.isEmpty
                ? 'Chưa có tin nhắn'
                : conversation.lastMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 6),
            if (conversation.unreadByAdmin > 0)
              _UnreadBadge(count: conversation.unreadByAdmin),
          ],
        ),
      ),
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({
    required this.message,
    required this.timeText,
    required this.compact,
    required this.lastInGroup,
  });

  final ChatMessage message;
  final String timeText;
  final bool compact;
  final bool lastInGroup;

  @override
  Widget build(BuildContext context) {
    final mine = message.isAdmin;
    final icon = message.isBot
        ? Icons.local_fire_department_rounded
        : mine
        ? Icons.support_agent_rounded
        : Icons.person_rounded;
    final showAvatar = !mine && lastInGroup;
    final bubbleColor = message.isBot
        ? AppTheme.surfaceColor
        : AppTheme.surfaceRaisedColor;

    return Padding(
      padding: EdgeInsets.only(top: compact ? 3 : 10),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            showAvatar ? _MiniAvatar(icon: icon) : const SizedBox(width: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
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
                    if (lastInGroup && timeText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        timeText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminComposer extends StatelessWidget {
  const _AdminComposer({
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
                hintText: 'Trả lời khách...',
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

class _AdminChatComposer extends _AdminComposer {
  const _AdminChatComposer({
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
                      hintText: 'Tra loi khach...',
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

class _CustomerInfoRow extends StatelessWidget {
  const _CustomerInfoRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.goldColor, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.icon});

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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.blazeColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WaitingBadge extends StatelessWidget {
  const _WaitingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.blazeColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Cần hỗ trợ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
