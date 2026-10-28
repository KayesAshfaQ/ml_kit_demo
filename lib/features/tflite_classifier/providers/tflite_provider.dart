import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../core/services/image_picker_service.dart';
import '../models/prediction_model.dart';

class TfliteProvider extends ChangeNotifier {
  TfliteProvider(this._picker, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final ImagePickerService _picker;
  final AssetBundle _bundle;
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _disposed = false;

  File? selectedImage;
  List<PredictionModel> predictions = [];
  List<int> inputShape = [];
  List<int> outputShape = [];
  TensorType? inputType;
  TensorType? outputType;
  bool isBusy = false;
  bool isReady = false;
  String? error;

  // STEP 1 — Load model + labels, then inspect their tensor contract.
  Future<void> initModel() async {
    if (_disposed || isBusy || isReady) return;
    isBusy = true;
    error = null;
    notifyListeners();
    Interpreter? loaded;
    try {
      // Check assets separately, so a missing file produces an instructional
      // error rather than being confused with a native library/model failure.
      try {
        _labels = (await _bundle.loadString('assets/model/labels.txt'))
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .toList();
        // Drop trailing newlines only: dropping interior blank labels could
        // shift all class indices. Validation below rejects empty class names.
        while (_labels.isNotEmpty && _labels.last.isEmpty) {
          _labels.removeLast();
        }
        await _bundle.load('assets/model/model.tflite');
      } catch (_) {
        throw const FormatException(
          'Model assets are missing. Drop model.tflite and labels.txt into '
          'assets/model/, register assets/model/ in pubspec.yaml, then fully '
          'restart the app. See assets/model/README_MODEL.md.',
        );
      }
      if (_disposed) return;
      loaded = await Interpreter.fromAsset('assets/model/model.tflite');
      if (_disposed) {
        loaded.close();
        return;
      }
      final input = loaded.getInputTensor(0);
      final output = loaded.getOutputTensor(0);
      inputShape = input.shape;
      outputShape = output.shape;
      inputType = input.type;
      outputType = output.type;
      validateModel(
        inputShape,
        input.type,
        outputShape,
        output.type,
        _labels,
        inputCount: loaded.getInputTensors().length,
        outputCount: loaded.getOutputTensors().length,
      );
      if (output.type == TensorType.uint8 && output.params.scale <= 0) {
        throw const FormatException(
          'The output quantization scale must be positive.',
        );
      }
      _interpreter = loaded;
      isReady = true;
    } catch (failure) {
      loaded?.close();
      if (!_disposed) {
        error = failure is FormatException
            ? failure.message
            : 'Could not load the TFLite model. Check that it is a valid '
                  'image classifier and that the native TFLite library is available. '
                  'See assets/model/README_MODEL.md, then retry.';
      }
    } finally {
      _finish();
    }
  }

  Future<void> pickImage(ImageSource source) async {
    if (_disposed || isBusy) return;
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final image = await _picker.pickImage(source);
      if (_disposed || image == null) return;
      selectedImage = image;
      predictions = [];
    } catch (_) {
      if (!_disposed) {
        error = 'Could not open the image. Check permissions and try again.';
      }
    } finally {
      _finish();
    }
  }

  Future<void> classify() async {
    if (_disposed || isBusy || !isReady || selectedImage == null) return;
    isBusy = true;
    error = null;
    predictions = [];
    notifyListeners();
    try {
      // STEP 2 — Decode → orient → resize → RGB → [1, height, width, 3].
      final bytes = await selectedImage!.readAsBytes();
      // Navigation may have disposed and closed the interpreter during the read.
      if (_disposed) return;
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw const FormatException(
          'Cannot decode this photo. Try a JPEG or PNG image.',
        );
      }
      final inputTensor = preprocessImage(
        decoded,
        width: inputShape[2],
        height: inputShape[1],
        type: inputType!,
      );

      // STEP 3 — Allocate the output with its OWN type, then run inference.
      // Input and output types need not be the same. Double zeros matter for
      // float32; int zeros matter for uint8. Both objects match tensor shapes.
      final outputTensor = allocateOutput(outputShape[1], outputType!);
      // This small demo deliberately keeps inference here for live teaching.
      // run is synchronous: disposal cannot interrupt a native call mid-run.
      _interpreter!.run(inputTensor, outputTensor);

      // STEP 4 — Convert scores to probabilities and show the top 3 labels.
      final output = _interpreter!.getOutputTensor(0);
      predictions = topPredictions(
        outputTensor.first,
        _labels,
        type: outputType!,
        scale: outputType == TensorType.uint8 ? output.params.scale : 1,
        zeroPoint: outputType == TensorType.uint8 ? output.params.zeroPoint : 0,
      );
    } catch (failure) {
      if (!_disposed) {
        error = failure is FormatException
            ? failure.message
            : 'Classification failed. Try another JPEG or PNG photo and '
                  'check that the model matches the documented tensor format.';
      }
    } finally {
      _finish();
    }
  }

  // Helpers stay in this Provider so students can read the entire pipeline.
  // Pure inputs/outputs also let us test tensor math without native plugins.
  @visibleForTesting
  static void validateModel(
    List<int> input,
    TensorType inputType,
    List<int> output,
    TensorType outputType,
    List<String> labels, {
    int inputCount = 1,
    int outputCount = 1,
  }) {
    if (inputCount != 1 ||
        outputCount != 1 ||
        input.length != 4 ||
        input[0] != 1 ||
        input[1] <= 0 ||
        input[2] <= 0 ||
        input[3] != 3 ||
        output.length != 2 ||
        output[0] != 1 ||
        output[1] <= 0) {
      throw const FormatException(
        'Use a single-input RGB classifier: input [1, height, width, 3] '
        'and output [1, classes]. Detection and multi-input models are unsupported.',
      );
    }
    if (![TensorType.float32, TensorType.uint8].contains(inputType) ||
        ![TensorType.float32, TensorType.uint8].contains(outputType)) {
      throw const FormatException(
        'This lesson supports float32 or uint8 tensors only.',
      );
    }
    if (labels.length != output[1] || labels.any((label) => label.isEmpty)) {
      throw FormatException(
        'labels.txt must contain ${output[1]} nonempty class labels, in model '
        'output order. Include the background label if the model has one.',
      );
    }
  }

  @visibleForTesting
  static Object preprocessImage(
    img.Image decoded, {
    required int width,
    required int height,
    required TensorType type,
  }) {
    final resized = img.copyResize(
      img.bakeOrientation(decoded),
      width: width,
      height: height,
    );
    if (type == TensorType.float32) {
      // Float32 lesson contract: normalize raw channels to 0.0–1.0.
      // Some other models require -1–1: consult their training/export docs.
      return [
        List.generate(
          height,
          (y) => List.generate(width, (x) {
            final pixel = resized.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          }),
        ),
      ];
    }
    if (type == TensorType.uint8) {
      // Quantized MobileNet expects raw RGB integers, not normalized doubles.
      return [
        List.generate(
          height,
          (y) => List.generate(width, (x) {
            final pixel = resized.getPixel(x, y);
            return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
          }),
        ),
      ];
    }
    throw const FormatException('Unsupported input tensor type.');
  }

  @visibleForTesting
  static List<List<num>> allocateOutput(int classes, TensorType type) {
    if (type == TensorType.float32) return [List<double>.filled(classes, 0.0)];
    if (type == TensorType.uint8) return [List<int>.filled(classes, 0)];
    throw const FormatException('Unsupported output tensor type.');
  }

  @visibleForTesting
  static List<PredictionModel> topPredictions(
    List<num> scores,
    List<String> labels, {
    required TensorType type,
    double scale = 1,
    int zeroPoint = 0,
  }) {
    final ranked = List.generate(scores.length, (index) {
      // Quantization: real probability = (integer - zero point) × scale.
      // Dividing every output by 255 would be wrong for other quantization scales.
      final probability = type == TensorType.uint8
          ? (scores[index] - zeroPoint) * scale
          : scores[index].toDouble();
      if (!probability.isFinite ||
          probability < -0.001 ||
          probability > 1.001) {
        throw const FormatException(
          'Expected probability outputs, not logits. Use a classifier with a probability output.',
        );
      }
      return PredictionModel(
        label: labels[index],
        confidence: probability.clamp(0.0, 1.0),
      );
    })..sort((a, b) => b.confidence.compareTo(a.confidence));
    return ranked.take(3).toList();
  }

  void _finish() {
    if (_disposed) return;
    isBusy = false;
    notifyListeners();
  }

  // STEP 5 — Release native memory when the route is popped.
  @override
  void dispose() {
    _disposed = true;
    _interpreter?.close();
    _interpreter = null;
    super.dispose();
  }
}
