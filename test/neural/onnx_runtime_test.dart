import 'package:test/test.dart';
import 'package:anteater/neural/inference/onnx_runtime.dart';

import 'mock_onnx_runtime.dart';

void main() {
  group('OnnxRuntime', () {
    group('cosineSimilarity', () {
      test('identical vectors have similarity 1.0', () {
        final a = [1.0, 2.0, 3.0];
        final b = [1.0, 2.0, 3.0];

        final similarity = OnnxRuntime.cosineSimilarity(a, b);

        expect(similarity, closeTo(1.0, 0.0001));
      });

      test('orthogonal vectors have similarity 0.0', () {
        final a = [1.0, 0.0, 0.0];
        final b = [0.0, 1.0, 0.0];

        final similarity = OnnxRuntime.cosineSimilarity(a, b);

        expect(similarity, closeTo(0.0, 0.0001));
      });

      test('opposite vectors have similarity -1.0', () {
        final a = [1.0, 2.0, 3.0];
        final b = [-1.0, -2.0, -3.0];

        final similarity = OnnxRuntime.cosineSimilarity(a, b);

        expect(similarity, closeTo(-1.0, 0.0001));
      });

      test('handles zero vectors', () {
        final a = [0.0, 0.0, 0.0];
        final b = [1.0, 2.0, 3.0];

        final similarity = OnnxRuntime.cosineSimilarity(a, b);

        expect(similarity, equals(0.0));
      });

      test('throws on dimension mismatch', () {
        final a = [1.0, 2.0];
        final b = [1.0, 2.0, 3.0];

        expect(
          () => OnnxRuntime.cosineSimilarity(a, b),
          throwsArgumentError,
        );
      });

      test('works with 768-dimensional embeddings', () {
        final a = List.generate(768, (i) => i / 768.0);
        final b = List.generate(768, (i) => i / 768.0);

        final similarity = OnnxRuntime.cosineSimilarity(a, b);

        expect(similarity, closeTo(1.0, 0.0001));
      });

      test('similar vectors have high similarity', () {
        final a = [1.0, 2.0, 3.0, 4.0, 5.0];
        final b = [1.1, 2.1, 3.1, 4.1, 5.1];

        final similarity = OnnxRuntime.cosineSimilarity(a, b);

        expect(similarity, greaterThan(0.99));
      });

      test('handles moderate values without overflow', () {
        // Test with reasonable values that don't overflow the custom sqrt
        final a = [100.0, 200.0, 300.0];
        final b = [100.0, 200.0, 300.0];

        final similarity = OnnxRuntime.cosineSimilarity(a, b);

        expect(similarity, closeTo(1.0, 0.0001));
      });

      test('handles negative values', () {
        // Mix of positive and negative
        final a = [-1.0, 2.0, -3.0];
        final b = [-1.0, 2.0, -3.0];

        final similarity = OnnxRuntime.cosineSimilarity(a, b);

        expect(similarity, closeTo(1.0, 0.0001));
      });
    });
  });

  group('MockOnnxRuntime', () {
    late MockOnnxRuntime runtime;

    setUp(() {
      runtime = MockOnnxRuntime();
    });

    tearDown(() {
      runtime.dispose();
    });

    test('throws StateError if model not loaded', () async {
      expect(
        () => runtime.getEmbedding([101, 102, 103]),
        throwsA(isA<StateError>()),
      );
    });

    test('returns 768-dimensional embedding after model load', () async {
      await runtime.loadModel('dummy.onnx');
      final embedding = await runtime.getEmbedding([101, 102, 103]);

      expect(embedding.length, equals(768));
    });

    test('returns deterministic embeddings for same input', () async {
      await runtime.loadModel('dummy.onnx');
      final embedding1 = await runtime.getEmbedding([101, 102, 103]);
      final embedding2 = await runtime.getEmbedding([101, 102, 103]);

      expect(embedding1, equals(embedding2));
    });

    test('different inputs produce different embeddings', () async {
      await runtime.loadModel('dummy.onnx');
      final embedding1 = await runtime.getEmbedding([101, 102, 103]);
      final embedding2 = await runtime.getEmbedding([104, 105, 106]);

      expect(embedding1, isNot(equals(embedding2)));
    });

    test('embeddings are normalized (values 0-1)', () async {
      await runtime.loadModel('dummy.onnx');
      final embedding = await runtime.getEmbedding([101, 102, 103]);

      for (final value in embedding) {
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThan(1.0));
      }
    });

    test('embedding hash is deterministic across calls', () async {
      await runtime.loadModel('dummy.onnx');

      // Same input ids should produce same embedding
      final emb1 = await runtime.getEmbedding([1, 2, 3]);
      final emb2 = await runtime.getEmbedding([1, 2, 3]);

      expect(emb1, equals(emb2));
    });

    test('can be reused after dispose and reload', () async {
      await runtime.loadModel('dummy.onnx');
      runtime.dispose();

      expect(
        () => runtime.getEmbedding([101]),
        throwsA(isA<StateError>()),
      );

      // Re-load
      await runtime.loadModel('another.onnx');
      final embedding = await runtime.getEmbedding([101]);

      expect(embedding.length, equals(768));
    });
  });

  group('NativeOnnxRuntime', () {
    late NativeOnnxRuntime runtime;

    setUp(() {
      runtime = NativeOnnxRuntime();
    });

    tearDown(() {
      runtime.dispose();
    });

    test('throws StateError if model not loaded', () async {
      expect(
        () => runtime.getEmbedding([101, 102, 103]),
        throwsA(isA<StateError>()),
      );
    });

    test('returns 768-dimensional stub embedding after load', () async {
      // NativeOnnxRuntime currently returns zeros (stub implementation)
      await runtime.loadModel('dummy.onnx');
      final embedding = await runtime.getEmbedding([101, 102, 103]);

      expect(embedding.length, equals(768));
      expect(embedding.every((v) => v == 0.0), isTrue);
    });

    test('accepts custom library path', () {
      final customRuntime = NativeOnnxRuntime(
        libraryPath: '/custom/path/libonnxruntime.so',
      );

      expect(customRuntime, isA<NativeOnnxRuntime>());
      customRuntime.dispose();
    });
  });

  group('CloneCandidate', () {
    test('toString formats percentage correctly', () {
      const candidate = CloneCandidate(
        functionId: 'myFunc',
        similarity: 0.95,
      );

      expect(
        candidate.toString(),
        equals('CloneCandidate(myFunc, similarity: 95.0%)'),
      );
    });

    test('toString handles 100% similarity', () {
      const candidate = CloneCandidate(
        functionId: 'func',
        similarity: 1.0,
      );

      expect(
        candidate.toString(),
        equals('CloneCandidate(func, similarity: 100.0%)'),
      );
    });

    test('toString handles low similarity', () {
      const candidate = CloneCandidate(
        functionId: 'lowSim',
        similarity: 0.123,
      );

      expect(
        candidate.toString(),
        equals('CloneCandidate(lowSim, similarity: 12.3%)'),
      );
    });

    test('stores functionId and similarity correctly', () {
      const candidate = CloneCandidate(
        functionId: 'testId',
        similarity: 0.87,
      );

      expect(candidate.functionId, equals('testId'));
      expect(candidate.similarity, equals(0.87));
    });
  });

  group('SemanticCloneDetector integration', () {
    // These tests verify the detector works with MockOnnxRuntime
    // without requiring the real WordPieceTokenizer

    test('MockOnnxRuntime produces similar embeddings for similar inputs', () async {
      final runtime = MockOnnxRuntime();
      await runtime.loadModel('test.onnx');

      // Get embeddings for similar inputs
      final emb1 = await runtime.getEmbedding([100, 101, 102]);
      final emb2 = await runtime.getEmbedding([100, 101, 103]); // slightly different

      final similarity = OnnxRuntime.cosineSimilarity(emb1, emb2);

      // Should be high but not identical
      expect(similarity, greaterThan(0.9));
      expect(similarity, lessThan(1.0));
    });

    test('MockOnnxRuntime embedding similarity is transitive', () async {
      final runtime = MockOnnxRuntime();
      await runtime.loadModel('test.onnx');

      final embA = await runtime.getEmbedding([1, 2, 3]);
      final embB = await runtime.getEmbedding([1, 2, 3]);
      final embC = await runtime.getEmbedding([1, 2, 3]);

      final simAB = OnnxRuntime.cosineSimilarity(embA, embB);
      final simBC = OnnxRuntime.cosineSimilarity(embB, embC);
      final simAC = OnnxRuntime.cosineSimilarity(embA, embC);

      // All should be identical (1.0) for same input, allow floating point tolerance
      expect(simAB, closeTo(1.0, 1e-10));
      expect(simBC, closeTo(1.0, 1e-10));
      expect(simAC, closeTo(1.0, 1e-10));
    });
  });
}
