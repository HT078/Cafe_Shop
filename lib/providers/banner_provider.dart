import 'package:flutter/material.dart';

import '../models/banner_model.dart';
import '../services/supabase_service.dart';

class BannerProvider extends ChangeNotifier {
  List<BannerItem> _items = [];
  bool _loading = false;
  String? _errorMessage;

  List<BannerItem> get items =>
      List.unmodifiable(_items.where((item) => item.isVisibleNow));

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;

  Future<void> loadBanners({bool force = false}) async {
    if (_loading) return;
    if (!force && _items.isNotEmpty) return;

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final rows = await SupabaseService.client
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      _items = rows
          .map<BannerItem>(
            (row) => BannerItem.fromMap(Map<String, dynamic>.from(row)),
          )
          .toList();
      debugPrint('BannerProvider.loadBanners: loaded ${_items.length} rows');
    } catch (error, stackTrace) {
      _items = [];
      _errorMessage = error.toString();
      debugPrint('BannerProvider.loadBanners failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
