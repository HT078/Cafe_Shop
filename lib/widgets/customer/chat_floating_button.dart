import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../screens/customer/chat/chat_screen.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/theme.dart';
import 'login_gate.dart';

class ChatFloatingButton extends StatefulWidget {
  const ChatFloatingButton({super.key});

  @override
  State<ChatFloatingButton> createState() => _ChatFloatingButtonState();
}

class _ChatFloatingButtonState extends State<ChatFloatingButton> {
  int _unread = 0;
  RealtimeChannel? _conversationChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUnread();
      _subscribeConversation();
    });
  }

  @override
  void dispose() {
    final channel = _conversationChannel;
    if (channel != null) {
      SupabaseService.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _loadUnread() async {
    try {
      final unread = await ChatService.fetchCustomerUnreadCount();
      if (!mounted) return;
      setState(() => _unread = unread);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unread = 0);
    }
  }

  // Theo dõi realtime conversation của khách để cập nhật badge.
  void _subscribeConversation() {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    final oldChannel = _conversationChannel;
    if (oldChannel != null) {
      SupabaseService.client.removeChannel(oldChannel);
    }

    _conversationChannel = SupabaseService.client
        .channel('customer_conversation_badge_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (_) => _loadUnread(),
        )
        .subscribe();
  }

  Future<void> _openChat() async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    if (!mounted) return;
    await _loadUnread();
    _subscribeConversation();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              gradient: AppTheme.flameGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Chat hỗ trợ',
              onPressed: _openChat,
              icon: const Icon(
                Icons.chat_bubble_rounded,
                color: AppTheme.charColor,
              ),
            ),
          ),
          if (_unread > 0)
            Positioned(
              right: -2,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.blazeColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.charColor, width: 2),
                ),
                child: Text(
                  _unread > 99 ? '99+' : '$_unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
