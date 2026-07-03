import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../screens/customer/product/product_detail_screen.dart';
import '../theme/theme.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
    this.onTap,
  });

  final Product product;
  final VoidCallback onAddToCart;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final isAgent = cart.isAgent;
    final currency = NumberFormat('#,##0', 'vi_VN');
    final weight = product.weights.isNotEmpty ? product.weights.first : '500g';
    final price = product.priceFor(weight, isAgent: isAgent);
    final salePrice = product.isOnSale && !isAgent
        ? product.priceFor(weight, isAgent: false, includeSale: true)
        : null;
    final originalPrice = product.isOnSale && !isAgent
        ? product.priceFor(weight, isAgent: false, includeSale: false)
        : null;

    return InkWell(
      onTap: onTap ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          },
      borderRadius: BorderRadius.circular(18),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.08,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ProductImage(url: product.imageUrls.isNotEmpty ? product.imageUrls.first : ''),
                  if (product.isOnSale && !isAgent)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _Badge(
                        label: product.salePercent != null && product.salePercent! > 0
                            ? '-${product.salePercent}%'
                            : 'SALE',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8A93C), Color(0xFFC81E2C)],
                        ),
                      ),
                    )
                  else if (product.badge.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _Badge(label: product.badge),
                    ),
                  if (product.isOutOfStock)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.lineColor),
                        ),
                        child: const Text(
                          'Hết hàng',
                          style: TextStyle(
                            color: AppTheme.creamColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.weightLabel.isEmpty ? product.category : product.weightLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (originalPrice != null) ...[
                              Text(
                                '${currency.format(originalPrice)}đ',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.mutedColor,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              '${currency.format(salePrice ?? price)}đ',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.goldColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _AddButton(
                        enabled: !product.isOutOfStock,
                        onPressed: onAddToCart,
                      ),
                    ],
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: AppTheme.surfaceAltColor,
        alignment: Alignment.center,
        child: const Icon(Icons.coffee_rounded, color: AppTheme.goldColor, size: 38),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppTheme.surfaceAltColor,
          alignment: Alignment.center,
          child: const Icon(Icons.coffee_rounded, color: AppTheme.goldColor, size: 38),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.gradient});

  final String label;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? Colors.black.withValues(alpha: 0.45) : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.creamColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.flameGradient : null,
        color: enabled ? null : AppTheme.surfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: enabled ? Colors.transparent : AppTheme.lineColor),
      ),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.add_rounded,
          size: 20,
          color: enabled ? AppTheme.charColor : AppTheme.mutedColor,
        ),
      ),
    );
  }
}
