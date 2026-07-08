import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../theme/theme.dart';
import '../../../widgets/customer/chat_floating_button.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _weightIndex = 0;
  int _grindIndex = 0;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cart = context.watch<CartProvider>();
    final isAgent = cart.isAgent;
    final weight = product.weights.isNotEmpty
        ? product.weights[_weightIndex.clamp(0, product.weights.length - 1)]
        : '500g';
    final grind = product.grindOptions.isNotEmpty
        ? product.grindOptions[_grindIndex.clamp(
            0,
            product.grindOptions.length - 1,
          )]
        : 'Xay pha phin';
    final price = product.priceFor(weight, isAgent: isAgent);
    final currency = NumberFormat('#,##0', 'vi_VN');
    final salePrice = product.isOnSale && !isAgent
        ? product.priceFor(weight, isAgent: false, includeSale: true)
        : null;
    final originalPrice = product.isOnSale && !isAgent
        ? product.priceFor(weight, isAgent: false, includeSale: false)
        : null;

    return Scaffold(
      backgroundColor: AppTheme.charColor,
      floatingActionButton: const ChatFloatingButton(),
      appBar: AppBar(title: const Text('Chi Tiết Sản Phẩm'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.1,
              child: product.imageUrls.isEmpty
                  ? Container(
                      color: AppTheme.surfaceAltColor,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.coffee_rounded,
                        color: AppTheme.goldColor,
                        size: 62,
                      ),
                    )
                  : Image.network(
                      product.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppTheme.surfaceAltColor,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.coffee_rounded,
                            color: AppTheme.goldColor,
                            size: 62,
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (product.isOnSale && !isAgent)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.flameGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  product.salePercent != null && product.salePercent! > 0
                      ? '-${product.salePercent}%'
                      : 'SALE',
                  style: const TextStyle(
                    color: AppTheme.charColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            product.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            product.description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (originalPrice != null) ...[
                Text(
                  '${currency.format(originalPrice)}đ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedColor,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                '${currency.format(salePrice ?? price)}đ',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.goldColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Trọng lượng'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              product.weights.isEmpty ? 1 : product.weights.length,
              (index) {
                final selected = _weightIndex == index;
                final value = product.weights.isEmpty
                    ? '500g'
                    : product.weights[index];
                return ChoiceChip(
                  label: Text(value),
                  selected: selected,
                  onSelected: (_) => setState(() => _weightIndex = index),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Độ xay'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              product.grindOptions.isEmpty ? 1 : product.grindOptions.length,
              (index) {
                final selected = _grindIndex == index;
                final value = product.grindOptions.isEmpty
                    ? 'Xay pha phin'
                    : product.grindOptions[index];
                return ChoiceChip(
                  label: Text(value),
                  selected: selected,
                  onSelected: (_) => setState(() => _grindIndex = index),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Số lượng'),
          const SizedBox(height: 10),
          Row(
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '$_quantity',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _StepperButton(
                icon: Icons.add_rounded,
                onPressed: () => setState(() => _quantity++),
              ),
              const Spacer(),
              Text(
                'Tồn kho: ${product.stock}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: product.isLowStock
                      ? Colors.orangeAccent
                      : AppTheme.mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppTheme.flameGradient,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                onPressed: product.isOutOfStock
                    ? null
                    : () async {
                        final message = await context
                            .read<CartProvider>()
                            .addItem(
                              product,
                              weight: weight,
                              grindType: grind,
                              quantity: _quantity,
                            );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message ?? 'Đã thêm vào giỏ hàng'),
                            backgroundColor: message == null
                                ? null
                                : AppTheme.blazeColor,
                          ),
                        );
                      },
                child: Text(
                  'Thêm vào giỏ · ${currency.format((salePrice ?? price) * _quantity)}đ',
                  style: const TextStyle(
                    color: AppTheme.charColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.lineColor),
        ),
        child: Icon(
          icon,
          color: onPressed == null ? AppTheme.mutedColor : AppTheme.creamColor,
        ),
      ),
    );
  }
}
