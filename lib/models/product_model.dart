class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.pricesByWeight,
    required this.imageUrls,
    required this.badge,
    required this.flavorProfile,
    required this.grindOptions,
    required this.weights,
    required this.isBestSeller,
    required this.weightLabel,
    this.stock = 0,
    this.lowStockThreshold = 5,
    this.isActive = true,
    this.salePercent,
    this.salePrice,
    this.saleStart,
    this.saleEnd,
    this.agentPricesByWeight = const {},
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int price;
  final Map<String, int> pricesByWeight;
  final List<String> imageUrls;
  final String badge;
  final Map<String, int> flavorProfile;
  final List<String> grindOptions;
  final List<String> weights;
  final bool isBestSeller;
  final String weightLabel;
  final int stock;
  final int lowStockThreshold;
  final bool isActive;
  final int? salePercent;
  final int? salePrice;
  final DateTime? saleStart;
  final DateTime? saleEnd;
  final Map<String, int> agentPricesByWeight;

  bool get isLowStock => stock > 0 && stock < lowStockThreshold;

  bool get isOutOfStock => stock <= 0;

  bool get isOnSale {
    final now = DateTime.now();
    final startsOk = saleStart == null || !saleStart!.isAfter(now);
    final endsOk = saleEnd == null || saleEnd!.isAfter(now);
    return startsOk && endsOk && ((salePercent ?? 0) > 0 || (salePrice ?? 0) > 0);
  }

  int priceFor(
    String weight, {
    bool isAgent = false,
    bool includeSale = true,
  }) {
    final retail = pricesByWeight[weight] ?? price;
    if (isAgent) return agentPricesByWeight[weight] ?? retail;
    if (!includeSale || !isOnSale) return retail;
    if ((salePrice ?? 0) > 0) return salePrice!;
    if ((salePercent ?? 0) > 0) {
      return (retail * (100 - salePercent!) / 100).round();
    }
    return retail;
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final categoryValue = map['category'];
    final categoryMap = map['categories'];
    final prices = _intMap(map['prices_by_weight'] ?? map['pricesByWeight']);

    final agentPrices = <String, int>{
      ..._intMap(map['agent_prices_by_weight'] ?? map['agentPricesByWeight']),
      if (map.containsKey('agent_price_250g')) '250g': _asInt(map['agent_price_250g']),
      if (map.containsKey('agent_price_500g')) '500g': _asInt(map['agent_price_500g']),
      if (map.containsKey('agent_price_1kg')) '1kg': _asInt(map['agent_price_1kg']),
    }..removeWhere((key, value) => value <= 0);

    return Product(
      id: map['id'].toString(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      category: categoryMap is Map
          ? (categoryMap['title'] ?? categoryMap['name'] ?? '').toString()
          : (categoryValue ?? '').toString(),
      price: _asInt(map['price']),
      pricesByWeight: prices,
      imageUrls: _stringList(
        map['image_urls'] ?? map['imageUrls'] ?? map['image_url'] ?? map['imageUrl'],
      ),
      badge: (map['badge'] ?? '').toString(),
      flavorProfile: _intMap(map['flavor_profile'] ?? map['flavorProfile']),
      grindOptions: _stringList(map['grind_options'] ?? map['grindOptions']),
      weights: _stringList(map['weights']).isEmpty ? prices.keys.toList() : _stringList(map['weights']),
      isBestSeller:
          map['is_bestseller'] == true ||
          map['is_best_seller'] == true ||
          map['isBestSeller'] == true,
      weightLabel: (map['weight_label'] ?? map['weightLabel'] ?? '').toString(),
      stock: _asInt(map['stock']),
      lowStockThreshold: _asInt(map['low_stock_threshold']) == 0 ? 5 : _asInt(map['low_stock_threshold']),
      isActive: map['is_active'] != false && _asInt(map['stock']) > 0,
      salePercent: _nullableInt(map['sale_percent']),
      salePrice: _nullableInt(map['sale_price']),
      saleStart: _date(map['sale_start']),
      saleEnd: _date(map['sale_end']),
      agentPricesByWeight: agentPrices,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    final parsed = _asInt(value);
    return parsed == 0 ? null : parsed;
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  static Map<String, int> _intMap(dynamic value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), _asInt(item)));
    }
    return const {};
  }
}
