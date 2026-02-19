import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ThumbnailGenerator {
  static Uint8List? generateThumbnail(Uint8List imageBytes) {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      const int maxSize = 200;
      img.Image thumbnail;

      if (image.width > image.height) {
        thumbnail = img.copyResize(image, width: maxSize);
      } else {
        thumbnail = img.copyResize(image, height: maxSize);
      }

      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 85));
    } catch (e) {
      return null;
    }
  }
}
