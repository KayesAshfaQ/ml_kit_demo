import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_llama/flutter_llama.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum LlmPhase {
  idle,
  preparing,
  downloading,
  loading,
  ready,
  generating,
  stopping,
  completed,
  stopped,
  failed,
}

/// Model preparation, token streaming, and native cleanup live in this Provider.
class LlmProvider extends ChangeNotifier {
  LlmProvider({
    http.Client? client,
    Future<Directory> Function()? documentsDirectory,
  }) : _client = client ?? http.Client(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static const modelFilename = 'smollm2-135m-instruct-q4_k_m.gguf';
  // The originally requested HuggingFaceTB GGUF URL returns HTTP 401.
  static const modelUrl =
      'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/09816acd5d99df7be770d85ea30822623dab342c/SmolLM2-135M-Instruct-Q4_K_M.gguf';
  static const modelBytes = 105454432;
  static Future<void> _cleanup = Future<void>.value();
  static LlmProvider? _nativeOwner;
  final http.Client _client;
  final Future<Directory> Function() _documentsDirectory;
  final _llama = FlutterLlama.instance;

  double downloadProgress = 0;
  bool downloadLengthKnown = true;
  bool isModelReady = false;
  LlmPhase phase = LlmPhase.idle;
  bool get isBusy => switch (phase) {
    LlmPhase.preparing ||
    LlmPhase.downloading ||
    LlmPhase.loading ||
    LlmPhase.generating ||
    LlmPhase.stopping => true,
    _ => false,
  };
  bool get isGenerating =>
      phase == LlmPhase.generating || phase == LlmPhase.stopping;
  bool wasStopped = false;
  String status = 'Model not loaded';
  String streamedResponse = '';
  String? error;
  bool _disposed = false;
  bool _stopRequested = false;
  Future<void>? _active;

  @visibleForTesting
  Future<void> get cleanupComplete => _cleanup;

  bool get canGenerate => !isBusy && isModelReady;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // Set the guard before awaiting so repeated taps cannot start overlapping work.
  Future<void> _perform(Future<void> Function() action) {
    if (_disposed || isBusy) return Future<void>.value();
    phase = LlmPhase.preparing;
    status = 'Preparing…';
    error = null;
    _notify();
    return _active = (() async {
      try {
        await action();
      } catch (e, stack) {
        debugPrint('LLM operation failed: $e\n$stack');
        if (!_disposed) {
          error = e is StateError
              ? e.message.toString()
              : 'Operation failed. Check the connection or model and retry.';
          status = 'Operation failed';
          phase = LlmPhase.failed;
        }
      } finally {
        if (phase == LlmPhase.preparing) {
          phase = isModelReady ? LlmPhase.ready : LlmPhase.idle;
        }
        _notify();
      }
    })();
  }

  /// Step 1: download to app documents, then load quantized weights into RAM.
  Future<void> prepareAndLoadModel() {
    final previousCleanup = _cleanup;
    return _perform(() async {
      if (isModelReady) return;
      status = 'Waiting for previous model cleanup…';
      _notify();
      await previousCleanup;
      if (_disposed) return;
      if (_nativeOwner != null && _nativeOwner != this) {
        throw StateError('Another LLM screen is open. Return to it first.');
      }
      _nativeOwner = this;
      status = 'Checking downloaded model…';
      _notify();
      final directory = await _documentsDirectory();
      if (_disposed) return;
      final file = File('${directory.path}/$modelFilename');
      if (await _validModel(file)) {
        downloadProgress = 1;
        downloadLengthKnown = true;
      } else {
        await _download(file);
      }
      if (_disposed) return;
      phase = LlmPhase.loading;
      status = 'Loading model into native memory…';
      _notify();
      _nativeOwner = this;
      // Route disposal owns memory. Disable the plugin's background/idle policy:
      // automatic unloading must not invalidate readiness during this lesson.
      _llama.lifecycle = LlamaLifecycle(
        unloadOnBackground: false,
        idleTimeoutOff: true,
        onMemoryPressure: MemoryPressureAction.ignore,
      );
      isModelReady = await _llama.loadModel(
        LlamaConfig(
          modelPath: file.path,
          nThreads: 4,
          nGpuLayers: -1,
          contextSize: 2048,
          useGpu: true,
        ),
      );
      if (!isModelReady) {
        throw StateError('Model could not load. Try a physical device.');
      }
      phase = LlmPhase.ready;
      status = 'Model ready — offline inference';
    });
  }

  Future<bool> _validModel(File file) async {
    if (!await file.exists() || await file.length() != modelBytes) return false;
    final handle = await file.open();
    try {
      return ascii.decode(await handle.read(4), allowInvalid: true) == 'GGUF';
    } finally {
      await handle.close();
    }
  }

  Future<void> _download(File file) async {
    final partial = File('${file.path}.part');
    IOSink? sink;
    try {
      phase = LlmPhase.downloading;
      downloadLengthKnown = false;
      status = 'Downloading model (~105 MB)…';
      downloadProgress = 0;
      _notify();
      final response = await _client
          .send(http.Request('GET', Uri.parse(modelUrl)))
          .timeout(const Duration(seconds: 30));
      if (_disposed) return;
      if (response.statusCode != 200) {
        throw StateError(
          'Download failed (HTTP ${response.statusCode}). Retry the download.',
        );
      }
      downloadLengthKnown = response.contentLength != null;
      sink = partial.openWrite();
      var received = 0;
      await for (final bytes in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (_disposed) return;
        sink.add(
          bytes,
        ); // Stream to disk; never hold the full GGUF in Dart RAM.
        received += bytes.length;
        downloadProgress = (received / (response.contentLength ?? modelBytes))
            .clamp(0.0, 1.0);
        _notify();
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (_disposed) return;
      if (!await _validModel(partial)) {
        throw StateError(
          'Download is incomplete or invalid. Retry the download.',
        );
      }
      await partial.rename(file.path);
      downloadProgress = 1;
    } finally {
      await sink?.close();
      if (await partial.exists()) await partial.delete();
    }
  }

  /// Step 2: each token changes state, which rebuilds the live response viewer.
  Future<void> runPromptStream(String prompt) => _perform(() async {
    if (!isModelReady) {
      throw StateError('Load the model first.');
    }
    if (prompt.trim().isEmpty) throw StateError('Enter a prompt first.');
    await _generate(prompt.trim());
  });

  Future<void> _generate(String prompt) async {
    if (_disposed) return;
    final candidate =
        '<|im_start|>system\nYou are a helpful, concise assistant. Follow the user instruction.<|im_end|>\n<|im_start|>user\n$prompt<|im_end|>\n<|im_start|>assistant\n';
    if (utf8.encode(candidate).length > 1700) {
      throw StateError('Prompt is too long. Use a shorter prompt.');
    }
    streamedResponse = '';
    wasStopped = false;
    _stopRequested = false;
    phase = LlmPhase.generating;
    status = 'Generating offline…';
    _notify();
    final formattedPrompt =
        '<|im_start|>system\nYou are a helpful, concise assistant. Follow the user instruction.<|im_end|>\n<|im_start|>user\n$prompt<|im_end|>\n<|im_start|>assistant\n';
    final params = GenerationParams(
      prompt: formattedPrompt,
      temperature: 0.3,
      topP: 0.9,
      topK: 40,
      maxTokens: 256,
      repeatPenalty: 1.1,
      stopSequences: ['<|im_end|>', '<|im_start|>'],
    );
    // A conservative UTF-8 byte budget bounds tokens without relying on the
    // plugin's newer core tokenizer (not exposed by its mobile legacy bridge).
    if (utf8.encode(formattedPrompt).length > 1700) {
      throw StateError(
        'Prompt is too long for the 2048-token context. Use a shorter prompt.',
      );
    }
    if (_disposed || _stopRequested) return;
    final stream = _llama.generateStream(params);
    await for (final token in stream) {
      if (_disposed || _stopRequested) break;
      streamedResponse += token;
      _notify();
    }
    wasStopped = _stopRequested;
    phase = wasStopped ? LlmPhase.stopped : LlmPhase.completed;
    if (!wasStopped && streamedResponse.trim().isEmpty) {
      throw StateError('The model returned no text. Try another prompt.');
    }
    status = wasStopped ? 'Stopped — partial response' : 'Response complete';
  }

  Future<void> stopGeneration() async {
    if (_disposed || !isGenerating || _stopRequested) return;
    _stopRequested = true;
    wasStopped = true;
    phase = LlmPhase.stopping;
    status = 'Stopping…';
    _notify();
    await _llama.stopGeneration();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopRequested = true;
    _client.close();
    final stop = _nativeOwner == this
        ? _llama.stopGeneration()
        : Future<void>.value();
    // Step 4: llama.cpp allocate native C++ memory outside Dart's GC.
    // dispose cannot be async: schedule cleanup, waiting for in-flight load
    // and generation before freeing memory. The next route load waits for this.
    final previous = _cleanup;
    _cleanup = () async {
      await previous;
      await stop;
      await _active;

      if (_nativeOwner == this) {
        try {
          await _llama.unloadModel();
        } catch (e) {
          debugPrint('LLM cleanup failed: $e');
        } finally {
          if (!_llama.isModelLoaded) _nativeOwner = null;
        }
      }
    }();
    super.dispose();
  }
}
