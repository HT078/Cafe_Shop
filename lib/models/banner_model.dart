class BannerItem {
  const BannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.tag,
    required this.linkType,
    required this.linkValue,
    required this.isActive,
    required this.sortOrder,
    required this.startAt,
    required this.endAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String tag;
  final String linkType;
  final String linkValue;
  final bool isActive;
  final int sortOrder;
  final DateTime? startAt;
  final DateTime? endAt;

  bool get isVisibleNow {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);
    final startDate = startAt == null
        ? null
        : DateTime(startAt!.year, startAt!.month, startAt!.day);
    final endDate = endAt == null
        ? null
        : DateTime(endAt!.year, endAt!.month, endAt!.day);

    final startOk = startDate == null || !startDate.isAfter(dateOnly);
    final endOk = endDate == null || !endDate.isBefore(dateOnly);
    return isActive && startOk && endOk;
  }

  String get statusLabel {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);
    final startDate = startAt == null
        ? null
        : DateTime(startAt!.year, startAt!.month, startAt!.day);
    final endDate = endAt == null
        ? null
        : DateTime(endAt!.year, endAt!.month, endAt!.day);

    if (!isActive) return 'Đã tắt';
    if (startDate != null && startDate.isAfter(dateOnly)) return 'Sắp chạy';
    if (endDate != null && endDate.isBefore(dateOnly)) return 'Đã hết hạn';
    return 'Đang chạy';
  }

  factory BannerItem.fromMap(Map<String, dynamic> map) {
    return BannerItem(
      id: map['id']?.toString() ?? '',
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      imageUrl: (map['image_url'] ?? map['imageUrl'] ?? '').toString(),
      tag: (map['tag'] ?? '').toString(),
      linkType: (map['link_type'] ?? 'none').toString(),
      linkValue: (map['link_value'] ?? '').toString(),
      isActive: map['is_active'] == true,
      sortOrder: _asInt(map['sort_order']),
      startAt: _date(map['start_at']),
      endAt: _date(map['end_at']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
