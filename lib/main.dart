import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants/app_routes.dart';
import 'providers/account_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'providers/report_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'services/supabase_service.dart';
import 'theme/theme.dart';

Future<void> main() async {
  print('BOOT main:start');
  WidgetsFlutterBinding.ensureInitialized();
  print('BOOT binding:ready');
  try {
    await initializeDateFormatting('vi_VN').timeout(const Duration(seconds: 5));
    print('BOOT intl:ready');
  } catch (error, stackTrace) {
    print('BOOT intl:error $error');
    debugPrint('Khong khoi tao duoc dinh dang ngay vi_VN: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await dotenv.load(fileName: '.env').timeout(const Duration(seconds: 5));
    print('BOOT dotenv:ready');
  } catch (error, stackTrace) {
    print('BOOT dotenv:error $error');
    debugPrint('Khong tai duoc file .env: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (SupabaseService.isConfigured) {
    try {
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      ).timeout(const Duration(seconds: 8));
      print('BOOT supabase:ready');
    } catch (error, stackTrace) {
      print('BOOT supabase:error $error');
      debugPrint('Khong khoi tao duoc Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  } else {
    print('BOOT supabase:not-configured');
    debugPrint(
      'Supabase chua duoc cau hinh. Ung dung se chay voi du lieu local/mock.',
    );
  }

  print('BOOT runApp:before');
  runApp(const HaiTinApp());
  print('BOOT runApp:after');
}

class HaiTinApp extends StatelessWidget {
  const HaiTinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()..load()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => BannerProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
      ],
      child: MaterialApp(
        title: 'Cà Phê Hải Tín',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.appTheme,
        home: const SplashScreen(),
        routes: AppRoutes.routes,
      ),
    );
  }
}
