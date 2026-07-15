import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../screens/customer/cart/cart_screen.dart';
import '../../../theme/theme.dart';
import '../../../widgets/customer/cart_badge.dart';
import '../../../widgets/customer/chat_floating_button.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final PageController _pageController;
  int _imageIndex = 0;
  int _weightIndex = 0;
  int _grindIndex = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id == widget.product.id) return;
    _imageIndex = 0;
    _weightIndex = 0;
    _grindIndex = 0;
    _quantity = 1;
    _pageController.jumpToPage(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cart = context.watch<CartProvider>();
    final isWholesale = cart.isAgent;
    final weights = _uniqueWeights(product);
    final grinds = _uniqueGrinds(product);
    final weight = weights[_weightIndex.clamp(0, weights.length - 1)];
    final grind = grinds.isEmpty
        ? ''
        : grinds[_grindIndex.clamp(0, grinds.length - 1)];
    final currentPrice = product.priceFor(weight, isAgent: isWholesale);
    final retailPrice = product.priceFor(
      weight,
      isAgent: false,
      includeSale: false,
    );
    final images = _imageUrls(product);
    final totalPrice = currentPrice * _quantity;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.charColor,
      floatingActionButton: const ChatFloatingButton(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton.filledTonal(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          CartBadge(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ProductGallery(
                  images: images,
                  productName: product.name,
                  pageController: _pageController,
                  currentIndex: _imageIndex,
                  onPageChanged: (index) => setState(() => _imageIndex = index),
                  onThumbnailTap: (index) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 122),
                sliver: SliverList.list(
                  children: [
                    _ProductHeader(
                      product: product,
                      currentPrice: currentPrice,
                      retailPrice: retailPrice,
                      isWholesale: isWholesale,
                    ),
                    const SizedBox(height: 18),
                    _OptionPanel(
                      title: 'TRỌNG LƯỢNG',
                      children: [
                        _OptionWrap(
                          values: weights,
                          selectedIndex: _weightIndex,
                          onSelected: (index) =>
                              setState(() => _weightIndex = index),
                        ),
                        if (grinds.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const _SectionLabel('KIỂU XAY'),
                          const SizedBox(height: 10),
                          _OptionWrap(
                            values: grinds.map(_grindName).toList(),
                            selectedIndex: _grindIndex,
                            onSelected: (index) =>
                                setState(() => _grindIndex = index),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    _FlavorSection(product: product),
                    const SizedBox(height: 18),
                    _DescriptionSection(product: product, weights: weights),
                    const SizedBox(height: 18),
                    _RelatedProductsSection(currentProduct: product),
                  ],
                ),
              ),
            ],
          ),
          _StickyCartBar(
            quantity: _quantity,
            isOutOfStock: product.isOutOfStock,
            totalPrice: totalPrice,
            onDecrease: _quantity > 1
                ? () => setState(() => _quantity--)
                : null,
            onIncrease: () => setState(() => _quantity++),
            onAddToCart: () async {
              final message = await context.read<CartProvider>().addItem(
                product,
                weight: weight,
                grindType: grind.isEmpty ? 'Không xay' : grind,
                quantity: _quantity,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message ?? 'Đã thêm vào giỏ hàng'),
                  backgroundColor: message == null ? null : AppTheme.blazeColor,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static List<String> _uniqueWeights(Product product) {
    final values = <String>{};
    for (final weight in product.weights) {
      final trimmed = weight.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    for (final weight in product.pricesByWeight.keys) {
      final trimmed = weight.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    if (values.isEmpty) values.add('500g');
    return values.toList();
  }

  static List<String> _uniqueGrinds(Product product) {
    final values = <String>{};
    for (final grind in product.grindOptions) {
      final trimmed = grind.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    return values.toList();
  }

  static List<String> _imageUrls(Product product) {
    final values = product.imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    return values.isEmpty ? const [''] : values;
  }
}

class _ProductGallery extends StatelessWidget {
  const _ProductGallery({
    required this.images,
    required this.productName,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onThumbnailTap,
  });

  final List<String> images;
  final String productName;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onThumbnailTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF160D09),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Column(
        children: [
          SizedBox(
            height: 322,
            child: PageView.builder(
              controller: pageController,
              itemCount: images.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                return _CoffeeImage(url: images[index], label: productName);
              },
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = index == currentIndex;
                  return GestureDetector(
                    onTap: () => onThumbnailTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF8B4513)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _CoffeeImage(
                          url: images[index],
                          label: productName,
                          compact: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == currentIndex ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == currentIndex
                        ? AppTheme.goldColor
                        : AppTheme.lineColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CoffeeImage extends StatelessWidget {
  const _CoffeeImage({
    required this.url,
    required this.label,
    this.compact = false,
  });

  final String url;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _ImageFallback(compact: compact);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => _ImageFallback(compact: compact),
      errorWidget: (context, url, error) => _ImageFallback(compact: compact),
      imageBuilder: (context, imageProvider) {
        return DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2B1710), Color(0xFF63301A), Color(0xFF1E130F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.local_cafe_rounded,
        color: AppTheme.goldColor,
        size: compact ? 28 : 76,
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    required this.product,
    required this.currentPrice,
    required this.retailPrice,
    required this.isWholesale,
  });

  final Product product;
  final int currentPrice;
  final int retailPrice;
  final bool isWholesale;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0', 'vi_VN');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.badge.isNotEmpty || product.isBestSeller)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.lineColor),
            ),
            child: Text(
              product.badge.isNotEmpty ? product.badge : 'Bán chạy',
              style: const TextStyle(
                color: AppTheme.goldColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        Text(
          product.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.lightTextColor,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            Icon(Icons.star_half_rounded, color: Colors.amber, size: 16),
            SizedBox(width: 6),
            Text(
              '(4.8) · 128 đánh giá',
              style: TextStyle(color: AppTheme.mutedColor, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${currency.format(currentPrice)}đ',
              style: const TextStyle(
                color: Color(0xFFE74C3C),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            if (product.stock > 0) ...[
              const SizedBox(width: 10),
              Text(
                'Còn ${product.stock}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: product.isLowStock
                      ? Colors.orangeAccent
                      : AppTheme.mutedColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        if (isWholesale && retailPrice > currentPrice) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${currency.format(retailPrice)}đ',
                style: const TextStyle(
                  color: AppTheme.mutedColor,
                  fontSize: 16,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Giá sỉ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OptionPanel extends StatelessWidget {
  const _OptionPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _OptionWrap extends StatelessWidget {
  const _OptionWrap({
    required this.values,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> values;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(values.length, (index) {
        final selected = selectedIndex == index;
        return InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF8B4513) : Colors.transparent,
              border: Border.all(
                color: selected
                    ? const Color(0xFF8B4513)
                    : AppTheme.lineSoftColor,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              values[index],
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.creamColor,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _FlavorSection extends StatelessWidget {
  const _FlavorSection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final bitterness = _profileValue(product, const [
      'bitterness',
      'bitter',
      'dang',
    ]);
    final sourness = _profileValue(product, const ['sourness', 'sour', 'chua']);
    final aroma = _profileValue(product, const ['aroma', 'fragrance', 'huong']);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('HƯƠNG VỊ'),
          const SizedBox(height: 12),
          _FlavorBar(label: 'Độ đắng', value: bitterness),
          _FlavorBar(label: 'Độ chua', value: sourness),
          _FlavorBar(label: 'Hương thơm', value: aroma),
        ],
      ),
    );
  }

  static int _profileValue(Product product, List<String> keys) {
    for (final entry in product.flavorProfile.entries) {
      final key = entry.key.toLowerCase();
      if (keys.any((needle) => key.contains(needle))) {
        return entry.value.clamp(0, 5).toInt();
      }
    }
    if (keys.first == 'bitterness') return 4;
    if (keys.first == 'sourness') return 1;
    return 5;
  }
}

class _FlavorBar extends StatelessWidget {
  const _FlavorBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.mutedColor,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 5,
                backgroundColor: AppTheme.surfaceRaisedColor,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF8B4513)),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value/5',
            style: const TextStyle(
              color: AppTheme.mutedColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.product, required this.weights});

  final Product product;
  final List<String> weights;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('MÔ TẢ'),
          const SizedBox(height: 10),
          _ExpandableText(text: _description(product, weights)),
        ],
      ),
    );
  }

  static String _description(Product product, List<String> weights) {
    if (product.description.trim().isNotEmpty) {
      return product.description.trim();
    }
    final weightText = weights.join(' / ');
    return '''
${product.name} được chọn lọc theo gu cà phê Việt Nam, phù hợp pha phin, pha máy hoặc dùng hằng ngày tại gia đình và văn phòng.

1. THÔNG TIN CHUNG:
- Định lượng: $weightText
- Thành phần: Cà phê rang mộc chọn lọc
- Hạn sử dụng: 12 tháng kể từ ngày rang
- Xuất xứ: Việt Nam
- Thương hiệu: Cà Phê Hải Tín

2. HƯỚNG DẪN PHA CHẾ:
- Tỉ lệ: 20-25g cà phê / 200ml nước
- Nhiệt độ nước: 90-95°C
- Thời gian pha phin: 4-5 phút
- Có thể pha thêm đá, sữa đặc tùy khẩu vị

3. BẢO QUẢN:
- Bảo quản nơi khô ráo, thoáng mát
- Tránh ánh nắng trực tiếp và độ ẩm cao
- Sau khi mở: nên dùng trong vòng 30 ngày
''';
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : 4,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.creamColor,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'Thu gọn' : 'Xem thêm'),
        ),
      ],
    );
  }
}

class _RelatedProductsSection extends StatelessWidget {
  const _RelatedProductsSection({required this.currentProduct});

  final Product currentProduct;

  @override
  Widget build(BuildContext context) {
    final related = context
        .watch<ProductProvider>()
        .products
        .where(
          (product) =>
              product.id != currentProduct.id &&
              product.category == currentProduct.category,
        )
        .take(6)
        .toList();

    if (related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('SẢN PHẨM LIÊN QUAN'),
        const SizedBox(height: 10),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _SmallProductCard(product: related[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _SmallProductCard extends StatelessWidget {
  const _SmallProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final currency = NumberFormat('#,##0', 'vi_VN');
    final weight = product.weights.isEmpty ? '500g' : product.weights.first;
    final price = product.priceFor(weight, isAgent: cart.isAgent);
    return InkWell(
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 142,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.lineColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CoffeeImage(
                url: product.imageUrls.isEmpty ? '' : product.imageUrls.first,
                label: product.name,
                compact: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currency.format(price)}đ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE74C3C),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyCartBar extends StatelessWidget {
  const _StickyCartBar({
    required this.quantity,
    required this.isOutOfStock,
    required this.totalPrice,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAddToCart,
  });

  final int quantity;
  final bool isOutOfStock;
  final int totalPrice;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0', 'vi_VN');
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1A0A00),
            border: Border(top: BorderSide(color: AppTheme.lineColor)),
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.lineSoftColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Giảm',
                      onPressed: onDecrease,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tăng',
                      onPressed: onIncrease,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isOutOfStock ? null : onAddToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOutOfStock
                        ? Colors.grey
                        : const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade700,
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isOutOfStock
                          ? 'HẾT HÀNG'
                          : 'THÊM VÀO GIỎ · ${currency.format(totalPrice)}đ',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.mutedColor,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
  }
}

String _grindName(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('nguyên') || normalized.contains('hat')) {
    return 'Nguyên hạt';
  }
  if (normalized.contains('mịn') || normalized.contains('may')) {
    return 'Xay mịn pha máy';
  }
  if (normalized.contains('phin')) return 'Xay pha phin';
  return value;
}
