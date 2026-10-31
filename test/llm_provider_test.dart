import 'package:flutter_test/flutter_test.dart';
import 'package:ml_kit_demo/features/local_llm/providers/llm_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('initial state requires model preparation', () {
    final provider = LlmProvider();
    expect(provider.phase, LlmPhase.idle);
    expect(provider.canGenerate, isFalse);
    expect(provider.isBusy, isFalse);
    provider.dispose();
  });
  test('generation without model reports an actionable error', () async {
    final provider = LlmProvider();
    await provider.runPromptStream('Hello');
    expect(provider.error, 'Load the model first.');
    expect(provider.phase, LlmPhase.failed);
    expect(provider.isBusy, isFalse);
    provider.dispose();
  });
  test('Stop while idle is harmless', () async {
    final provider = LlmProvider();
    await provider.stopGeneration();
    expect(provider.phase, LlmPhase.idle);
    provider.dispose();
  });
}
