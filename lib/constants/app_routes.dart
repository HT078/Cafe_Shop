import 'package:flutter/material.dart';

import '../screens/admin/admin_guard_screen.dart';
import '../screens/customer/account/become_agent_screen.dart';
import '../screens/customer/account/personal_info_screen.dart';
import '../screens/customer/account/shipping_address_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const admin = '/admin';
  static const personalInfo = '/account/personal-info';
  static const shippingAddress = '/account/shipping-address';
  static const wholesaleRegistration = '/account/wholesale-registration';

  static Map<String, WidgetBuilder> get routes {
    return {
      admin: (_) => const AdminGuardScreen(),
      personalInfo: (_) => const PersonalInfoScreen(),
      shippingAddress: (_) => const ShippingAddressScreen(),
      wholesaleRegistration: (_) => const BecomeAgentScreen(),
    };
  }
}
