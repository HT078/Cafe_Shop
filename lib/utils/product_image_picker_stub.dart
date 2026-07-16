import 'package:image_picker/image_picker.dart';

import 'product_image_picker_result.dart';

Future<PickedProductImage?> pickProductImage({
  ImageSource source = ImageSource.gallery,
}) async {
  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: source,
    imageQuality: 90,
    maxWidth: 1800,
  );
  if (image == null) return null;

  final bytes = await image.readAsBytes();
  if (bytes.isEmpty) {
    throw StateError('File ảnh rỗng hoặc không đọc được dữ liệu ảnh');
  }

  return PickedProductImage(
    bytes: bytes,
    fileName: image.name.isEmpty ? 'product.jpg' : image.name,
  );
}
