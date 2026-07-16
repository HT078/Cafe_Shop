import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/providers/account_provider.dart';
import 'package:flutter_application_1/providers/auth_provider.dart';
import 'package:flutter_application_1/screens/customer/account/become_agent_screen.dart';
import 'package:flutter_application_1/screens/customer/account/personal_info_screen.dart';
import 'package:flutter_application_1/screens/customer/account/shipping_address_screen.dart';
import 'package:flutter_application_1/theme/theme.dart';

Widget _wrapWithProviders(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => AccountProvider()),
    ],
    child: MaterialApp(theme: AppTheme.darkTheme, home: child),
  );
}

void main() {
  testWidgets('personal info screen renders form fields', (tester) async {
    await tester.pumpWidget(_wrapWithProviders(const PersonalInfoScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lưu thay đổi'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
  });

  testWidgets('shipping address screen shows mock addresses', (tester) async {
    await tester.pumpWidget(_wrapWithProviders(const ShippingAddressScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Địa chỉ giao hàng'), findsOneWidget);
    expect(find.text('Thêm địa chỉ mới'), findsOneWidget);
    expect(find.text('Mặc định'), findsOneWidget);
  });

  testWidgets('wholesale registration screen shows registration form', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithProviders(const BecomeAgentScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký làm Khách Sỉ'), findsOneWidget);
    expect(find.text('Gửi đăng ký'), findsOneWidget);
    expect(find.text('Tên cửa hàng / đại lý'), findsOneWidget);
  });
}
