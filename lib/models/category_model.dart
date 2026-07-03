import 'package:flutter/material.dart';

class CategoryItem {
  const CategoryItem({required this.title, required this.icon, this.id});

  final String? id;
  final String title;
  final IconData icon;

  factory CategoryItem.fromMap(Map<String, dynamic> map) {
    final title = (map['title'] ?? map['name'] ?? '').toString();
    return CategoryItem(
      id: map['id']?.toString(),
      title: title,
      icon: _iconFor(title),
    );
  }

  static IconData _iconFor(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('hạt')) return Icons.grain_outlined;
    if (normalized.contains('túi') || normalized.contains('lọc')) {
      return Icons.filter_alt_outlined;
    }
    if (normalized.contains('dụng') || normalized.contains('pha')) {
      return Icons.local_cafe_outlined;
    }
    return Icons.coffee_outlined;
  }
}
