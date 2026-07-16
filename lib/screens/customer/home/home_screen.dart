import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/banner_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../screens/customer/catalog/category_screen.dart';
import '../../../screens/auth/login_screen.dart';
import '../../../screens/customer/product/product_detail_screen.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/theme.dart';
import '../../../utils/open_external_url.dart';
import '../../../widgets/customer/banner_slider.dart';
import '../../../widgets/customer/cart_badge.dart';
import '../../../widgets/customer/brand_logo.dart';
import '../../../widgets/customer/coffee_search_bar.dart';
import '../../../widgets/customer/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onTabSelected, this.onCategorySelected});

  final ValueChanged<int>? onTabSelected;
  final ValueChanged<String>? onCategorySelected;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hideGuestBanner = false;
  late Future<List<Product>> _bestSellersFuture;

  @override
  void initState() {
    super.initState();
    _bestSellersFuture = SupabaseService.fetchBestSellers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProductProvider>().loadCatalog();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openBanner(BannerItem banner) async {
    final type = banner.linkType.toLowerCase();
    if (type == 'none' || banner.linkValue.trim().isEmpty) return;

    if (type == 'url') {
      await openExternalUrl(banner.linkValue.trim());
      return;
    }

    if (type == 'product') {
      final product = await SupabaseService.fetchProductById(
        banner.linkValue.trim(),
      );
      if (!mounted) return;
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy sản phẩm')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      );
      return;
    }

    if (type == 'category') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CategoryScreen(
            initialCategoryTitle: banner.linkValue.trim(),
            onCartTap: () => widget.onTabSelected?.call(2),
          ),
        ),
      );
    }
  }

  Future<void> _addToCartIfLoggedIn(
    BuildContext context,
    Product product,
  ) async {
    final message = await context.read<CartProvider>().addItem(
      product,
      weight: product.weights.isEmpty ? '500g' : product.weights.first,
      grindType: product.grindOptions.isEmpty
          ? 'Xay pha phin'
          : product.grindOptions.first,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Đã thêm sản phẩm vào giỏ'),
        backgroundColor: message == null ? null : AppTheme.blazeColor,
      ),
    );
  }

  void _openQuickCategory(String title) {
    final onCategorySelected = widget.onCategorySelected;
    if (onCategorySelected != null) {
      onCategorySelected(title);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryScreen(
          initialCategoryTitle: title,
          onCartTap: () => widget.onTabSelected?.call(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<ProductProvider>();
    final auth = context.watch<AuthProvider>();
    final guest = SupabaseService.currentUser == null;
    final displayName = auth.fullName.trim().isEmpty
        ? (auth.email.isNotEmpty ? auth.email.split('@').first : 'bạn')
        : auth.fullName.trim();

    return Scaffold(
      backgroundColor: AppTheme.pageColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                color: AppTheme.charColor,
                border: Border(
                  bottom: BorderSide(color: AppTheme.goldColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const BrandLogo(size: 46, color: AppTheme.lightTextColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cà Phê Hải Tín',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.lightTextColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          guest ? 'Chào bạn' : 'Chào $displayName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.goldColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    color: AppTheme.lightTextColor,
                    icon: const Icon(Icons.favorite_border_rounded),
                  ),
                  CartBadge(
                    onPressed: () => widget.onTabSelected?.call(2),
                    iconColor: AppTheme.lightTextColor,
                  ),
                ],
              ),
            ),
            if (guest && !_hideGuestBanner)
              _GuestLoginBanner(
                onClose: () => setState(() => _hideGuestBanner = true),
                onLogin: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: CoffeeSearchBar(),
            ),
            Expanded(
              child: catalog.isLoading && !catalog.hasLoaded
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.goldColor,
                      ),
                    )
                  : catalog.hasLoadError
                  ? _CatalogMessage(
                      text:
                          catalog.errorMessage ??
                          'Không tải được dữ liệu sản phẩm',
                      onRetry: () => context
                          .read<ProductProvider>()
                          .loadCatalog(force: true),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        BannerSlider(onTap: _openBanner),
                        const SizedBox(height: 24),
                        Text(
                          'Danh Mục Nhanh',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppTheme.creamColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 12),
                        catalog.categories.isEmpty
                            ? const _EmptyText('Chưa có danh mục')
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.8,
                                    ),
                                itemCount: catalog.categories.length,
                                itemBuilder: (context, index) {
                                  final item = catalog.categories[index];
                                  return InkWell(
                                    onTap: () => _openQuickCategory(item.title),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceColor,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.lineColor,
                                            ),
                                          ),
                                          child: Icon(
                                            item.icon,
                                            color: AppTheme.goldColor,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.title,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppTheme.mutedColor,
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sản phẩm bán chạy',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppTheme.creamColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            TextButton(
                              onPressed: () => widget.onTabSelected?.call(1),
                              child: const Text('Xem tất cả'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<Product>>(
                          future: _bestSellersFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const _ShimmerGrid();
                            }

                            final bestSellers = snapshot.data ?? const [];
                            if (bestSellers.isEmpty) {
                              return _EmptyText(
                                catalog.isCatalogEmpty
                                    ? 'Cửa hàng chưa có sản phẩm nào, quay lại sau nhé'
                                    : 'Chưa có sản phẩm bán chạy',
                              );
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.78,
                                  ),
                              itemCount: bestSellers.length,
                              itemBuilder: (context, index) {
                                final product = bestSellers[index];
                                return ProductCard(
                                  product: product,
                                  onAddToCart: () =>
                                      _addToCartIfLoggedIn(context, product),
                                );
                              },
                            );
                          },
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

class _GuestLoginBanner extends StatelessWidget {
  const _GuestLoginBanner({required this.onClose, required this.onLogin});

  final VoidCallback onClose;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.flameGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đăng nhập để tích điểm và theo dõi đơn hàng dễ dàng hơn',
                  style: TextStyle(
                    color: AppTheme.charColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onLogin,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: Colors.black.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Đăng nhập ngay',
                    style: TextStyle(
                      color: AppTheme.charColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: AppTheme.charColor),
          ),
        ],
      ),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAltColor.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, color: AppTheme.surfaceAltColor),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 96,
                      color: AppTheme.surfaceAltColor,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          height: 14,
                          width: 68,
                          color: AppTheme.surfaceAltColor,
                        ),
                        const Spacer(),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAltColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Tải lại')),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
        ),
      ),
    );
  }
}
