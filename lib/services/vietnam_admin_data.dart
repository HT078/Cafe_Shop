class VietnamAdministrativeData {
  VietnamAdministrativeData._();

  static const Map<String, Map<String, List<String>>> _data = {
    'TP. Hồ Chí Minh': {
      'Quận 1': ['Phường Bến Nghé', 'Phường Bến Thành', 'Phường Cầu Ông Lãnh'],
      'Quận 7': ['Phường Tân Phong', 'Phường Tân Hưng', 'Phường Bình Thuận'],
      'Thành phố Thủ Đức': ['Phường Hiệp Phú', 'Phường Phước Long B', 'Phường Thảo Điền'],
    },
    'Hà Nội': {
      'Quận Hoàn Kiếm': ['Phường Hàng Bạc', 'Phường Hàng Trống', 'Phường Tràng Tiền'],
      'Quận Cầu Giấy': ['Phường Dịch Vọng', 'Phường Yên Hòa', 'Phường Nghĩa Đô'],
      'Quận Hai Bà Trưng': ['Phường Bạch Mai', 'Phường Lê Đại Hành', 'Phường Quỳnh Mai'],
    },
    'Đà Nẵng': {
      'Quận Hải Châu': ['Phường Hải Châu I', 'Phường Thạch Thang', 'Phường Bình Hiên'],
      'Quận Sơn Trà': ['Phường An Hải Bắc', 'Phường An Hải Đông', 'Phường Phước Mỹ'],
    },
    'Cần Thơ': {
      'Quận Ninh Kiều': ['Phường Tân An', 'Phường An Hòa', 'Phường Xuân Khánh'],
      'Quận Bình Thủy': ['Phường Bùi Hữu Nghĩa', 'Phường Bình Thủy', 'Phường Long Hòa'],
    },
    'Bình Dương': {
      'Thành phố Thủ Dầu Một': ['Phường Phú Cường', 'Phường Hiệp Thành', 'Phường Chánh Nghĩa'],
      'Thành phố Thuận An': ['Phường Lái Thiêu', 'Phường An Phú', 'Phường Bình Hòa'],
    },
  };

  static List<String> get provinces => _data.keys.toList();

  static List<String> districtsOf(String province) {
    return _data[province]?.keys.toList() ?? const [];
  }

  static List<String> wardsOf(String province, String district) {
    return _data[province]?[district] ?? const [];
  }
}
