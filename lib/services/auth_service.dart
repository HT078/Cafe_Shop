import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthService {
  AuthService._();

  static bool _googleReady = false;

  // Đăng nhập bằng email và mật khẩu.
  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    SupabaseService.ensureConfigured();
    final response = await SupabaseService.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await _syncProfileFromMetadata(response.user);
    return response;
  }

  // Đăng ký tài khoản bằng email/password, phone lưu trong profiles/user metadata.
  static Future<AuthResponse> signUp({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    SupabaseService.ensureConfigured();
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final response = await SupabaseService.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'phone': cleanPhone},
    );

    // Nếu Supabase trả session ngay, có thể insert profile bằng RLS user hiện tại.
    // Nếu đang bật confirm email, profile nên được tạo sau khi user xác nhận/login.
    if (response.session != null) {
      await _safeUpsertProfile(
        id: response.user?.id,
        fullName: fullName.trim(),
        phone: cleanPhone,
        email: email.trim(),
      );
    }

    return response;
  }

  // Đăng nhập Google. Web dùng OAuth của Supabase để tránh lỗi popup/idToken.
  static Future<AuthResponse?> signInWithGoogle() async {
    SupabaseService.ensureConfigured();
    final googleClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '';
    debugPrint(
      'AuthService.signInWithGoogle: kIsWeb=$kIsWeb '
      'clientIdConfigured=${googleClientId.isNotEmpty && !googleClientId.contains('PASTE_')}',
    );

    if (kIsWeb) {
      final redirectTo = Uri.base.origin;
      debugPrint(
        'AuthService.signInWithGoogle: Supabase OAuth redirectTo=$redirectTo',
      );

      final opened = await SupabaseService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        queryParams: const {
          'prompt': 'select_account',
        },
      );
      if (!opened) {
        throw const AuthException('Không mở được trang đăng nhập Google');
      }

      // Supabase sẽ redirect khỏi app; Splash xử lý session khi quay lại.
      return null;
    }

    try {
      final googleSignIn = GoogleSignIn.instance;
      if (!_googleReady) {
        await googleSignIn.initialize(
          clientId: kIsWeb ? googleClientId : null,
          serverClientId:
              kIsWeb ||
                  googleClientId.isEmpty ||
                  googleClientId.contains('PASTE_')
              ? null
              : googleClientId,
        );
        _googleReady = true;
      }

      final googleUser = await googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      debugPrint(
        'AuthService.signInWithGoogle: google user=${googleUser.email} '
        'hasIdToken=${idToken != null}',
      );
      if (idToken == null) {
        throw const AuthException('Không lấy được Google ID Token');
      }

      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      await _safeUpsertProfile(
        id: response.user?.id,
        fullName: googleUser.displayName ?? googleUser.email,
        phone: '',
        email: googleUser.email,
      );

      return response;
    } on GoogleSignInException catch (error) {
      debugPrint(
        'AuthService.signInWithGoogle GoogleSignInException: '
        'code=${error.code} description=${error.description} details=${error.details}',
      );
      throw AuthException(_friendlyGoogleError(error));
    } on AuthException catch (error) {
      debugPrint('AuthService.signInWithGoogle AuthException: ${error.message}');
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('AuthService.signInWithGoogle failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw AuthException('Không đăng nhập được Google: $error');
    }
  }

  // Đăng xuất khỏi Supabase và Google.
  static Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
    if (_googleReady) {
      await GoogleSignIn.instance.signOut();
    }
  }

  // Đồng bộ profile sau OAuth redirect, nhất là đăng nhập Google trên web.
  static Future<void> syncCurrentUserProfile() async {
    await _syncProfileFromMetadata(SupabaseService.currentUser);
  }

  static String _friendlyGoogleError(GoogleSignInException error) {
    final description = error.description ?? error.code.name;
    final lower = description.toLowerCase();
    if (lower.contains('client') ||
        lower.contains('origin') ||
        lower.contains('oauth')) {
      return 'Google login chưa cấu hình đúng OAuth Client ID hoặc Authorized JavaScript origin.';
    }
    if (error.code == GoogleSignInExceptionCode.canceled) {
      return 'Bạn đã hủy đăng nhập Google.';
    }
    return 'Không đăng nhập được Google: $description';
  }

  static Future<void> _syncProfileFromMetadata(User? user) async {
    if (user == null) return;
    final metadata = user.userMetadata ?? {};
    await _safeUpsertProfile(
      id: user.id,
      fullName: (metadata['full_name'] ?? user.email ?? '').toString(),
      phone: (metadata['phone'] ?? '').toString(),
      email: user.email,
    );
  }

  static Future<void> _safeUpsertProfile({
    required String? id,
    required String fullName,
    required String phone,
    String? email,
  }) async {
    if (id == null) return;
    try {
      await SupabaseService.upsertProfile(
        id: id,
        fullName: fullName,
        phone: phone,
        email: email,
      );
      debugPrint(
        'AuthService._safeUpsertProfile: upsert OK id=$id email=$email',
      );
    } on PostgrestException catch (error) {
      debugPrint(
        'AuthService._safeUpsertProfile blocked: id=$id email=$email '
        'code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}',
      );
      // RLS có thể chặn khi email confirmation chưa tạo session; không làm hỏng đăng ký.
    }
  }
}
