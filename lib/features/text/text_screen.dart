import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'text_provider.dart';

class TextScreen extends StatelessWidget {
  
  const TextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<TextProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Text Recognition')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('1. Choose an image  →  2. Analyze  →  3. Save'),
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
              onPressed: scan.isBusy || scan.selectedImage == null
                  ? null
                  : scan.analyze,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Analyze'),
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
            if (scan.hasResult) ...[
              const SizedBox(height: 20),
              Text('Full text', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              SelectableText(
                scan.fullText.isEmpty ? 'No text found.' : scan.fullText,
              ),
              const SizedBox(height: 16),
              Text(
                'Blocks and lines',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final block in scan.blocks.asMap().entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      'Block ${block.key + 1}\n${block.value.asMap().entries.map((line) => "Line ${line.key + 1}: ${line.value}").join("\n")}',
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
