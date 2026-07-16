import '../../models/voucher_model.dart';
import '../../services/admin_service.dart';
import '../../services/supabase_service.dart';

class VoucherAdminRepository {
  Future<List<Voucher>> getAllVouchers() async {
    await AdminService.requireAdmin();
    final rows = await SupabaseService.client
        .from('coupons')
        .select()
        .order('created_at', ascending: false);
    return rows
        .map<Voucher>((row) => Voucher.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> addVoucher(Voucher voucher) async {
    await AdminService.requireAdmin();
    await SupabaseService.client.from('coupons').insert(voucher.toJson());
  }

  Future<void> updateVoucher(String id, Voucher voucher) async {
    await AdminService.requireAdmin();
    await SupabaseService.client
        .from('coupons')
        .update(voucher.toJson(includeCode: false))
        .eq('id', id);
  }

  Future<void> toggleVoucher(String id, bool isActive) async {
    await AdminService.requireAdmin();
    await SupabaseService.client
        .from('coupons')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  Future<void> deleteVoucher(String id) async {
    await AdminService.requireAdmin();
    await SupabaseService.client.from('coupons').delete().eq('id', id);
  }

  Future<void> resetUsedCount(String id) async {
    await AdminService.requireAdmin();
    await SupabaseService.client
        .from('coupons')
        .update({'used_count': 0})
        .eq('id', id);
  }
}
