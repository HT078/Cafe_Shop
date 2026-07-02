import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/theme.dart';

class ChatManageScreen extends StatefulWidget {
  const ChatManageScreen({super.key});

  @override
  State<ChatManageScreen> createState() => _ChatManageScreenState();
}

class _ChatManageScreenState extends State<ChatManageScreen> {
  List<ChatConversation> _conversations = const [];
  RealtimeChannel? _conversationChannel;
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
      setState(() {
        _conversations = conversations;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  // Realtime danh sách hội thoại để admin thấy khách mới ngay.
  void _subscribeConversations() {
    _conversationChannel = SupabaseService.client
        .channel('admin_conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _loadConversations(),
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

    return RefreshIndicator(
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

  Future<void> _loadMessages({bool markRead = false}) async {
    final messages = await ChatService.fetchMessages(widget.conversation.id);
    if (markRead) {
      await ChatService.markReadByAdmin(widget.conversation.id);
    }
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  // Realtime khung chat admin.
  void _subscribeMessages() {
    _messagesChannel = SupabaseService.client
        .channel('admin_messages_${widget.conversation.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversation.id,
          ),
          callback: (_) => _loadMessages(markRead: true),
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
      await _loadMessages(markRead: true);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.conversation.customerName?.trim().isNotEmpty == true
        ? widget.conversation.customerName!
        : widget.conversation.customerEmail ?? 'Khách hàng';

    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(title: Text(title), centerTitle: true),
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
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _AdminMessageBubble(
                          message: message,
                          timeText: message.createdAt == null
                              ? ''
                              : _timeFormat.format(message.createdAt!),
                        );
                      },
                    ),
            ),
            _AdminComposer(
              controller: _controller,
              isSending: _isSending,
              onSend: _send,
            ),
          ],
        ),
      ),
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
  const _AdminMessageBubble({required this.message, required this.timeText});

  final ChatMessage message;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    final mine = message.isAdmin;
    final icon = message.isBot
        ? Icons.local_fire_department_rounded
        : mine
        ? Icons.support_agent_rounded
        : Icons.person_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) _MiniAvatar(icon: icon),
          if (!mine) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    gradient: mine ? AppTheme.flameGradient : null,
                    color: mine ? null : AppTheme.surfaceColor,
                    border: mine ? null : Border.all(color: AppTheme.lineColor),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: mine ? AppTheme.charColor : AppTheme.creamColor,
                      fontWeight: mine ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (timeText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (mine) const SizedBox(width: 8),
          if (mine) _MiniAvatar(icon: icon),
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
