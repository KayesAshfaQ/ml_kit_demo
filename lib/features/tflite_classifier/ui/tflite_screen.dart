import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/tflite_provider.dart';

class TfliteScreen extends StatelessWidget {
  const TfliteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<TfliteProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('TFLite Classifier')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Model Inspector',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (scan.inputType != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      'Input: ${scan.inputShape} (${scan.inputType!.name})',
                    ),
                  ),
                  Chip(
                    label: Text(
                      'Output: ${scan.outputShape} (${scan.outputType!.name})',
                    ),
                  ),
                ],
              )
            else
              const Text('Load a model to inspect its tensors.'),
            if (!scan.isReady)
              OutlinedButton.icon(
                onPressed: scan.isBusy ? null : scan.initModel,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Model Loading'),
              ),
            const SizedBox(height: 16),
            const Text('1. Choose an image  →  2. Classify'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: scan.isBusy
                      ? null
                      : () => scan.pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: scan.isBusy
                      ? null
                      : () => scan.pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (scan.selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  scan.selectedImage!,
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => const SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'Image preview unavailable. Choose another image.',
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(
                height: 180,
                child: Center(child: Text('Choose a photo to get started.')),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  scan.isBusy || !scan.isReady || scan.selectedImage == null
                  ? null
                  : scan.classify,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Classify'),
            ),
            if (scan.isBusy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (scan.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  scan.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (scan.predictions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Top predictions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final entry in scan.predictions.asMap().entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${entry.key + 1}  ${entry.value.label}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${(entry.value.confidence * 100).toStringAsFixed(1)}%',
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: entry.value.confidence,
                          semanticsLabel: '${entry.value.label} confidence',
                          semanticsValue:
                              '${(entry.value.confidence * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            
          ],
        ),
      ),
    );
  }
}
