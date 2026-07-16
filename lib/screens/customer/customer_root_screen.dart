import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/customer/chat_floating_button.dart';
import 'account/profile_screen.dart';
import 'cart/cart_screen.dart';
import 'catalog/category_screen.dart';
import 'home/home_screen.dart';

class CustomerRootScreen extends StatefulWidget {
  const CustomerRootScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CustomerRootScreen> createState() => _CustomerRootScreenState();
}

class _CustomerRootScreenState extends State<CustomerRootScreen> {
  late int _currentIndex;
  String? _selectedCategoryTitle;
  int _categorySelectionVersion = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CartProvider>().syncWithCurrentUser();
    });
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 2) {
      unawaited(context.read<CartProvider>().reloadFromSupabase());
    }
  }

  void _selectCategory(String title) {
    setState(() {
      _selectedCategoryTitle = title;
      _categorySelectionVersion += 1;
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onTabSelected: _selectTab,
            onCategorySelected: _selectCategory,
          ),
          CategoryScreen(
            key: ValueKey(_categorySelectionVersion),
            initialCategoryTitle: _selectedCategoryTitle,
            onCartTap: () => _selectTab(2),
          ),
          CartScreen(onExploreProducts: () => _selectTab(0)),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: const ChatFloatingButton(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A0E0A),
          border: Border(top: BorderSide(color: AppTheme.lineColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _selectTab,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Danh mục',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              label: 'Giỏ hàng',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}
