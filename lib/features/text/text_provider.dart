import 'package:flutter/material.dart';

import '../../core/services/image_picker_service.dart';

class TextProvider extends ChangeNotifier {
  final ImagePickerService picker;
  TextProvider(this.picker);
}
