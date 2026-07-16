import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/banner_model.dart';
import '../../../services/admin_service.dart';
import '../../../theme/theme.dart';
import '../../../utils/product_image_picker.dart';

abstract final class _BannerColors {
  static const page = Color(0xFFF7F4EF);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2D1B13);
  static const muted = Color(0xFF74665E);
  static const line = Color(0xFFE4DAD2);
  static const softGold = Color(0xFFFFF0D1);
  static const softGreen = Color(0xFFE4F3EB);
  static const green = Color(0xFF26745B);
  static const softCoral = Color(0xFFFFE8E1);
  static const coral = Color(0xFFC8523B);
}

ThemeData _bannerLightTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppTheme.goldColor,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppTheme.goldColor,
        secondary: _BannerColors.green,
        surface: _BannerColors.card,
        onSurface: _BannerColors.ink,
        outline: _BannerColors.line,
        error: _BannerColors.coral,
      );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: _BannerColors.page,
    textTheme: base.textTheme.apply(
      bodyColor: _BannerColors.ink,
      displayColor: _BannerColors.ink,
    ),
    cardTheme: CardThemeData(
      color: _BannerColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _BannerColors.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _BannerColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFBF9F6),
      labelStyle: const TextStyle(color: _BannerColors.muted),
      hintStyle: const TextStyle(color: _BannerColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _BannerColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.goldColor, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.goldColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _BannerColors.ink,
        side: const BorderSide(color: _BannerColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppTheme.goldColor),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppTheme.goldColor,
      foregroundColor: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : _BannerColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? _BannerColors.green
            : _BannerColors.line,
      ),
    ),
  );
}

class BannerManageScreen extends StatefulWidget {
  const BannerManageScreen({super.key});

  @override
  State<BannerManageScreen> createState() => _BannerManageScreenState();
}

class _BannerManageScreenState extends State<BannerManageScreen> {
  late Future<List<BannerItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BannerItem>> _load() async {
    final rows = await AdminService.fetchBanners();
    return rows.map((row) => BannerItem.fromMap(row)).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Color _statusColor(BannerItem banner) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (!banner.isActive) return _BannerColors.coral;
    if (banner.startAt != null &&
        DateUtils.dateOnly(banner.startAt!).isAfter(today)) {
      return AppTheme.goldColor;
    }
    if (banner.endAt != null &&
        DateUtils.dateOnly(banner.endAt!).isBefore(today)) {
      return Colors.orangeAccent;
    }
    return _BannerColors.green;
  }

  Future<void> _toggleActive(BannerItem banner, bool value) async {
    try {
      await AdminService.toggleBannerActive(banner.id, value);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cập nhật được banner: $error')),
      );
    }
  }

  Future<void> _openForm({BannerItem? banner}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Theme(
        data: _bannerLightTheme(),
        child: _BannerFormDialog(banner: banner, onSaved: _refresh),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _bannerLightTheme(),
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text(
            'Thêm banner',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: FutureBuilder<List<BannerItem>>(
          future: _future,
          builder: (context, snapshot) {
            final banners = snapshot.data ?? const <BannerItem>[];
            return Column(
              children: [
                _BannerPageHeader(
                  total: banners.length,
                  active: banners.where((banner) => banner.isVisibleNow).length,
                  onRefresh: _refresh,
                ),
                Expanded(child: _buildContent(context, snapshot, banners)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AsyncSnapshot<List<BannerItem>> snapshot,
    List<BannerItem> banners,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.goldColor),
      );
    }

    if (snapshot.hasError) {
      return _BannerMessageState(
        icon: Icons.cloud_off_outlined,
        title: 'Không tải được danh sách banner',
        message: snapshot.error.toString(),
        actionLabel: 'Thử lại',
        onAction: _refresh,
      );
    }

    if (banners.isEmpty) {
      return _BannerMessageState(
        icon: Icons.photo_library_outlined,
        title: 'Chưa có banner',
        message: 'Tạo banner đầu tiên để hiển thị trên trang chủ.',
        actionLabel: 'Thêm banner',
        onAction: () => _openForm(),
      );
    }

    return RefreshIndicator(
      color: AppTheme.goldColor,
      onRefresh: _refresh,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
            itemCount: banners.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final banner = banners[index];
              return _BannerListItem(
                banner: banner,
                statusColor: _statusColor(banner),
                onToggle: (value) => _toggleActive(banner, value),
                onEdit: () => _openForm(banner: banner),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BannerPageHeader extends StatelessWidget {
  const _BannerPageHeader({
    required this.total,
    required this.active,
    required this.onRefresh,
  });

  final int total;
  final int active;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _BannerColors.card,
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _BannerColors.softGold,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.campaign_outlined,
              color: AppTheme.goldColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Banner quảng cáo',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '$active đang chạy · $total tổng cộng',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _BannerColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: onRefresh,
            color: _BannerColors.ink,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _BannerListItem extends StatelessWidget {
  const _BannerListItem({
    required this.banner,
    required this.statusColor,
    required this.onToggle,
    required this.onEdit,
  });

  final BannerItem banner;
  final Color statusColor;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final details = _BannerDetails(
                banner: banner,
                statusColor: statusColor,
              );

              if (compact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        _BannerThumb(
                          imageUrl: banner.imageUrl,
                          width: 96,
                          height: 64,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: details),
                        IconButton(
                          tooltip: 'Chỉnh sửa',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusChip(
                          label: banner.statusLabel,
                          color: statusColor,
                        ),
                        const Spacer(),
                        Text(
                          banner.isActive ? 'Đang bật' : 'Đã tắt',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Switch(value: banner.isActive, onChanged: onToggle),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  _BannerThumb(
                    imageUrl: banner.imageUrl,
                    width: 124,
                    height: 76,
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: details),
                  _StatusChip(label: banner.statusLabel, color: statusColor),
                  const SizedBox(width: 16),
                  Switch(value: banner.isActive, onChanged: onToggle),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Chỉnh sửa',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BannerDetails extends StatelessWidget {
  const _BannerDetails({required this.banner, required this.statusColor});

  final BannerItem banner;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (banner.tag.isNotEmpty) banner.tag,
      'Vị trí ${banner.sortOrder}',
      if (banner.linkType != 'none') 'Có liên kết',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          banner.title.isEmpty ? 'Banner chưa đặt tên' : banner.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (banner.subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            banner.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: _BannerColors.muted),
          ),
        ],
        const SizedBox(height: 7),
        Text(
          metadata.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BannerMessageState extends StatelessWidget {
  const _BannerMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: AppTheme.goldColor),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _BannerColors.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BannerThumb extends StatelessWidget {
  const _BannerThumb({
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  final String imageUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return _BannerThumbFallback(
        icon: Icons.image_outlined,
        width: width,
        height: height,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => SizedBox(
          width: width,
          height: height,
          child: Center(
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _BannerThumbFallback(
          icon: Icons.broken_image_outlined,
          width: width,
          height: height,
        ),
      ),
    );
  }
}

class _BannerThumbFallback extends StatelessWidget {
  const _BannerThumbFallback({
    required this.icon,
    required this.width,
    required this.height,
  });

  final IconData icon;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _BannerColors.softGold,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: AppTheme.goldColor),
    );
  }
}

class _BannerFormDialog extends StatefulWidget {
  const _BannerFormDialog({required this.banner, required this.onSaved});

  final BannerItem? banner;
  final Future<void> Function() onSaved;

  @override
  State<_BannerFormDialog> createState() => _BannerFormDialogState();
}

class _BannerFormDialogState extends State<_BannerFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _tagController;
  late final TextEditingController _linkValueController;
  late final TextEditingController _sortOrderController;
  late String _linkType;
  late bool _isActive;
  DateTime? _startAt;
  DateTime? _endAt;
  Uint8List? _pickedImage;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _imageUploadError;

  @override
  void initState() {
    super.initState();
    final banner = widget.banner;
    _titleController = TextEditingController(text: banner?.title ?? '');
    _subtitleController = TextEditingController(text: banner?.subtitle ?? '');
    _imageUrlController = TextEditingController(text: banner?.imageUrl ?? '');
    _tagController = TextEditingController(text: banner?.tag ?? '');
    _linkValueController = TextEditingController(text: banner?.linkValue ?? '');
    _sortOrderController = TextEditingController(
      text: (banner?.sortOrder ?? 0).toString(),
    );
    _linkType = banner?.linkType.isNotEmpty == true ? banner!.linkType : 'none';
    _isActive = banner?.isActive ?? true;
    _startAt = banner?.startAt;
    _endAt = banner?.endAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _imageUrlController.dispose();
    _tagController.dispose();
    _linkValueController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_saving || _uploadingImage) return;

    setState(() {
      _uploadingImage = true;
      _imageUploadError = null;
    });
    try {
      final picked = await pickProductImage();
      if (!mounted || picked == null) return;

      setState(() => _pickedImage = picked.bytes);
      final imageUrl = await AdminService.uploadBannerImage(
        bytes: picked.bytes,
        fileName: picked.fileName,
      );
      if (!mounted) return;

      setState(() {
        _imageUrlController.text = imageUrl;
        _imageUploadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _imageUploadError = _friendlyUploadError(error));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  String _friendlyUploadError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final lower = message.toLowerCase();
    if (lower.contains('bucket not found') || lower.contains('404')) {
      return 'Bucket banners chưa được tạo. Hãy chạy file banner_storage_and_schema.sql trên Supabase.';
    }
    if (lower.contains('row-level security') ||
        lower.contains('unauthorized') ||
        lower.contains('403') ||
        lower.contains('42501')) {
      return 'Tài khoản chưa có quyền upload vào bucket banners. Hãy chạy lại policy banner.';
    }
    return 'Không tải được ảnh banner: $message';
  }

  Future<void> _pickDate(bool isStart) async {
    final current = isStart ? _startAt : _endAt;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: current ?? DateTime.now(),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startAt = picked;
      } else {
        _endAt = picked;
      }
    });
  }

  String _linkLabel() {
    return switch (_linkType) {
      'product' => 'ID sản phẩm',
      'category' => 'Tên danh mục',
      'url' => 'Link ngoài',
      _ => 'Không dùng',
    };
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiêu đề banner là bắt buộc')),
      );
      return;
    }

    if (_imageUrlController.text.trim().isEmpty) {
      setState(() => _imageUploadError = 'Vui lòng chọn và tải ảnh banner.');
      return;
    }

    if (_startAt != null && _endAt != null && _endAt!.isBefore(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ngày kết thúc phải sau ngày bắt đầu')),
      );
      return;
    }

    if (_linkType != 'none' && _linkValueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung liên kết')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'title': title,
        'subtitle': _subtitleController.text.trim(),
        'image_url': _imageUrlController.text.trim(),
        'tag': _tagController.text.trim(),
        'link_type': _linkType,
        'link_value': _linkValueController.text.trim(),
        'is_active': _isActive,
        'sort_order': int.tryParse(_sortOrderController.text.trim()) ?? 0,
        'start_at': _startAt?.toIso8601String(),
        'end_at': _endAt?.toIso8601String(),
      };

      await AdminService.saveBanner(payload, id: widget.banner?.id);
      if (!mounted) return;

      Navigator.of(context).pop();
      await widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(20),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 16, 14),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _BannerColors.softGold,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.photo_library_outlined,
              color: AppTheme.goldColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.banner == null ? 'Thêm banner' : 'Chỉnh sửa banner',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BannerImageUpload(
                pickedImage: _pickedImage,
                imageUrl: _imageUrlController.text.trim(),
                isUploading: _uploadingImage,
                errorText: _imageUploadError,
                onPick: _pickImage,
              ),
              const SizedBox(height: 18),
              _field('Tiêu đề', controller: _titleController),
              _field('Phụ đề', controller: _subtitleController, maxLines: 2),
              Row(
                children: [
                  Expanded(child: _field('Tag', controller: _tagController)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: _field(
                      'Vị trí',
                      controller: _sortOrderController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                initialValue: _linkType,
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('Không liên kết'),
                  ),
                  DropdownMenuItem(value: 'product', child: Text('Sản phẩm')),
                  DropdownMenuItem(value: 'category', child: Text('Danh mục')),
                  DropdownMenuItem(value: 'url', child: Text('Link ngoài')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _linkType = value);
                },
                decoration: const InputDecoration(labelText: 'Loại liên kết'),
              ),
              const SizedBox(height: 10),
              if (_linkType != 'none')
                _field(_linkLabel(), controller: _linkValueController),
              Row(
                children: [
                  Expanded(
                    child: _BannerDateButton(
                      label: 'Bắt đầu',
                      value: _startAt,
                      onPressed: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BannerDateButton(
                      label: 'Kết thúc',
                      value: _endAt,
                      onPressed: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: _isActive
                      ? _BannerColors.softGreen
                      : _BannerColors.softCoral,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: Text(
                    _isActive ? 'Banner đang bật' : 'Banner đang tắt',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  secondary: Icon(
                    _isActive
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _isActive
                        ? _BannerColors.green
                        : _BannerColors.coral,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton.icon(
          onPressed: _saving || _uploadingImage ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Đang lưu...' : 'Lưu banner'),
        ),
      ],
    );
  }

  Widget _field(
    String label, {
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _BannerImageUpload extends StatelessWidget {
  const _BannerImageUpload({
    required this.pickedImage,
    required this.imageUrl,
    required this.isUploading,
    required this.errorText,
    required this.onPick,
  });

  final Uint8List? pickedImage;
  final String imageUrl;
  final bool isUploading;
  final String? errorText;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasImage = pickedImage != null || imageUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _BannerColors.softGold,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: errorText == null
                  ? _BannerColors.line
                  : _BannerColors.coral,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pickedImage != null)
                Image.memory(pickedImage!, fit: BoxFit.cover)
              else if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: AppTheme.goldColor),
                  ),
                  errorWidget: (context, url, error) => const _ImagePlaceholder(
                    icon: Icons.broken_image_outlined,
                    label: 'Ảnh không còn khả dụng',
                  ),
                )
              else
                const _ImagePlaceholder(
                  icon: Icons.add_photo_alternate_outlined,
                  label: 'Chưa chọn ảnh banner',
                ),
              if (hasImage)
                const Positioned(top: 12, left: 12, child: _ImageReadyBadge()),
              Positioned(
                right: 12,
                bottom: 12,
                child: FilledButton.icon(
                  onPressed: isUploading ? null : onPick,
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(
                    isUploading
                        ? 'Đang tải...'
                        : hasImage
                        ? 'Đổi ảnh'
                        : 'Chọn ảnh',
                  ),
                ),
              ),
              if (isUploading)
                ColoredBox(color: Colors.white.withValues(alpha: 0.18)),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 7),
          Text(
            errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _BannerColors.coral,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppTheme.goldColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _BannerColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageReadyBadge extends StatelessWidget {
  const _ImageReadyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _BannerColors.green,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 15, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Đã có ảnh',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerDateButton extends StatelessWidget {
  const _BannerDateButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(66),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined, color: AppTheme.goldColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _BannerColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value == null
                      ? 'Chưa chọn'
                      : DateFormat('dd/MM/yyyy').format(value!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
