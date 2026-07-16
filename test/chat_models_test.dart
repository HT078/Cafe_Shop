import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/chat_models.dart';

void main() {
  ChatMessage message({
    required String id,
    required String createdAt,
    String content = '',
  }) {
    return ChatMessage(
      id: id,
      conversationId: 'conversation-1',
      senderType: 'user',
      content: content,
      createdAt: DateTime.parse(createdAt),
      isRead: false,
    );
  }

  test('normalizeChatMessages keeps messages in chronological order', () {
    final normalized = normalizeChatMessages([
      message(id: 'new', createdAt: '2026-07-16T06:42:00Z'),
      message(id: 'old', createdAt: '2026-07-16T06:40:00Z'),
      message(id: 'middle', createdAt: '2026-07-16T06:41:00Z'),
    ]);

    expect(normalized.map((item) => item.id), ['old', 'middle', 'new']);
  });

  test('normalizeChatMessages removes duplicate realtime messages', () {
    final normalized = normalizeChatMessages([
      message(
        id: 'same-id',
        createdAt: '2026-07-16T06:40:00Z',
        content: 'old value',
      ),
      message(
        id: 'same-id',
        createdAt: '2026-07-16T06:40:00Z',
        content: 'latest value',
      ),
    ]);

    expect(normalized, hasLength(1));
    expect(normalized.single.content, 'latest value');
  });
}
