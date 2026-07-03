import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_models.dart';
import 'supabase_service.dart';

class ChatService {
  ChatService._();

  static SupabaseClient get _client => SupabaseService.client;

  static const String welcomeMessage =
      'Chào bạn! Mình là trợ lý Cà Phê Hải Tín 👋 Bạn cần hỗ trợ gì hôm nay?';

  static const List<String> defaultQuickReplies = [
    'Tra cứu đơn hàng',
    'Hỏi về sản phẩm',
    'Chính sách đổi trả',
    'Nói chuyện với nhân viên',
  ];

  // Tạo conversation lần đầu và gửi lời chào tự động từ bot.
  static Future<ChatConversation> getOrCreateCustomerConversation() async {
    SupabaseService.ensureConfigured();
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để chat với Hải Tín');
    }

    final rows = await _client
        .from('conversations')
        .select()
        .eq('user_id', user.id)
        .order('last_message_at', ascending: false)
        .limit(1);
    if (rows.isNotEmpty) {
      return ChatConversation.fromMap(Map<String, dynamic>.from(rows.first));
    }

    final now = DateTime.now().toIso8601String();
    final row = await _client
        .from('conversations')
        .insert({
          'user_id': user.id,
          'status': 'open',
          'last_message': welcomeMessage,
          'last_message_at': now,
          'unread_by_user': 0,
          'unread_by_admin': 0,
        })
        .select()
        .single();
    final conversation = ChatConversation.fromMap(
      Map<String, dynamic>.from(row),
    );

    await _client.from('messages').insert({
      'conversation_id': conversation.id,
      'sender_type': 'bot',
      'sender_id': null,
      'content': welcomeMessage,
      'is_read': true,
      'created_at': now,
    });

    return conversation;
  }

  static Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    SupabaseService.ensureConfigured();
    final rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return rows
        .map<ChatMessage>(
          (row) => ChatMessage.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  // Khách mở chat thì reset số tin chưa đọc của khách.
  static Future<void> markReadByCustomer(String conversationId) async {
    SupabaseService.ensureConfigured();
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .inFilter('sender_type', ['admin', 'bot']);
    await _client
        .from('conversations')
        .update({'unread_by_user': 0})
        .eq('id', conversationId);
  }

  // Admin mở chat thì reset số tin chưa đọc của admin.
  static Future<void> markReadByAdmin(String conversationId) async {
    SupabaseService.ensureConfigured();
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .eq('sender_type', 'user');
    await _client
        .from('conversations')
        .update({'unread_by_admin': 0})
        .eq('id', conversationId);
  }

  static Future<void> sendCustomerMessage({
    required String conversationId,
    required String content,
  }) async {
    SupabaseService.ensureConfigured();
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để gửi tin nhắn');
    }

    final text = content.trim();
    if (text.isEmpty) return;
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_type': 'user',
      'sender_id': user.id,
      'content': text,
      'is_read': false,
    });
    await _updateConversationAfterMessage(
      conversationId: conversationId,
      lastMessage: text,
      unreadColumn: 'unread_by_admin',
    );
  }

  static Future<void> sendAdminMessage({
    required String conversationId,
    required String content,
  }) async {
    SupabaseService.ensureConfigured();
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để gửi tin nhắn');
    }

    final text = content.trim();
    if (text.isEmpty) return;
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_type': 'admin',
      'sender_id': user.id,
      'content': text,
      'is_read': false,
    });
    await _updateConversationAfterMessage(
      conversationId: conversationId,
      lastMessage: text,
      unreadColumn: 'unread_by_user',
      extra: {'status': 'open', 'unread_by_admin': 0},
    );
  }

  static Future<void> sendBotMessage({
    required String conversationId,
    required String content,
    bool countUnreadForUser = false,
  }) async {
    SupabaseService.ensureConfigured();
    final text = content.trim();
    if (text.isEmpty) return;
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_type': 'bot',
      'sender_id': null,
      'content': text,
      'is_read': !countUnreadForUser,
    });
    await _updateConversationAfterMessage(
      conversationId: conversationId,
      lastMessage: text,
      unreadColumn: countUnreadForUser ? 'unread_by_user' : null,
    );
  }

  static Future<int> fetchCustomerUnreadCount() async {
    SupabaseService.ensureConfigured();
    final user = SupabaseService.currentUser;
    if (user == null) return 0;
    final row = await _client
        .from('conversations')
        .select('unread_by_user')
        .eq('user_id', user.id)
        .order('last_message_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return _asInt(row?['unread_by_user']);
  }

  static Future<int> fetchWaitingAdminCount() async {
    SupabaseService.ensureConfigured();
    final rows = await _client
        .from('conversations')
        .select('id')
        .eq('status', 'waiting_admin');
    return rows.length;
  }

  static Future<List<ChatConversation>> fetchAdminConversations() async {
    SupabaseService.ensureConfigured();
    try {
      final rows = await _client
          .from('conversations')
          .select('*, profiles(full_name,email,phone)')
          .order('last_message_at', ascending: false);
      return rows
          .map<ChatConversation>(
            (row) => ChatConversation.fromMap(Map<String, dynamic>.from(row)),
          )
          .toList();
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'fetchAdminConversations(join) failed: code=${error.code} '
        'message=${error.message} details=${error.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      final rows = await _client
          .from('conversations')
          .select()
          .order('last_message_at', ascending: false);
      final conversations = rows
          .map<ChatConversation>(
            (row) => ChatConversation.fromMap(Map<String, dynamic>.from(row)),
          )
          .toList();
      return _attachProfiles(conversations);
    }
  }

  static Future<void> setWaitingAdmin(String conversationId) async {
    SupabaseService.ensureConfigured();
    await _client
        .from('conversations')
        .update({'status': 'waiting_admin'})
        .eq('id', conversationId);
  }

  static Future<Map<String, dynamic>?> findCustomerOrder(String keyword) async {
    SupabaseService.ensureConfigured();
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    final code = keyword.trim();
    if (code.isEmpty) return null;

    final rows = await _client
        .from('orders')
        .select('id,status,tracking_code,shipping_unit,total,created_at')
        .eq('user_id', user.id)
        .ilike('id', '%$code%')
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  static Future<List<ChatConversation>> _attachProfiles(
    List<ChatConversation> conversations,
  ) async {
    final userIds = conversations
        .map((item) => item.userId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (userIds.isEmpty) return conversations;

    final profiles = await _client
        .from('profiles')
        .select('id,full_name,email,phone')
        .inFilter('id', userIds);
    final profilesById = <String, Map<String, dynamic>>{
      for (final profile in profiles)
        profile['id'].toString(): Map<String, dynamic>.from(profile),
    };

    return conversations.map((conversation) {
      final profile = profilesById[conversation.userId];
      if (profile == null) return conversation;
      return conversation.copyWith(
        customerName: profile['full_name']?.toString(),
        customerEmail: profile['email']?.toString(),
        customerPhone: profile['phone']?.toString(),
      );
    }).toList();
  }

  static Future<void> _updateConversationAfterMessage({
    required String conversationId,
    required String lastMessage,
    required String? unreadColumn,
    Map<String, dynamic> extra = const {},
  }) async {
    final row = await _client
        .from('conversations')
        .select('unread_by_user,unread_by_admin')
        .eq('id', conversationId)
        .maybeSingle();
    final payload = <String, dynamic>{
      'last_message': lastMessage,
      'last_message_at': DateTime.now().toIso8601String(),
      ...extra,
    };
    if (unreadColumn != null) {
      payload[unreadColumn] = _asInt(row?[unreadColumn]) + 1;
    }
    await _client
        .from('conversations')
        .update(payload)
        .eq('id', conversationId);
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
