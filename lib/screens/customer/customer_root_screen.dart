import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/customer/chat_floating_button.dart';
import 'cart_screen.dart';
import 'category_screen.dart';
import 'home/home_screen.dart';
import 'profile_screen.dart';

class CustomerRootScreen extends StatefulWidget {
  const CustomerRootScreen({super.key});

  @override
  State<CustomerRootScreen> createState() => _CustomerRootScreenState();
}

class _CustomerRootScreenState extends State<CustomerRootScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CartProvider>().syncWithCurrentUser();
    });
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onTabSelected: _selectTab),
          CategoryScreen(onCartTap: () => _selectTab(2)),
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
