import 'package:flutter/material.dart';

import '../models/banner_model.dart';
import '../services/supabase_service.dart';

class BannerProvider extends ChangeNotifier {
  List<BannerItem> _items = [];
  bool _loading = false;

  List<BannerItem> get items =>
      List.unmodifiable(_items.where((item) => item.isVisibleNow));

  bool get isLoading => _loading;

  Future<void> loadBanners({bool force = false}) async {
    if (_loading) return;
    if (!force && _items.isNotEmpty) return;

    _loading = true;
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
    } catch (_) {
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
