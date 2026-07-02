import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  String _role = 'customer';
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get profile => _profile;
  String get role => _role;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isAdmin => _role.trim().toLowerCase() == 'admin';
  bool get isAgent =>
      _profile?['is_agent'] == true || _profile?['agent_status'] == 'approved';
  String? get agentStatus => _profile?['agent_status']?.toString();
  String? get rejectReason => _profile?['reject_reason']?.toString();
  String get fullName => (_profile?['full_name'] ?? '').toString();
  String get phone => (_profile?['phone'] ?? '').toString();
  String get email => (SupabaseService.currentUser?.email ?? '').toString();

  Future<void> refreshCurrentUser() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        _profile = null;
        _role = 'customer';
        return;
      }

      _profile = await SupabaseService.fetchProfile();
      final rawProfileRole = _profile?['role']?.toString();
      _role = await SupabaseService.fetchCurrentRole();
      debugPrint(
        'AuthProvider.refreshCurrentUser: '
        'user=${user.id} email=${user.email} '
        'profileRole="$rawProfileRole" providerRole="$_role" '
        'isAdmin=$isAdmin profile=$_profile',
      );
    } catch (error) {
      debugPrint('AuthProvider.refreshCurrentUser failed: $error');
      _error = error.toString();
      _profile = null;
      _role = 'customer';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _profile = null;
    _role = 'customer';
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
