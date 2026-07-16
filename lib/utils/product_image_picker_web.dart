import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

import 'product_image_picker_result.dart';

Future<PickedProductImage?> pickProductImage({
  ImageSource source = ImageSource.gallery,
}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp,image/gif'
    ..multiple = false;
  if (source == ImageSource.camera) {
    input.setAttribute('capture', 'environment');
  }

  final result = Completer<PickedProductImage?>();
  Timer? cancelTimer;
  late final StreamSubscription<web.Event> changeSubscription;
  late final JSFunction focusListener;

  changeSubscription = input.onChange.listen((_) async {
    cancelTimer?.cancel();
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!result.isCompleted) result.complete(null);
      return;
    }

    try {
      final file = files.item(0)!;
      final bytes = await _readFileBytes(file);
      if (bytes.isEmpty) {
        throw StateError('File ảnh rỗng hoặc không đọc được dữ liệu ảnh');
      }
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        throw StateError('Ảnh vượt quá dung lượng tối đa 10 MB');
      }

      if (!result.isCompleted) {
        result.complete(
          PickedProductImage(
            bytes: bytes,
            fileName: file.name.isEmpty ? 'product.jpg' : file.name,
          ),
        );
      }
    } catch (error, stackTrace) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
    }
  });

  focusListener = ((web.Event _) {
    cancelTimer?.cancel();
    cancelTimer = Timer(const Duration(milliseconds: 700), () {
      if (!result.isCompleted && (input.files?.length ?? 0) == 0) {
        result.complete(null);
      }
    });
  }).toJS;
  web.window.addEventListener('focus', focusListener);

  input.click();
  try {
    return await result.future;
  } finally {
    cancelTimer?.cancel();
    await changeSubscription.cancel();
    web.window.removeEventListener('focus', focusListener);
  }
}

Future<Uint8List> _readFileBytes(web.File file) async {
  try {
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    throw StateError('Trình duyệt không đọc được file ảnh');
  }
}
