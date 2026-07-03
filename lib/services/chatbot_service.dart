import 'package:intl/intl.dart';

import 'chat_service.dart';

class ChatbotService {
  ChatbotService._();

  static final _currency = NumberFormat('#,##0', 'vi_VN');

  // Xử lý tin nhắn khách và chèn phản hồi bot tương ứng.
  static Future<void> chatbotReply({
    required String conversationId,
    required String userMessage,
  }) async {
    final text = userMessage.trim();
    if (text.isEmpty) return;

    if (_isOrderLookup(text)) {
      await ChatService.sendBotMessage(
        conversationId: conversationId,
        content: 'Bạn cho mình xin mã đơn hàng nhé (VD: HT260620)',
      );
      return;
    }

    if (await _isWaitingOrderCode(conversationId)) {
      await _replyOrderStatus(conversationId, text);
      return;
    }

    if (_isProductQuestion(text)) {
      await ChatService.sendBotMessage(
        conversationId: conversationId,
        content:
            'Bạn có thể xem các dòng cà phê bột, cà phê hạt, túi lọc và dụng cụ pha chế ở Danh Mục. Nếu bạn thích vị đậm, mình gợi ý chọn dòng rang mộc hoặc robusta phối.',
      );
      return;
    }

    if (_isReturnPolicy(text)) {
      await ChatService.sendBotMessage(
        conversationId: conversationId,
        content:
            'Chính sách đổi trả Hải Tín: hỗ trợ đổi/trả trong 3 ngày nếu sản phẩm lỗi, hư hỏng khi nhận hàng hoặc giao sai sản phẩm. Sản phẩm đã mở bao bì không áp dụng đổi trả, trừ lỗi từ nhà sản xuất. Bạn nhớ giữ hình ảnh đơn hàng và bao bì để Hải Tín xử lý nhanh nhé.',
      );
      return;
    }

    if (_isHumanSupport(text)) {
      await ChatService.sendBotMessage(
        conversationId: conversationId,
        content:
            'Mình đã chuyển yêu cầu của bạn cho nhân viên, vui lòng chờ trong giây lát nhé 🙌',
      );
      await ChatService.setWaitingAdmin(conversationId);
      return;
    }

    await ChatService.sendBotMessage(
      conversationId: conversationId,
      content:
          'Mình chưa hiểu rõ ý bạn, bạn chọn 1 trong các mục bên dưới hoặc để mình chuyển bạn sang nhân viên nhé',
    );
  }

  static List<String> quickRepliesForBotText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('danh mục') || lower.contains('cà phê bột')) {
      return ['Xem danh mục', 'Nói chuyện với nhân viên'];
    }
    if (lower.contains('chưa hiểu rõ') ||
        lower.contains('trợ lý cà phê hải tín')) {
      return ChatService.defaultQuickReplies;
    }
    return const [];
  }

  static bool _isOrderLookup(String text) {
    final lower = _normalize(text);
    return lower.contains('tra cuu don hang') ||
        lower.contains('kiem tra don') ||
        lower.contains('don hang cua toi');
  }

  static bool _isProductQuestion(String text) {
    final lower = _normalize(text);
    return lower.contains('hoi ve san pham') ||
        lower.contains('san pham') ||
        lower.contains('ca phe') ||
        lower.contains('danh muc');
  }

  static bool _isReturnPolicy(String text) {
    final lower = _normalize(text);
    return lower.contains('chinh sach doi tra') ||
        lower.contains('doi tra') ||
        lower.contains('hoan hang') ||
        lower.contains('bao hanh');
  }

  static bool _isHumanSupport(String text) {
    final lower = _normalize(text);
    return lower.contains('noi chuyen voi nhan vien') ||
        lower.contains('nhan vien') ||
        lower.contains('tu van vien') ||
        lower.contains('ho tro vien');
  }

  static Future<bool> _isWaitingOrderCode(String conversationId) async {
    final messages = await ChatService.fetchMessages(conversationId);
    if (messages.length < 2) return false;
    final previous = messages.reversed.skip(1).firstOrNull;
    return previous?.isBot == true &&
        previous!.content.toLowerCase().contains('xin mã đơn hàng');
  }

  static Future<void> _replyOrderStatus(
    String conversationId,
    String orderCode,
  ) async {
    final order = await ChatService.findCustomerOrder(orderCode);
    if (order == null) {
      await ChatService.sendBotMessage(
        conversationId: conversationId,
        content:
            'Mình không tìm thấy đơn hàng này, bạn kiểm tra lại mã giúp mình nhé, hoặc để mình chuyển bạn sang nhân viên hỗ trợ',
      );
      return;
    }

    final status = (order['status'] ?? 'Đang xử lý').toString();
    final tracking = (order['tracking_code'] ?? '').toString();
    final shippingUnit = (order['shipping_unit'] ?? '').toString();
    final total = _asInt(order['total']);
    final trackingLine = tracking.isEmpty
        ? 'Mã vận đơn: chưa cập nhật'
        : 'Mã vận đơn: $tracking${shippingUnit.isEmpty ? '' : ' · $shippingUnit'}';

    await ChatService.sendBotMessage(
      conversationId: conversationId,
      content:
          'Mình tìm thấy đơn ${order['id']}. Trạng thái hiện tại: $status. $trackingLine. Tổng đơn: ${_currency.format(total)}đ.',
    );
  }

  static String _normalize(String value) {
    var result = value.toLowerCase();
    const groups = <String, String>{
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    for (final entry in groups.entries) {
      for (final char in entry.value.split('')) {
        result = result.replaceAll(char, entry.key);
      }
    }
    return result;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
