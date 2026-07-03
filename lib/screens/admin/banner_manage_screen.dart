import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/banner_model.dart';
import '../../services/admin_service.dart';
import '../../theme/theme.dart';

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
    return switch (banner.statusLabel) {
      'Đang chạy' => Colors.greenAccent,
      'Đã hết hạn' => Colors.orangeAccent,
      'Đã tắt' => AppTheme.blazeColor,
      _ => AppTheme.goldColor,
    };
  }

  Future<void> _toggleActive(BannerItem banner, bool value) async {
    await AdminService.toggleBannerActive(banner.id, value);
    await _refresh();
  }

  Future<void> _openForm({BannerItem? banner}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BannerFormDialog(
        banner: banner,
        onSaved: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm banner'),
        backgroundColor: AppTheme.goldColor,
      ),
      body: FutureBuilder<List<BannerItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.goldColor),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          final banners = snapshot.data ?? const [];
          if (banners.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.goldColor,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Chưa có banner nào',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.mutedColor,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.goldColor,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: banners.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final banner = banners[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: banner.imageUrl.isEmpty
                            ? Container(
                                color: AppTheme.surfaceAltColor,
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: AppTheme.goldColor,
                                ),
                              )
                            : Image.network(
                                banner.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppTheme.surfaceAltColor,
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: AppTheme.goldColor,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    title: Text(
                      banner.title.isEmpty ? 'Banner' : banner.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        banner.tag.isNotEmpty ? banner.tag : '',
                        banner.statusLabel,
                        'Sort ${banner.sortOrder}',
                      ].where((item) => item.isNotEmpty).join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Switch(
                          value: banner.isActive,
                          onChanged: (value) => _toggleActive(banner, value),
                        ),
                        IconButton(
                          tooltip: 'Chỉnh sửa',
                          onPressed: () => _openForm(banner: banner),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        _StatusChip(
                          label: banner.statusLabel,
                          color: _statusColor(banner),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
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

class _BannerFormDialog extends StatefulWidget {
  const _BannerFormDialog({
    required this.banner,
    required this.onSaved,
  });

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

  @override
  void initState() {
    super.initState();
    final banner = widget.banner;
    _titleController = TextEditingController(text: banner?.title ?? '');
    _subtitleController = TextEditingController(text: banner?.subtitle ?? '');
    _imageUrlController = TextEditingController(text: banner?.imageUrl ?? '');
    _tagController = TextEditingController(text: banner?.tag ?? '');
    _linkValueController = TextEditingController(text: banner?.linkValue ?? '');
    _sortOrderController =
        TextEditingController(text: (banner?.sortOrder ?? 0).toString());
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chức năng chọn file tạm thời chưa khả dụng')),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final current = isStart ? _startAt : _endAt;
    final initial = current ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: initial,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.banner == null ? 'Thêm banner' : 'Chỉnh sửa banner'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Tiêu đề', controller: _titleController),
              _field('Phụ đề', controller: _subtitleController, maxLines: 2),
              _field('Tag', controller: _tagController),
              _field('Ảnh URL', controller: _imageUrlController),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(_pickedImage == null ? 'Upload ảnh' : 'Đang chọn...'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _linkType,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Không liên kết')),
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
              _field(
                'Thứ tự hiển thị',
                controller: _sortOrderController,
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Bắt đầu'),
                      subtitle: Text(
                        _startAt == null
                            ? 'Chưa chọn'
                            : DateFormat('dd/MM/yyyy').format(_startAt!),
                      ),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Kết thúc'),
                      subtitle: Text(
                        _endAt == null
                            ? 'Chưa chọn'
                            : DateFormat('dd/MM/yyyy').format(_endAt!),
                      ),
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                title: const Text('Đang chạy'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
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
