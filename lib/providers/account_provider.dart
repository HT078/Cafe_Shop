import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/address_item_model.dart';
import '../services/supabase_service.dart';

class AccountProfile {
  const AccountProfile({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.dateOfBirth,
    required this.gender,
    required this.isWholesaleCustomer,
    required this.wholesaleStatus,
    required this.rejectReason,
    required this.businessName,
    required this.businessAddress,
    required this.businessPhone,
    required this.expectedVolume,
    required this.wholesaleNote,
  });

  final String fullName;
  final String phone;
  final String email;
  final DateTime? dateOfBirth;
  final String? gender;
  final bool isWholesaleCustomer;
  final String? wholesaleStatus;
  final String? rejectReason;
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final String expectedVolume;
  final String wholesaleNote;

  static const empty = AccountProfile(
    fullName: '',
    phone: '',
    email: '',
    dateOfBirth: null,
    gender: null,
    isWholesaleCustomer: false,
    wholesaleStatus: null,
    rejectReason: null,
    businessName: '',
    businessAddress: '',
    businessPhone: '',
    expectedVolume: '5-20kg',
    wholesaleNote: '',
  );

  factory AccountProfile.fromSupabase(
    Map<String, dynamic>? profile, {
    required String email,
  }) {
    final normalizedStatus = _normalizeWholesaleStatus(
      profile?['agent_status'],
    );
    final gender = profile?['gender']?.toString().trim();
    final rejectReason = normalizedStatus == 'rejected'
        ? _nonEmptyString(profile?['reject_reason'])
        : null;

    return AccountProfile(
      fullName: (profile?['full_name'] ?? '').toString(),
      phone: (profile?['phone'] ?? '').toString(),
      email: (profile?['email'] ?? email).toString(),
      dateOfBirth: DateTime.tryParse(
        (profile?['date_of_birth'] ?? '').toString(),
      ),
      gender: gender == null || gender.isEmpty ? null : gender,
      isWholesaleCustomer:
          profile?['is_agent'] == true || normalizedStatus == 'approved',
      wholesaleStatus: normalizedStatus,
      rejectReason: rejectReason,
      businessName: (profile?['business_name'] ?? '').toString(),
      businessAddress: (profile?['business_address'] ?? '').toString(),
      businessPhone: (profile?['business_phone'] ?? profile?['phone'] ?? '')
          .toString(),
      expectedVolume: (profile?['expected_volume'] ?? '5-20kg').toString(),
      wholesaleNote: (profile?['agent_note'] ?? '').toString(),
    );
  }

  static String? _normalizeWholesaleStatus(dynamic value) {
    final status = value?.toString().trim().toLowerCase();
    return switch (status) {
      'pending' || 'approved' || 'rejected' => status,
      _ => null,
    };
  }

  static String? _nonEmptyString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  AccountProfile copyWith({
    String? fullName,
    String? phone,
    String? email,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? gender,
    bool clearGender = false,
    bool? isWholesaleCustomer,
    String? wholesaleStatus,
    bool clearWholesaleStatus = false,
    String? rejectReason,
    bool clearRejectReason = false,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? expectedVolume,
    String? wholesaleNote,
  }) {
    return AccountProfile(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
      gender: clearGender ? null : gender ?? this.gender,
      isWholesaleCustomer: isWholesaleCustomer ?? this.isWholesaleCustomer,
      wholesaleStatus: clearWholesaleStatus
          ? null
          : wholesaleStatus ?? this.wholesaleStatus,
      rejectReason: clearRejectReason
          ? null
          : rejectReason ?? this.rejectReason,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      businessPhone: businessPhone ?? this.businessPhone,
      expectedVolume: expectedVolume ?? this.expectedVolume,
      wholesaleNote: wholesaleNote ?? this.wholesaleNote,
    );
  }
}

class AccountProvider extends ChangeNotifier {
  AccountProfile _profile = AccountProfile.empty;
  List<AddressItem> _addresses = _mockAddresses();
  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;
  String? _error;
  String? _loadedUserId;

  AccountProfile get profile => _profile;
  List<AddressItem> get addresses => List.unmodifiable(_addresses);
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    final currentUserId = SupabaseService.currentUser?.id;
    final userChanged = _loadedUserId != currentUserId;
    if (_loading || (_loaded && !force && !userChanged)) return;

    _loading = true;
    _error = null;
    _notifySafely();

    try {
      final user = SupabaseService.currentUser;
      _loadedUserId = user?.id;
      if (user == null) {
        _profile = AccountProfile.empty;
        _addresses = _mockAddresses();
        _loaded = true;
        return;
      }

      final profile = await SupabaseService.fetchProfile();
      _profile = AccountProfile.fromSupabase(profile, email: user.email ?? '');
      if (userChanged || !_loaded) {
        _addresses = [];
      }

      try {
        final remoteAddresses = await SupabaseService.fetchAddresses();
        _addresses = _normalizeRemoteAddresses(remoteAddresses);
      } catch (error, stackTrace) {
        debugPrint('AccountProvider.load addresses fallback: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      _loaded = true;
    } catch (error, stackTrace) {
      _error = error.toString();
      debugPrint('AccountProvider.load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _loaded = true;
    } finally {
      _loading = false;
      _notifySafely();
    }
  }

  Future<void> updatePersonalInfo({
    required String fullName,
    required String phone,
    required String email,
    required DateTime? dateOfBirth,
    required String? gender,
  }) async {
    final updated = _profile.copyWith(
      fullName: fullName,
      phone: phone,
      email: email,
      dateOfBirth: dateOfBirth,
      clearDateOfBirth: dateOfBirth == null,
      gender: gender,
      clearGender: gender == null,
    );

    final user = SupabaseService.currentUser;
    if (user != null) {
      try {
        await SupabaseService.updateProfileById(user.id, {
          'full_name': fullName,
          'phone': phone,
          'email': email,
          'date_of_birth': dateOfBirth?.toIso8601String(),
          'gender': gender,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (error, stackTrace) {
        debugPrint('AccountProvider.updatePersonalInfo remote failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _profile = updated;
    _notifySafely();
  }

  Future<void> submitWholesaleRegistration({
    required String businessName,
    required String businessAddress,
    required String businessPhone,
    required String expectedVolume,
    required String note,
  }) async {
    final updated = _profile.copyWith(
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      expectedVolume: expectedVolume,
      wholesaleNote: note,
      wholesaleStatus: 'pending',
      clearRejectReason: true,
      isWholesaleCustomer: false,
    );

    final user = SupabaseService.currentUser;
    if (user != null) {
      try {
        await SupabaseService.updateProfileById(user.id, {
          'business_name': businessName,
          'business_address': businessAddress,
          'business_phone': businessPhone,
          'expected_volume': expectedVolume,
          'agent_note': note,
          'agent_status': 'pending',
          'is_agent': false,
          'reject_reason': null,
          'agent_requested_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (error, stackTrace) {
        debugPrint(
          'AccountProvider.submitWholesaleRegistration remote failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _profile = updated;
    _notifySafely();
  }

  Future<void> resetWholesaleRegistration() async {
    final updated = _profile.copyWith(
      clearWholesaleStatus: true,
      clearRejectReason: true,
      isWholesaleCustomer: false,
    );

    final user = SupabaseService.currentUser;
    if (user != null) {
      try {
        await SupabaseService.updateProfileById(user.id, {
          'agent_status': null,
          'is_agent': false,
          'reject_reason': null,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (error, stackTrace) {
        debugPrint(
          'AccountProvider.resetWholesaleRegistration remote failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _profile = updated;
    _notifySafely();
  }

  Future<void> saveAddress(AddressItem address) async {
    final user = SupabaseService.currentUser;
    final userId = SupabaseService.currentUser?.id ?? 'local-user';
    final normalized = address.copyWith(
      // Giữ id rỗng khi tạo mới để SupabaseService thực hiện INSERT.
      // Chỉ dùng id hiện có khi đang sửa địa chỉ đã lưu.
      id: address.id,
      userId: address.userId.isEmpty ? userId : address.userId,
      createdAt: address.createdAt ?? DateTime.now(),
    );

    if (user != null) {
      await SupabaseService.saveAddress(normalized);
      final remoteAddresses = await SupabaseService.fetchAddresses();
      _addresses = _normalizeRemoteAddresses(remoteAddresses);
      _notifySafely();
      return;
    }

    final next = [..._addresses];
    final existingIndex = next.indexWhere((item) => item.id == normalized.id);
    if (existingIndex >= 0) {
      next[existingIndex] = normalized;
    } else {
      next.add(normalized);
    }

    _addresses = _normalizeDefault(next, preferredDefaultId: normalized.id);
    _notifySafely();
  }

  Future<void> deleteAddress(String id) async {
    final user = SupabaseService.currentUser;
    if (user != null) {
      await SupabaseService.deleteAddress(id);
      final remoteAddresses = await SupabaseService.fetchAddresses();
      _addresses = _normalizeRemoteAddresses(remoteAddresses);
      _notifySafely();
      return;
    }

    _addresses = _normalizeDefault(
      _addresses.where((address) => address.id != id).toList(),
    );
    _notifySafely();
  }

  Future<void> setDefaultAddress(String id) async {
    final user = SupabaseService.currentUser;
    if (user != null) {
      await SupabaseService.setDefaultAddress(id);
      final remoteAddresses = await SupabaseService.fetchAddresses();
      _addresses = _normalizeRemoteAddresses(remoteAddresses);
      _notifySafely();
      return;
    }

    _addresses = _addresses
        .map((address) => address.copyWith(isDefault: address.id == id))
        .toList();
    _notifySafely();
  }

  static List<AddressItem> _normalizeRemoteAddresses(
    List<AddressItem> addresses,
  ) {
    if (addresses.isEmpty) {
      return <AddressItem>[];
    }
    return _normalizeDefault(addresses);
  }

  void _notifySafely() {
    if (_disposed) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static List<AddressItem> _normalizeDefault(
    List<AddressItem> addresses, {
    String? preferredDefaultId,
  }) {
    if (addresses.isEmpty) return addresses;

    AddressItem? preferred;
    if (preferredDefaultId != null) {
      for (final address in addresses) {
        if (address.id == preferredDefaultId) {
          preferred = address;
          break;
        }
      }
    }

    final defaultAddress = preferred?.isDefault == true
        ? preferred!
        : addresses.firstWhere(
            (item) => item.isDefault,
            orElse: () => preferred ?? addresses.first,
          );

    return addresses
        .map(
          (address) =>
              address.copyWith(isDefault: address.id == defaultAddress.id),
        )
        .toList();
  }

  static List<AddressItem> _mockAddresses() {
    final now = DateTime.now();
    return [
      AddressItem(
        id: 'mock-home',
        userId: 'local-user',
        fullName: 'Nguyễn Hoàng Tín',
        phone: '0901234567',
        province: 'TP. Hồ Chí Minh',
        district: 'Quận 7',
        ward: 'Phường Tân Phong',
        detailAddress: '12 Nguyễn Lương Bằng',
        isDefault: true,
        createdAt: now,
      ),
      AddressItem(
        id: 'mock-shop',
        userId: 'local-user',
        fullName: 'Cửa hàng Hải Tín',
        phone: '0912345678',
        province: 'TP. Hồ Chí Minh',
        district: 'Thành phố Thủ Đức',
        ward: 'Phường Hiệp Phú',
        detailAddress: '45 Lê Văn Việt',
        isDefault: false,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
