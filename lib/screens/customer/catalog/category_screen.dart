import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../theme/theme.dart';
import '../../../widgets/customer/cart_badge.dart';
import '../../../widgets/customer/coffee_search_bar.dart';
import '../../../widgets/customer/product_card.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, this.onCartTap, this.initialCategoryTitle});

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
      if (!mounted) return;
      context.read<ProductProvider>().loadCatalog();
    });
  }

  @override
  void didUpdateWidget(covariant CategoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategoryTitle != widget.initialCategoryTitle) {
      _appliedInitialCategory = false;
    }
  }

  void _applyInitialCategory(List<CategoryItem> categories) {
    if (_appliedInitialCategory ||
        widget.initialCategoryTitle == null ||
        categories.isEmpty) {
      return;
    }

    _appliedInitialCategory = true;
    final requestedCategory = _categoryKey(widget.initialCategoryTitle!);
    final matchedIndex = categories.indexWhere(
      (item) => _categoryKey(item.title) == requestedCategory,
    );
    if (matchedIndex < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedCategory = matchedIndex);
    });
  }

  String _categoryKey(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (normalized == 'chua phan loai' || normalized == 'chưa phân loại') {
      return 'chua phan loai';
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<ProductProvider>();
    final isAgent = context.watch<CartProvider>().isAgent;
    final categories = catalog.categories;

    _applyInitialCategory(categories);

    final selectedIndex = categories.isEmpty
        ? 0
        : _selectedCategory.clamp(0, categories.length - 1);
    final selectedTitle = categories.isEmpty
        ? ''
        : categories[selectedIndex].title;
    final products = selectedTitle.isEmpty
        ? <Product>[]
        : catalog.byCategory(
            selectedTitle,
            sort: _sort,
            query: _query,
            isAgent: isAgent,
          );

    return Scaffold(
      backgroundColor: AppTheme.pageColor,
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
        child: LayoutBuilder(
          builder: (context, viewport) {
            final horizontalPadding = viewport.maxWidth >= 720 ? 20.0 : 16.0;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    0,
                  ),
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
                            ? _CatalogStateMessage(
                                text:
                                    catalog.errorMessage ??
                                    'Không tải được dữ liệu sản phẩm',
                                actionLabel: 'Tải lại',
                                onAction: () => context
                                    .read<ProductProvider>()
                                    .loadCatalog(force: true),
                              )
                            : categories.isEmpty
                            ? const _CatalogStateMessage(
                                text: 'Chưa có danh mục sản phẩm',
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final useSideRail =
                                      constraints.maxWidth >= 940;

                                  if (useSideRail) {
                                    final railWidth =
                                        constraints.maxWidth >= 1160
                                        ? 220.0
                                        : 188.0;

                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: railWidth,
                                          child: _CategoryTabs(
                                            categories: categories,
                                            selectedIndex: selectedIndex,
                                            vertical: true,
                                            onSelected: (index) => setState(
                                              () => _selectedCategory = index,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _ProductSection(
                                            title: selectedTitle,
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
                                        selectedIndex: selectedIndex,
                                        vertical: false,
                                        onSelected: (index) => setState(
                                          () => _selectedCategory = index,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: _ProductSection(
                                          title: selectedTitle,
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
          },
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
    final chips = List.generate(categories.length, (index) {
      final item = categories[index];
      final selected = selectedIndex == index;

      return Padding(
        padding: EdgeInsets.only(
          right: vertical ? 0 : 10,
          bottom: vertical ? 10 : 0,
        ),
        child: InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: vertical ? double.infinity : null,
            constraints: BoxConstraints(
              minHeight: 58,
              minWidth: vertical ? 0 : 144,
              maxWidth: vertical ? double.infinity : 220,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: selected ? AppTheme.flameGradient : null,
              color: selected ? null : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? Colors.transparent : AppTheme.lineColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? AppTheme.charColor : AppTheme.goldColor,
                ),
                const SizedBox(width: 10),
                Flexible(
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

    if (vertical) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.lineColor),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: chips,
          ),
        ),
      );
    }

    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: chips,
      ),
    );
  }
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.title,
    required this.products,
    required this.sort,
    required this.onSortChanged,
  });

  final String title;
  final List<Product> products;
  final ProductSortOption sort;
  final ValueChanged<ProductSortOption> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeader = constraints.maxWidth < 560;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.lineColor),
                gradient: AppTheme.cardGlowGradient,
              ),
              child: compactHeader
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeading(title: title, count: products.length),
                        const SizedBox(height: 12),
                        _SortDropdown(
                          sort: sort,
                          onChanged: onSortChanged,
                          expanded: true,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _SectionHeading(
                            title: title,
                            count: products.length,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 230,
                          child: _SortDropdown(
                            sort: sort,
                            onChanged: onSortChanged,
                            expanded: false,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: products.isEmpty
                  ? const _CatalogStateMessage(
                      text: 'Chưa tìm thấy sản phẩm phù hợp',
                    )
                  : LayoutBuilder(
                      builder: (context, gridConstraints) {
                        final grid = _GridConfig.fromWidth(
                          gridConstraints.maxWidth,
                        );

                        return GridView.builder(
                          padding: const EdgeInsets.only(bottom: 28),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: grid.crossAxisCount,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: grid.childAspectRatio,
                              ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return ProductCard(
                              product: product,
                              onAddToCart: () async {
                                final message = await context
                                    .read<CartProvider>()
                                    .addItem(
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
                                    content: Text(
                                      message ?? 'Đã thêm sản phẩm vào giỏ',
                                    ),
                                    backgroundColor: message == null
                                        ? null
                                        : AppTheme.blazeColor,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          '$count sản phẩm',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.mutedColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({
    required this.sort,
    required this.onChanged,
    required this.expanded,
  });

  final ProductSortOption sort;
  final ValueChanged<ProductSortOption> onChanged;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductSortOption>(
          value: sort,
          isExpanded: expanded,
          dropdownColor: AppTheme.surfaceColor,
          iconEnabledColor: AppTheme.goldColor,
          items: ProductSortOption.values
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option.label)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _CatalogStateMessage extends StatelessWidget {
  const _CatalogStateMessage({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_cafe_outlined,
              size: 38,
              color: AppTheme.goldColor,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _GridConfig {
  const _GridConfig({
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  final int crossAxisCount;
  final double childAspectRatio;

  factory _GridConfig.fromWidth(double width) {
    if (width >= 1180) {
      return const _GridConfig(crossAxisCount: 4, childAspectRatio: 0.76);
    }
    if (width >= 900) {
      return const _GridConfig(crossAxisCount: 4, childAspectRatio: 0.75);
    }
    if (width >= 680) {
      return const _GridConfig(crossAxisCount: 3, childAspectRatio: 0.73);
    }
    if (width >= 360) {
      return const _GridConfig(crossAxisCount: 2, childAspectRatio: 0.7);
    }
    return const _GridConfig(crossAxisCount: 1, childAspectRatio: 0.82);
  }
}
