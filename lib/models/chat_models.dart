class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.userId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadByUser,
    required this.unreadByAdmin,
    required this.status,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
  });

  final String id;
  final String userId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadByUser;
  final int unreadByAdmin;
  final String status;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] is Map
        ? Map<String, dynamic>.from(map['profiles'] as Map)
        : const <String, dynamic>{};

    return ChatConversation(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      lastMessage: (map['last_message'] ?? '').toString(),
      lastMessageAt: _date(map['last_message_at'] ?? map['updated_at']),
      unreadByUser: _asInt(map['unread_by_user']),
      unreadByAdmin: _asInt(map['unread_by_admin']),
      status: (map['status'] ?? 'open').toString(),
      customerName: (profile['full_name'] ?? map['customer_name'])?.toString(),
      customerEmail: (profile['email'] ?? map['customer_email'])?.toString(),
      customerPhone: (profile['phone'] ?? map['customer_phone'])?.toString(),
    );
  }

  ChatConversation copyWith({
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) {
    return ChatConversation(
      id: id,
      userId: userId,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      unreadByUser: unreadByUser,
      unreadByAdmin: unreadByAdmin,
      status: status,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.content,
    required this.createdAt,
    required this.isRead,
    this.senderId,
  });

  final String id;
  final String conversationId;
  final String senderType;
  final String content;
  final DateTime? createdAt;
  final bool isRead;
  final String? senderId;

  bool get isUser => senderType == 'user';
  bool get isAdmin => senderType == 'admin';
  bool get isBot => senderType == 'bot';

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString() ?? '',
      senderType: (map['sender_type'] ?? 'user').toString(),
      content: (map['content'] ?? map['message'] ?? '').toString(),
      createdAt: _date(map['created_at']),
      isRead: map['is_read'] == true,
      senderId: map['sender_id']?.toString(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
