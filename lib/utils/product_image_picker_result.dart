import 'dart:typed_data';

class PickedProductImage {
  const PickedProductImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}
