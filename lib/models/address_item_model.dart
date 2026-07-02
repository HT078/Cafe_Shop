class AddressItem {
  AddressItem({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.province,
    required this.district,
    required this.ward,
    required this.detailAddress,
    required this.isDefault,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String province;
  final String district;
  final String ward;
  final String detailAddress;
  final bool isDefault;
  final DateTime? createdAt;

  factory AddressItem.fromMap(Map<String, dynamic> map) {
    return AddressItem(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      fullName: (map['full_name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      province: (map['province'] ?? '').toString(),
      district: (map['district'] ?? '').toString(),
      ward: (map['ward'] ?? '').toString(),
      detailAddress: (map['detail_address'] ?? '').toString(),
      isDefault: map['is_default'] == true,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'phone': phone,
      'province': province,
      'district': district,
      'ward': ward,
      'detail_address': detailAddress,
      'is_default': isDefault,
    };
  }

  String get formattedAddress {
    final parts = <String>[
      detailAddress,
      ward,
      district,
      province,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  AddressItem copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? phone,
    String? province,
    String? district,
    String? ward,
    String? detailAddress,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return AddressItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      province: province ?? this.province,
      district: district ?? this.district,
      ward: ward ?? this.ward,
      detailAddress: detailAddress ?? this.detailAddress,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
