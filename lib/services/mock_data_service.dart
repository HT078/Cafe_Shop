import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../models/product_model.dart';

class MockDataService {
  static List<CategoryItem> get categories => const [
        CategoryItem(title: 'Cà phê Bột', icon: Icons.coffee_outlined),
        CategoryItem(title: 'Cà phê Hạt', icon: Icons.grain_outlined),
        CategoryItem(title: 'Túi Lọc', icon: Icons.filter_alt_outlined),
        CategoryItem(title: 'Dụng Cụ Pha', icon: Icons.local_cafe_outlined),
      ];

  static List<Product> get products => [
        Product(
          id: 'robusta-500',
          name: 'Robusta Hải Tín Rang Củi',
          description: 'Hương đậm đà, hậu vị ấm, phù hợp pha phin truyền thống.',
          category: 'Cà phê Bột',
          price: 95000,
          pricesByWeight: {'250g': 48000, '500g': 95000, '1kg': 180000},
          imageUrls: ['https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=900&q=80'],
          badge: 'Bán chạy',
          flavorProfile: {'Đắng': 4, 'Chua': 2, 'Hương': 5},
          grindOptions: ['Nguyên hạt', 'Xay pha phin truyền thống', 'Xay mịn pha máy'],
          weights: ['250g', '500g', '1kg'],
          isBestSeller: true,
          weightLabel: 'Gói 500g · Nguyên hạt',
        ),
        Product(
          id: 'culi-250',
          name: 'Culi Đặc Biệt Sáng Bóng',
          description: 'Mùi thơm nồng, vị ngọt nhẹ, rất thích hợp cho buổi sáng.',
          category: 'Cà phê Hạt',
          price: 78000,
          pricesByWeight: {'250g': 78000, '500g': 148000, '1kg': 280000},
          imageUrls: ['https://images.unsplash.com/photo-1511920170033-f8396924c348?auto=format&fit=crop&w=900&q=80'],
          badge: 'Mới',
          flavorProfile: {'Đắng': 3, 'Chua': 3, 'Hương': 5},
          grindOptions: ['Nguyên hạt', 'Xay pha phin truyền thống', 'Xay mịn pha máy'],
          weights: ['250g', '500g', '1kg'],
          isBestSeller: true,
          weightLabel: 'Gói 250g · Xay phin',
        ),
        Product(
          id: 'filter-bag',
          name: 'Túi Lọc Hải Tín Signature',
          description: 'Túi lọc bền bỉ, pha lẫn hương vị cực mượt.',
          category: 'Túi Lọc',
          price: 65000,
          pricesByWeight: {'250g': 65000, '500g': 120000, '1kg': 220000},
          imageUrls: ['https://images.unsplash.com/photo-1497515114629-f71d768fd07c?auto=format&fit=crop&w=900&q=80'],
          badge: 'Hot',
          flavorProfile: {'Đắng': 2, 'Chua': 2, 'Hương': 4},
          grindOptions: ['Nguyên hạt', 'Xay pha phin truyền thống', 'Xay mịn pha máy'],
          weights: ['250g', '500g', '1kg'],
          isBestSeller: false,
          weightLabel: 'Hộp 20 túi',
        ),
        Product(
          id: 'phin',
          name: 'Phin Nhôm Truyền Thống',
          description: 'Thiết kế nhỏ gọn, giữ nhiệt tốt, phù hợp cả gia đình.',
          category: 'Dụng Cụ Pha',
          price: 45000,
          pricesByWeight: {'250g': 45000, '500g': 45000, '1kg': 45000},
          imageUrls: ['https://images.unsplash.com/photo-1517705008128-361805f42e86?auto=format&fit=crop&w=900&q=80'],
          badge: 'Mới',
          flavorProfile: {'Đắng': 2, 'Chua': 1, 'Hương': 3},
          grindOptions: ['Nguyên hạt', 'Xay pha phin truyền thống', 'Xay mịn pha máy'],
          weights: ['250g', '500g', '1kg'],
          isBestSeller: false,
          weightLabel: 'Loại 1 người dùng',
        ),
      ];
}
