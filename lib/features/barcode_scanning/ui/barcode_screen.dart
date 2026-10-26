import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/barcode_provider.dart';

class BarcodeScreen extends StatelessWidget {
  const BarcodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<BarcodeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Scanning')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('1. Choose an image  →  2. Analyze'),
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
              Text(
                'Total barcodes: ${scan.results.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (scan.results.isEmpty) const Text('No barcodes found.'),
              for (final entry in scan.results.asMap().entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      'Barcode ${entry.key + 1}\n${entry.value}',
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
