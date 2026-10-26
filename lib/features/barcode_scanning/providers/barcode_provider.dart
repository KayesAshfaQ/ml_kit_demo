import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../../../core/services/image_picker_service.dart';

class BarcodeProvider extends ChangeNotifier {
  BarcodeProvider(this._picker);
  final ImagePickerService _picker;
  // 1. Create one native detector for this route's lifetime.
  final _detector = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
  File? selectedImage;
  bool isBusy = false;
  bool hasResult = false;
  String? error;
  List<String> results = [];
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
      results = [];
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
      final barcodes = await _detector.processImage(inputImage);
      if (_disposed) return;
      results = barcodes
          .map(
            (barcode) =>
                'Format: ${barcode.format.name}\nType: ${barcode.type.name}\n'
                'Value: ${barcode.displayValue ?? barcode.rawValue ?? "Unavailable"}',
          )
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
      'Barcode scanning • ${results.length} barcodes\n'
      '${results.isEmpty ? "No barcodes found." : results.join("\n\n")}';

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
