import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/image_picker_service.dart';

class TextProvider extends ChangeNotifier {
  TextProvider(this._picker);
  final ImagePickerService _picker;
  // 1. Create one native detector for this route's lifetime.
  final _detector = TextRecognizer(script: TextRecognitionScript.latin);
  File? selectedImage;
  bool isBusy = false;
  bool hasResult = false;
  String? error;
  String fullText = '';
  List<List<String>> blocks = [];
  bool _disposed = false;
  Future<void>? _processing;

  Future<void> pickImage(ImageSource source) async {
    if (isBusy || _disposed) return;
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final image = await _picker.pickImage(source);
      if (_disposed || image == null) return;
      selectedImage = image;
      hasResult = false;
      fullText = '';
      blocks = [];
    } catch (_) {
      if (!_disposed) {
        error = 'Could not open the image. Check permissions and try again.';
      }
    } finally {
      if (!_disposed) {
        isBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> analyze() async {
    if (isBusy || _disposed || selectedImage == null) return;
    isBusy = true;
    hasResult = false;
    error = null;
    notifyListeners();
    _processing = _processImage();
    await _processing;
  }

  Future<void> _processImage() async {
    try {
      // 2. Convert the selected file into ML Kit's input type.
      final inputImage = InputImage.fromFilePath(selectedImage!.path);
      // 3. Process and parse the result, then rebuild listening widgets.
      final result = await _detector.processImage(inputImage);
      if (_disposed) return;
      fullText = result.text;
      blocks = result.blocks
          .map((block) => block.lines.map((line) => line.text).toList())
          .toList();
      hasResult = true;
    } catch (_) {
      if (!_disposed) error = 'Analysis failed. Try a clear, well-lit image.';
    } finally {
      if (!_disposed) {
        isBusy = false;
        notifyListeners();
      }
    }
  }

  String get summary =>
      'Text recognition • ${blocks.length} blocks, '
      '${blocks.fold<int>(0, (count, lines) => count + lines.length)} lines\n'
      '${fullText.isEmpty ? "No text found." : fullText}';

  @override
  void dispose() {
    _disposed = true;
    // 4. Release native memory when leaving the route. Let an active scan
    // finish first so its native detector is not closed while in use.
    unawaited(
      (_processing ?? Future<void>.value())
          .then((_) => _detector.close())
          .catchError((Object error, StackTrace stack) {
            debugPrint('Detector cleanup failed: $error');
          }),
    );
    super.dispose();
  }
}
