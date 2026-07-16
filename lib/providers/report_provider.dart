import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repositories/report_repository.dart';

enum ReportRangePreset { today, sevenDays, thirtyDays, threeMonths, custom }

class ReportProvider extends ChangeNotifier {
  ReportProvider({ReportRepository? repository})
    : _repository = repository ?? const ReportRepository(),
      _range = _presetRange(ReportRangePreset.sevenDays);

  final ReportRepository _repository;
  DateTimeRange _range;
  ReportRangePreset _preset = ReportRangePreset.sevenDays;
  ReportData? _data;
  String? _errorMessage;
  bool _isLoading = false;

  DateTimeRange get range => _range;
  ReportRangePreset get preset => _preset;
  ReportData? get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  String get rangeLabel {
    final date = DateFormat('dd/MM/yyyy', 'vi_VN');
    return '${date.format(_range.start)} - ${date.format(_range.end)}';
  }

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await _repository.fetchReport(_range);
    } catch (error) {
      _errorMessage = _friendlyError(error);
      _data ??= ReportData.empty;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPreset(ReportRangePreset preset) async {
    _preset = preset;
    _range = _presetRange(preset);
    notifyListeners();
    await load();
  }

  Future<void> setCustomRange(DateTimeRange range) async {
    _preset = ReportRangePreset.custom;
    _range = DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(range.end.year, range.end.month, range.end.day),
    );
    notifyListeners();
    await load();
  }

  static DateTimeRange _presetRange(ReportRangePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (preset) {
      ReportRangePreset.today => DateTimeRange(start: today, end: today),
      ReportRangePreset.sevenDays => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      ReportRangePreset.thirtyDays => DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      ),
      ReportRangePreset.threeMonths => DateTimeRange(
        start: DateTime(today.year, today.month - 2, today.day),
        end: today,
      ),
      ReportRangePreset.custom => DateTimeRange(start: today, end: today),
    };
  }

  static String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('Không có quyền') ||
        message.contains('KhÃ´ng cÃ³ quyá»n')) {
      return 'Tài khoản hiện tại không có quyền xem báo cáo admin.';
    }
    if (message.contains('Supabase') || message.contains('.env')) {
      return 'Chưa cấu hình Supabase hoặc kết nối dữ liệu bị gián đoạn.';
    }
    return 'Không tải được báo cáo doanh thu. Vui lòng thử lại.';
  }
}
