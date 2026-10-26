import 'dart:io';

import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  final _picker = ImagePicker();

  Future<File?> pickImage(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      requestFullMetadata: false,
    );
    return image == null ? null : File(image.path);
  }
}
