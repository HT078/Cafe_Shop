import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_model.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';

enum ProductSortOption {
  bestSeller('Bán chạy'),
  priceAsc('Giá thấp đến cao'),
  priceDesc('Giá cao đến thấp');

  const ProductSortOption(this.label);

  final String label;
}

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<CategoryItem> _categories = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<Product> get products =>
      List.unmodifiable(_products.where((product) => product.isActive));

  List<CategoryItem> get categories => List.unmodifiable(_categories);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  bool get hasLoadError => _errorMessage != null;

  bool get isCatalogEmpty =>
      _hasLoaded && _errorMessage == null && products.isEmpty;

  String? get errorMessage => _errorMessage;

  // Tải categories và products từ Supabase.
  Future<void> loadCatalog({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _hasLoaded) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      try {
        _categories = await SupabaseService.fetchCategories();
        if (_categories.isEmpty) {
          debugPrint(
            'ProductProvider.loadCatalog(categories): query succeeded but returned 0 rows',
          );
        }
      } on Object catch (error, stackTrace) {
        _logLoadError('categories', error, stackTrace);
        _categories = [];
        _errorMessage = 'Không tải được dữ liệu sản phẩm';
      }

      try {
        _products = await SupabaseService.fetchProducts();
        _categories = _mergeCategories(
          _categories,
          _categoriesFromProducts(_products),
        );
        if (products.isEmpty) {
          debugPrint(
            'ProductProvider.loadCatalog(products): query succeeded but no active products available',
          );
        }
      } on Object catch (error, stackTrace) {
        _logLoadError('products', error, stackTrace);
        _products = [];
        _errorMessage = 'Không tải được dữ liệu sản phẩm';
      }
    } finally {
      _hasLoaded = true;
      if (_errorMessage == null && products.isEmpty) {
        debugPrint(
          'ProductProvider.loadCatalog: catalog is empty after successful query',
        );
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  void _logLoadError(String source, Object error, StackTrace stackTrace) {
    if (error is AuthException) {
      debugPrint(
        'ProductProvider.loadCatalog($source) failed: Supabase/Auth configuration issue: ${error.message}',
      );
    } else if (error is PostgrestException) {
      debugPrint(
        'ProductProvider.loadCatalog($source) failed: '
        'code=${error.code}, message=${error.message}, details=${error.details}, hint=${error.hint}',
      );
    } else {
      debugPrint('ProductProvider.loadCatalog($source) failed: $error');
    }
    debugPrintStack(stackTrace: stackTrace);
  }

  List<CategoryItem> _categoriesFromProducts(List<Product> products) {
    final titles = <String>{};
    for (final product in products) {
      final title = product.category.trim();
      if (title.isNotEmpty) titles.add(title);
    }
    final sortedTitles = titles.toList()..sort();
    return sortedTitles.map((title) {
      return CategoryItem.fromMap({'title': title});
    }).toList();
  }

  List<CategoryItem> _mergeCategories(
    List<CategoryItem> storedCategories,
    List<CategoryItem> productCategories,
  ) {
    final merged = <CategoryItem>[...storedCategories];
    final knownKeys = storedCategories
        .map((category) => _categoryKey(category.title))
        .toSet();

    for (final category in productCategories) {
      if (knownKeys.add(_categoryKey(category.title))) {
        merged.add(category);
      }
    }

    return merged;
  }

  List<Product> byCategory(
    String category, {
    ProductSortOption sort = ProductSortOption.bestSeller,
    String query = '',
    bool isAgent = false,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final categoryKey = _categoryKey(category);
    final filtered = products.where((product) {
      final matchesCategory = _categoryKey(product.category) == categoryKey;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery) ||
          product.description.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesQuery;
    }).toList();

    switch (sort) {
      case ProductSortOption.bestSeller:
        filtered.sort((a, b) {
          if (a.isBestSeller == b.isBestSeller) return a.name.compareTo(b.name);
          return a.isBestSeller ? -1 : 1;
        });
      case ProductSortOption.priceAsc:
        filtered.sort(
          (a, b) => _effectivePrice(
            a,
            isAgent,
          ).compareTo(_effectivePrice(b, isAgent)),
        );
      case ProductSortOption.priceDesc:
        filtered.sort(
          (a, b) => _effectivePrice(
            b,
            isAgent,
          ).compareTo(_effectivePrice(a, isAgent)),
        );
    }

    return filtered;
  }

  int _effectivePrice(Product product, bool isAgent) {
    final weight = product.weights.isNotEmpty ? product.weights.first : '500g';
    return product.priceFor(weight, isAgent: isAgent);
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
}
