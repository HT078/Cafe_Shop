import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../services/admin_service.dart';
import '../../../theme/theme.dart';
import '../../../utils/product_image_picker.dart';

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
      builder: (_) =>
          _ProductFormDialog(product: product, onSaved: _loadProducts),
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

  int _productPrice(Map<String, dynamic> product) {
    final price = _asInt(product['price']);
    if (price > 0) return price;
    for (final key in const ['price_500g', 'price_250g', 'price_1kg']) {
      final legacyPrice = _asInt(product[key]);
      if (legacyPrice > 0) return legacyPrice;
    }
    final prices = product['prices_by_weight'];
    if (prices is Map) {
      for (final value in prices.values) {
        final mappedPrice = _asInt(value);
        if (mappedPrice > 0) return mappedPrice;
      }
    }
    return 0;
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(
          value?.toString().replaceAll('.', '').replaceAll(',', '') ?? '',
        ) ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm sản phẩm'),
        backgroundColor: AppTheme.goldColor,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.goldColor),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.mutedColor),
                ),
              ),
            )
          : _products.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: AppTheme.mutedColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có sản phẩm nào',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bấm "Thêm sản phẩm" để tạo sản phẩm đầu tiên.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedColor,
                      ),
                    ),
                  ],
                ),
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
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
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
                      '${_money(_productPrice(product))} • Tồn ${product['stock'] ?? 0} • ${product['category'] ?? 'Chưa phân loại'}',
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
                            await AdminService.saveProduct({
                              ...Map<String, dynamic>.from(product),
                              'is_active': !isActive,
                            }, id: id);
                            await _loadProducts();
                          },
                          icon: Icon(
                            isActive
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
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
  String? _imageUploadError;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(
      text: product?['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: product?['description']?.toString() ?? '',
    );
    _categoryController = TextEditingController(
      text: product?['category']?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: _formatVndInput(_storedProductPrice(product)),
    );
    _stockController = TextEditingController(
      text: (product?['stock'] ?? 0).toString(),
    );
    _thresholdController = TextEditingController(
      text: (product?['low_stock_threshold'] ?? 5).toString(),
    );
    _badgeController = TextEditingController(
      text: product?['badge']?.toString() ?? 'Mới',
    );
    _weightLabelController = TextEditingController(
      text: product?['weight_label']?.toString() ?? '500g',
    );
    _weightsController = TextEditingController(
      text: (product?['weights'] is List
          ? (product!['weights'] as List).join(',')
          : '500g'),
    );
    _salePercentController = TextEditingController(
      text: (product?['sale_percent'] ?? '').toString(),
    );
    _salePriceController = TextEditingController(
      text: _formatVndInput(product?['sale_price'], emptyForZero: true),
    );
    _imageUrlController = TextEditingController(text: _firstImageUrl(product));
    _isBestSeller =
        product?['is_best_seller'] == true || product?['isBestSeller'] == true;
    _isActive = product?['is_active'] != false;
    _saleStart = product?['sale_start'] != null
        ? DateTime.tryParse(product!['sale_start'].toString())
        : null;
    _saleEnd = product?['sale_end'] != null
        ? DateTime.tryParse(product!['sale_end'].toString())
        : null;
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

  static String _formatVndInput(dynamic value, {bool emptyForZero = false}) {
    final number = value is num
        ? value.round()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    if (emptyForZero && number == 0) return '';
    return _formatVnd(number);
  }

  static int _storedProductPrice(Map<String, dynamic>? product) {
    if (product == null) return 0;
    final direct = _parseVnd(product['price']?.toString() ?? '');
    if (direct > 0) return direct;
    for (final key in const ['price_500g', 'price_250g', 'price_1kg']) {
      final legacy = _parseVnd(product[key]?.toString() ?? '');
      if (legacy > 0) return legacy;
    }
    final prices = product['prices_by_weight'];
    if (prices is Map) {
      for (final value in prices.values) {
        final mapped = _parseVnd(value.toString());
        if (mapped > 0) return mapped;
      }
    }
    return 0;
  }

  static String _formatVnd(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
  }

  static int _parseVnd(String value) {
    return int.tryParse(value.replaceAll('.', '').replaceAll(',', '').trim()) ??
        0;
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isUploadingImage = true;
      _imageUploadError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final image = await pickProductImage(source: source);
      if (!mounted || image == null) return;

      setState(() => _pickedImage = image.bytes);
      final imageUrl = await AdminService.uploadProductImage(
        bytes: image.bytes,
        fileName: image.fileName,
      );
      if (imageUrl == null || imageUrl.isEmpty) {
        throw StateError('Supabase không trả về public URL của ảnh');
      }
      if (!mounted) return;
      setState(() {
        _imageUrlController.text = imageUrl;
        _imageUploadError = null;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã tải ảnh sản phẩm')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyImageError(error);
      setState(() => _imageUploadError = message);
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.blazeColor),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  String _friendlyImageError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    final lower = text.toLowerCase();
    if (lower.contains('row-level security') ||
        lower.contains('not authorized') ||
        lower.contains('unauthorized') ||
        lower.contains('403') ||
        lower.contains('42501')) {
      return 'Tài khoản chưa được policy Storage products nhận là admin. Hãy chạy lại SQL policy products trong Supabase.';
    }
    if (text.toLowerCase().contains('permission')) {
      return 'Không có quyền đọc ảnh hoặc mở camera. Hãy cấp quyền rồi thử lại.';
    }
    if (text.contains('bucket') || text.contains('products')) {
      return 'Không upload được ảnh: cần tạo bucket products và policy admin trong Supabase.';
    }
    return 'Không upload được ảnh sản phẩm: $text';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tên sản phẩm là bắt buộc')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final category = _categoryController.text.trim().isEmpty
          ? 'Chưa phân loại'
          : _categoryController.text.trim();
      final enteredPrice = _parseVnd(_priceController.text);
      final payload = <String, dynamic>{
        'name': name,
        'description': _descriptionController.text.trim(),
        'category': category,
        'price': enteredPrice,
        // Keep compatibility with the older Supabase products schema.
        'price_250g': enteredPrice,
        'price_500g': enteredPrice,
        'price_1kg': enteredPrice,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'low_stock_threshold': int.tryParse(_thresholdController.text) ?? 5,
        'badge': _badgeController.text.trim(),
        'weight_label': _weightLabelController.text.trim(),
        'weights': _weightsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'grind_options': ['Xay pha phin'],
        'is_best_seller': _isBestSeller,
        'is_active':
            _isActive && (int.tryParse(_stockController.text) ?? 0) > 0,
        'prices_by_weight': {'500g': enteredPrice},
      };

      final imageUrl = _imageUrlController.text.trim();
      if (imageUrl.isNotEmpty) {
        payload['image_urls'] = [imageUrl];
      }

      if (_salePercentController.text.trim().isNotEmpty) {
        payload['sale_percent'] = int.tryParse(_salePercentController.text);
      }
      if (_salePriceController.text.trim().isNotEmpty) {
        payload['sale_price'] = _parseVnd(_salePriceController.text);
      }
      if (_saleStart != null) {
        payload['sale_start'] = _saleStart!.toIso8601String();
      }
      if (_saleEnd != null) {
        payload['sale_end'] = _saleEnd!.toIso8601String();
      }

      await AdminService.saveProduct(
        payload,
        id: widget.product?['id']?.toString(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null ? 'Thêm sản phẩm' : 'Chỉnh sửa sản phẩm',
      ),
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
                errorText: _imageUploadError,
                onPickGallery: () => _pickImage(ImageSource.gallery),
                onPickCamera: () => _pickImage(ImageSource.camera),
              ),
              _field('Danh mục', controller: _categoryController),
              _field(
                'Giá bán',
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: const [_VietnameseMoneyFormatter()],
              ),
              _field(
                'Tồn kho',
                controller: _stockController,
                keyboardType: TextInputType.number,
              ),
              _field(
                'Ngưỡng cảnh báo',
                controller: _thresholdController,
                keyboardType: TextInputType.number,
              ),
              _field('Badge', controller: _badgeController),
              _field('Nhãn trọng lượng', controller: _weightLabelController),
              _field(
                'Trọng lượng (cách nhau bằng dấu phẩy)',
                controller: _weightsController,
              ),
              _field(
                'Giảm giá %',
                controller: _salePercentController,
                keyboardType: TextInputType.number,
              ),
              _field(
                'Giá khuyến mãi',
                controller: _salePriceController,
                keyboardType: TextInputType.number,
                inputFormatters: const [_VietnameseMoneyFormatter()],
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Bắt đầu khuyến mãi'),
                      subtitle: Text(
                        _saleStart == null
                            ? 'Chưa chọn'
                            : DateFormat('dd/MM/yyyy').format(_saleStart!),
                      ),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Kết thúc khuyến mãi'),
                      subtitle: Text(
                        _saleEnd == null
                            ? 'Chưa chọn'
                            : DateFormat('dd/MM/yyyy').format(_saleEnd!),
                      ),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _VietnameseMoneyFormatter extends TextInputFormatter {
  const _VietnameseMoneyFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.imageUrl,
    required this.pickedImage,
    required this.isUploading,
    required this.errorText,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  final String imageUrl;
  final Uint8List? pickedImage;
  final bool isUploading;
  final String? errorText;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: 92, height: 92, child: _preview()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUploading ? null : onPickGallery,
                        icon: isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_library_outlined),
                        label: Text(isUploading ? 'Đang tải...' : 'Thư viện'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Chụp bằng camera',
                      onPressed: isUploading ? null : onPickCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ảnh sẽ được lưu vào Supabase Storage bucket products, sau đó URL được lưu trong products.image_urls.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    errorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.blazeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
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
