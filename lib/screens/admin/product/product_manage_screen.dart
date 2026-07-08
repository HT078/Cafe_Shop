import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/admin_service.dart';
import '../../../theme/theme.dart';

class ProductManageScreen extends StatefulWidget {
  const ProductManageScreen({super.key});

  @override
  State<ProductManageScreen> createState() => _ProductManageScreenState();
}

class _ProductManageScreenState extends State<ProductManageScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rows = await AdminService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = rows;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? product}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProductFormDialog(product: product, onSaved: _loadProducts),
    );
  }

  String _money(dynamic value) {
    final amount = value is num
        ? value.round()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return '${_currency.format(amount)}đ';
  }

  String _firstImageUrl(Map<String, dynamic> product) {
    final imageUrls = product['image_urls'] ?? product['imageUrls'];
    if (imageUrls is List && imageUrls.isNotEmpty) {
      return imageUrls.first.toString();
    }
    return (product['image_url'] ?? product['imageUrl'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm sản phẩm'),
        backgroundColor: AppTheme.goldColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.goldColor))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_error!, style: const TextStyle(color: Colors.white70)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: _products.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = _products[index];
                final isActive = product['is_active'] != false;
                final imageUrl = _firstImageUrl(product);
                return Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: imageUrl.isEmpty
                            ? Container(
                                color: AppTheme.surfaceAltColor,
                                child: const Icon(
                                  Icons.coffee_rounded,
                                  color: AppTheme.goldColor,
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppTheme.surfaceAltColor,
                                  child: const Icon(
                                    Icons.coffee_rounded,
                                    color: AppTheme.goldColor,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    title: Text(product['name']?.toString() ?? 'Sản phẩm'),
                    subtitle: Text(
                      '${_money(product['price'])} • Tồn ${product['stock'] ?? 0} • ${product['category'] ?? 'Chưa phân loại'}',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () => _openForm(product: product),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () async {
                            final id = product['id']?.toString();
                            if (id == null) return;
                            await AdminService.saveProduct(
                              {
                                ...Map<String, dynamic>.from(product),
                                'is_active': !isActive,
                              },
                              id: id,
                            );
                            await _loadProducts();
                          },
                          icon: Icon(isActive ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({required this.product, required this.onSaved});

  final Map<String, dynamic>? product;
  final Future<void> Function() onSaved;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _thresholdController;
  late final TextEditingController _badgeController;
  late final TextEditingController _weightLabelController;
  late final TextEditingController _weightsController;
  late final TextEditingController _salePercentController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _imageUrlController;
  late bool _isBestSeller;
  late bool _isActive;
  DateTime? _saleStart;
  DateTime? _saleEnd;
  Uint8List? _pickedImage;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?['name']?.toString() ?? '');
    _descriptionController = TextEditingController(text: product?['description']?.toString() ?? '');
    _categoryController = TextEditingController(text: product?['category']?.toString() ?? '');
    _priceController = TextEditingController(text: (product?['price'] ?? 0).toString());
    _stockController = TextEditingController(text: (product?['stock'] ?? 0).toString());
    _thresholdController = TextEditingController(text: (product?['low_stock_threshold'] ?? 5).toString());
    _badgeController = TextEditingController(text: product?['badge']?.toString() ?? 'Mới');
    _weightLabelController = TextEditingController(text: product?['weight_label']?.toString() ?? '500g');
    _weightsController = TextEditingController(text: (product?['weights'] is List ? (product!['weights'] as List).join(',') : '500g'));
    _salePercentController = TextEditingController(text: (product?['sale_percent'] ?? '').toString());
    _salePriceController = TextEditingController(text: (product?['sale_price'] ?? '').toString());
    _imageUrlController = TextEditingController(text: _firstImageUrl(product));
    _isBestSeller = product?['is_best_seller'] == true || product?['isBestSeller'] == true;
    _isActive = product?['is_active'] != false;
    _saleStart = product?['sale_start'] != null ? DateTime.tryParse(product!['sale_start'].toString()) : null;
    _saleEnd = product?['sale_end'] != null ? DateTime.tryParse(product!['sale_end'].toString()) : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _badgeController.dispose();
    _weightLabelController.dispose();
    _weightsController.dispose();
    _salePercentController.dispose();
    _salePriceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  String _firstImageUrl(Map<String, dynamic>? product) {
    if (product == null) return '';
    final imageUrls = product['image_urls'] ?? product['imageUrls'];
    if (imageUrls is List && imageUrls.isNotEmpty) {
      return imageUrls.first.toString();
    }
    return (product['image_url'] ?? product['imageUrl'] ?? '').toString();
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chức năng chọn file tạm thời chưa khả dụng')),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = (isStart ? _saleStart : _saleEnd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _saleStart = picked;
      } else {
        _saleEnd = picked;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tên sản phẩm là bắt buộc')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'name': name,
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.trim(),
        'price': int.tryParse(_priceController.text) ?? 0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'low_stock_threshold': int.tryParse(_thresholdController.text) ?? 5,
        'badge': _badgeController.text.trim(),
        'weight_label': _weightLabelController.text.trim(),
        'weights': _weightsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'grind_options': ['Xay pha phin'],
        'is_best_seller': _isBestSeller,
        'is_active': _isActive && (int.tryParse(_stockController.text) ?? 0) > 0,
        'prices_by_weight': {
          '500g': int.tryParse(_priceController.text) ?? 0,
        },
      };

      final imageUrl = _imageUrlController.text.trim();
      if (imageUrl.isNotEmpty) {
        payload['image_urls'] = [imageUrl];
      }

      if (_salePercentController.text.trim().isNotEmpty) {
        payload['sale_percent'] = int.tryParse(_salePercentController.text);
      }
      if (_salePriceController.text.trim().isNotEmpty) {
        payload['sale_price'] = int.tryParse(_salePriceController.text);
      }
      if (_saleStart != null) {
        payload['sale_start'] = _saleStart!.toIso8601String();
      }
      if (_saleEnd != null) {
        payload['sale_end'] = _saleEnd!.toIso8601String();
      }

      await AdminService.saveProduct(payload, id: widget.product?['id']?.toString());
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Thêm sản phẩm' : 'Chỉnh sửa sản phẩm'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Tên sản phẩm', controller: _nameController),
              _field('Mô tả', controller: _descriptionController, maxLines: 3),
              _ImagePickerField(
                imageUrl: _imageUrlController.text.trim(),
                pickedImage: _pickedImage,
                isUploading: _isUploadingImage,
                onUpload: _pickImage,
              ),
              _field(
                'Ảnh sản phẩm URL',
                controller: _imageUrlController,
              ),
              _field('Danh mục', controller: _categoryController),
              _field('Giá bán', controller: _priceController, keyboardType: TextInputType.number),
              _field('Tồn kho', controller: _stockController, keyboardType: TextInputType.number),
              _field('Ngưỡng cảnh báo', controller: _thresholdController, keyboardType: TextInputType.number),
              _field('Badge', controller: _badgeController),
              _field('Nhãn trọng lượng', controller: _weightLabelController),
              _field('Trọng lượng (cách nhau bằng dấu phẩy)', controller: _weightsController),
              _field('Giảm giá %', controller: _salePercentController, keyboardType: TextInputType.number),
              _field('Giá khuyến mãi', controller: _salePriceController, keyboardType: TextInputType.number),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Bắt đầu khuyến mãi'),
                      subtitle: Text(_saleStart == null ? 'Chưa chọn' : DateFormat('dd/MM/yyyy').format(_saleStart!)),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Kết thúc khuyến mãi'),
                      subtitle: Text(_saleEnd == null ? 'Chưa chọn' : DateFormat('dd/MM/yyyy').format(_saleEnd!)),
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                value: _isBestSeller,
                onChanged: (value) => setState(() => _isBestSeller = value),
                title: const Text('Sản phẩm bán chạy'),
              ),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                title: const Text('Kích hoạt'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _isSaving || _isUploadingImage ? null : _save,
          child: Text(_isSaving ? 'Đang lưu...' : 'Lưu'),
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

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.imageUrl,
    required this.pickedImage,
    required this.isUploading,
    required this.onUpload,
  });

  final String imageUrl;
  final Uint8List? pickedImage;
  final bool isUploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 92,
              height: 92,
              child: _preview(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: isUploading ? null : onUpload,
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(isUploading ? 'Đang tải ảnh...' : 'Upload ảnh sản phẩm'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ảnh sẽ được lưu vào Supabase Storage bucket product-images, sau đó URL được lưu trong products.image_urls.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedColor,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (pickedImage != null) {
      return Image.memory(pickedImage!, fit: BoxFit.cover);
    }

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surfaceAltColor,
      alignment: Alignment.center,
      child: const Icon(
        Icons.add_photo_alternate_outlined,
        color: AppTheme.goldColor,
        size: 34,
      ),
    );
  }
}
