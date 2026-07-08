import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/customer/cart_badge.dart';
import '../../widgets/customer/coffee_search_bar.dart';
import '../../widgets/product_card.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    this.onCartTap,
    this.initialCategoryTitle,
  });

  final VoidCallback? onCartTap;
  final String? initialCategoryTitle;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  int _selectedCategory = 0;
  String _query = '';
  ProductSortOption _sort = ProductSortOption.bestSeller;
  bool _appliedInitialCategory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadCatalog();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<ProductProvider>();
    final isAgent = context.watch<CartProvider>().isAgent;
    final categories = catalog.categories;

    if (!_appliedInitialCategory &&
        widget.initialCategoryTitle != null &&
        categories.isNotEmpty) {
      final matchedIndex = categories.indexWhere(
        (item) =>
            item.title.toLowerCase() ==
            widget.initialCategoryTitle!.trim().toLowerCase(),
      );
      if (matchedIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedCategory = matchedIndex);
        });
        _appliedInitialCategory = true;
      }
    }

    if (_selectedCategory >= categories.length && categories.isNotEmpty) {
      _selectedCategory = 0;
    }

    final selectedTitle = categories.isEmpty
        ? ''
        : categories[_selectedCategory].title;
    final products = selectedTitle.isEmpty
        ? <Product>[]
        : catalog.byCategory(
            selectedTitle,
            sort: _sort,
            query: _query,
            isAgent: isAgent,
          );

    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(
        title: const Text('Danh Mục Sản Phẩm'),
        centerTitle: true,
        actions: [
          CartBadge(onPressed: widget.onCartTap ?? () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            children: [
              CoffeeSearchBar(
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: catalog.isLoading && !catalog.hasLoaded
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.goldColor,
                        ),
                      )
                    : catalog.hasLoadError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              catalog.errorMessage ?? 'Không tải được dữ liệu sản phẩm',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.mutedColor),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context
                                  .read<ProductProvider>()
                                  .loadCatalog(force: true),
                              child: const Text('Tải lại'),
                            ),
                          ],
                        ),
                      )
                    : categories.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có danh mục sản phẩm',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.mutedColor),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 620;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 170,
                                  child: _CategoryTabs(
                                    categories: categories,
                                    selectedIndex: _selectedCategory,
                                    vertical: true,
                                    onSelected: (index) => setState(
                                      () => _selectedCategory = index,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _ProductGrid(
                                    products: products,
                                    sort: _sort,
                                    onSortChanged: (value) =>
                                        setState(() => _sort = value),
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              _CategoryTabs(
                                categories: categories,
                                selectedIndex: _selectedCategory,
                                vertical: false,
                                onSelected: (index) =>
                                    setState(() => _selectedCategory = index),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _ProductGrid(
                                  products: products,
                                  sort: _sort,
                                  onSortChanged: (value) =>
                                      setState(() => _sort = value),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selectedIndex,
    required this.vertical,
    required this.onSelected,
  });

  final List<CategoryItem> categories;
  final int selectedIndex;
  final bool vertical;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final children = List.generate(categories.length, (index) {
      final item = categories[index];
      final selected = selectedIndex == index;
      return Padding(
        padding: EdgeInsets.only(
          right: vertical ? 0 : 8,
          bottom: vertical ? 10 : 0,
        ),
        child: InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: vertical ? double.infinity : 142,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: selected ? AppTheme.flameGradient : null,
              color: selected ? null : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? Colors.transparent : AppTheme.lineColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  color: selected ? AppTheme.charColor : AppTheme.goldColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? AppTheme.charColor
                          : AppTheme.creamColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });

    if (vertical) return Column(children: children);

    return SizedBox(
      height: 50,
      child: ListView(scrollDirection: Axis.horizontal, children: children),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.sort,
    required this.onSortChanged,
  });

  final List<Product> products;
  final ProductSortOption sort;
  final ValueChanged<ProductSortOption> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${products.length} sản phẩm',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.lineColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ProductSortOption>(
                  value: sort,
                  dropdownColor: AppTheme.surfaceColor,
                  iconEnabledColor: AppTheme.goldColor,
                  items: ProductSortOption.values
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Text(
                    'Chưa tìm thấy sản phẩm phù hợp',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.mutedColor,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      onAddToCart: () async {
                        final message = await context.read<CartProvider>().addItem(
                          product,
                          weight: product.weights.isEmpty
                              ? '500g'
                              : product.weights.first,
                          grindType: product.grindOptions.isEmpty
                              ? 'Xay pha phin'
                              : product.grindOptions.first,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message ?? 'Đã thêm sản phẩm vào giỏ'),
                            backgroundColor: message == null
                                ? null
                                : AppTheme.blazeColor,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
