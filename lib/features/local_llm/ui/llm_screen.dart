import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/llm_provider.dart';

class LlmScreen extends StatefulWidget {
  const LlmScreen({super.key});
  @override
  State<LlmScreen> createState() => _LlmScreenState();
}

class _LlmScreenState extends State<LlmScreen> {
  final _prompt = TextEditingController(
    text: 'Explain on-device AI in two sentences.',
  );
  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final llm = context.watch<LlmProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Local LLM')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prepare the model',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'SmolLM2 135M • Q4_K_M • ~105 MB\nResponses may be inaccurate.',
                    ),
                    Text(llm.status, key: const Key('llm-status')),
                    if (llm.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          llm.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (llm.isBusy) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value:
                            llm.phase == LlmPhase.downloading &&
                                llm.downloadLengthKnown
                            ? llm.downloadProgress
                            : null,
                      ),
                      if (llm.phase == LlmPhase.downloading &&
                          llm.downloadLengthKnown)
                        Text(
                          '${(llm.downloadProgress * 100).toStringAsFixed(0)}%',
                        ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: llm.isBusy || llm.isModelReady
                          ? null
                          : llm.prepareAndLoadModel,
                      icon: const Icon(Icons.download),
                      label: const Text('Download & Load Model'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stream a response',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prompt,
              onChanged: (_) => setState(() {}),
              minLines: 3,
              maxLines: 6,
              enabled: !llm.isBusy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Prompt',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: llm.canGenerate && _prompt.text.trim().isNotEmpty
                      ? () => llm.runPromptStream(_prompt.text)
                      : null,
                  child: const Text('Generate'),
                ),
                OutlinedButton(
                  onPressed: llm.isGenerating && !llm.wasStopped
                      ? llm.stopGeneration
                      : null,
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Live token output',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  llm.streamedResponse.isEmpty
                      ? 'Your response will appear here, token by token.'
                      : llm.streamedResponse,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
