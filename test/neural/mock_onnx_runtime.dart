import 'package:anteater/neural/inference/onnx_runtime.dart';

/// Mock ONNX Runtime for testing.
///
/// This class is only for testing purposes. In production code,
/// use [NativeOnnxRuntime] with actual ONNX Runtime library.
class MockOnnxRuntime implements OnnxRuntime {
  bool _loaded = false;

  @override
  Future<void> loadModel(String modelPath) async {
    _loaded = true;
  }

  @override
  Future<List<double>> getEmbedding(List<int> inputIds) async {
    if (!_loaded) {
      throw StateError('Model not loaded');
    }

    // Return deterministic mock embedding based on input
    final hash = inputIds.fold(0, (sum, id) => sum + id);
    return List.generate(768, (i) => (hash + i) % 1000 / 1000.0);
  }

  @override
  void dispose() {
    _loaded = false;
  }
}
