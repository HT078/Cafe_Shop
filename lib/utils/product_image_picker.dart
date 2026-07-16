import 'product_image_picker_stub.dart'
    if (dart.library.html) 'product_image_picker_web.dart'
    as picker;
import 'product_image_picker_result.dart';
import 'package:image_picker/image_picker.dart';

Future<PickedProductImage?> pickProductImage({
  ImageSource source = ImageSource.gallery,
}) => picker.pickProductImage(source: source);
