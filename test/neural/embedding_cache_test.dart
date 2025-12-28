import 'dart:io';

import 'package:test/test.dart';
import 'package:anteater/neural/cache/embedding_cache.dart';

void main() {
  group('EmbeddingCache', () {
    late EmbeddingCache cache;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('embedding_cache_test_').path;
      cache = EmbeddingCache(
        cachePath: '$tempDir/cache.json',
        maxEntries: 5,
      );
    });

    tearDown(() async {
      final dir = Directory(tempDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    group('basic operations', () {
      test('starts empty', () {
        expect(cache.isEmpty, isTrue);
        expect(cache.size, equals(0));
      });

      test('put and get embedding', () {
        final embedding = List.generate(768, (i) => i / 768.0);
        cache.put('func1', 'hash1', embedding);

        expect(cache.size, equals(1));
        expect(cache.isEmpty, isFalse);

        final retrieved = cache.get('func1', 'hash1');
        expect(retrieved, isNotNull);
        expect(retrieved!.length, equals(768));
        expect(retrieved, equals(embedding));
      });

      test('returns null for missing entry', () {
        final result = cache.get('nonexistent', 'hash');
        expect(result, isNull);
      });

      test('invalidates on hash change', () {
        final embedding = List.generate(768, (i) => i.toDouble());
        cache.put('func1', 'hash1', embedding);

        // Same function, different hash
        final result = cache.get('func1', 'hash2');
        expect(result, isNull);

        // Entry should be removed
        expect(cache.size, equals(0));
      });

      test('contains checks function and hash', () {
        final embedding = List.generate(768, (i) => i.toDouble());
        cache.put('func1', 'hash1', embedding);

        expect(cache.contains('func1', 'hash1'), isTrue);
        expect(cache.contains('func1', 'hash2'), isFalse);
        expect(cache.contains('func2', 'hash1'), isFalse);
      });

      test('remove deletes entry', () {
        final embedding = List.generate(768, (i) => i.toDouble());
        cache.put('func1', 'hash1', embedding);
        cache.remove('func1');

        expect(cache.size, equals(0));
        expect(cache.get('func1', 'hash1'), isNull);
      });

      test('clear removes all entries', () {
        final embedding = List.generate(768, (i) => i.toDouble());
        cache.put('func1', 'hash1', embedding);
        cache.put('func2', 'hash2', embedding);
        cache.clear();

        expect(cache.isEmpty, isTrue);
      });

      test('keys returns all function IDs', () {
        final embedding = List.generate(768, (i) => i.toDouble());
        cache.put('func1', 'hash1', embedding);
        cache.put('func2', 'hash2', embedding);

        expect(cache.keys, containsAll(['func1', 'func2']));
      });
    });

    group('LRU eviction', () {
      test('evicts oldest when at capacity', () {
        for (var i = 0; i < 5; i++) {
          cache.put('func$i', 'hash$i', List.generate(768, (j) => j.toDouble()));
        }
        expect(cache.size, equals(5));

        // Add one more, should evict oldest
        cache.put('func5', 'hash5', List.generate(768, (j) => j.toDouble()));
        expect(cache.size, equals(5));
        expect(cache.contains('func0', 'hash0'), isFalse);
        expect(cache.contains('func5', 'hash5'), isTrue);
      });

      test('access updates LRU order', () {
        for (var i = 0; i < 5; i++) {
          cache.put('func$i', 'hash$i', List.generate(768, (j) => j.toDouble()));
        }

        // Access func0 to make it recent
        cache.get('func0', 'hash0');

        // Add new entry, should evict func1 (oldest after func0 was accessed)
        cache.put('func5', 'hash5', List.generate(768, (j) => j.toDouble()));

        expect(cache.contains('func0', 'hash0'), isTrue);
        expect(cache.contains('func1', 'hash1'), isFalse);
      });
    });

    group('persistence', () {
      test('save and load preserves entries', () async {
        final embedding = List.generate(768, (i) => i / 768.0);
        cache.put('func1', 'hash1', embedding);
        cache.put('func2', 'hash2', embedding);
        await cache.save();

        // Create new cache instance and load
        final newCache = EmbeddingCache(
          cachePath: '$tempDir/cache.json',
          maxEntries: 5,
        );
        await newCache.load();

        expect(newCache.size, equals(2));
        expect(newCache.contains('func1', 'hash1'), isTrue);
        expect(newCache.contains('func2', 'hash2'), isTrue);

        final retrieved = newCache.get('func1', 'hash1');
        expect(retrieved, isNotNull);
        expect(retrieved!.length, equals(768));
      });

      test('load handles missing file', () async {
        await cache.load();
        expect(cache.isEmpty, isTrue);
      });

      test('load handles corrupted file', () async {
        final file = File('$tempDir/cache.json');
        await file.parent.create(recursive: true);
        await file.writeAsString('not valid json');

        await cache.load();
        expect(cache.isEmpty, isTrue);
      });

      test('save creates directory if needed', () async {
        final nestedCache = EmbeddingCache(
          cachePath: '$tempDir/nested/deep/cache.json',
          maxEntries: 5,
        );
        nestedCache.put('func1', 'hash1', List.generate(768, (i) => i.toDouble()));
        await nestedCache.save();

        expect(await File('$tempDir/nested/deep/cache.json').exists(), isTrue);
      });
    });

    group('similarity search', () {
      test('finds similar embeddings', () {
        // Create base embedding
        final base = List.generate(768, (i) => i / 768.0);

        // Create similar embedding (slight variation)
        final similar = List.generate(768, (i) => (i + 1) / 769.0);

        // Create different embedding
        final different = List.generate(768, (i) => (768 - i) / 768.0);

        cache.put('base', 'h1', base);
        cache.put('similar', 'h2', similar);
        cache.put('different', 'h3', different);

        final results = cache.findSimilar(base, threshold: 0.9);

        // Should find similar but not different
        expect(results.any((r) => r.functionId == 'similar'), isTrue);
      });

      test('excludes self from results', () {
        final embedding = List.generate(768, (i) => i.toDouble());
        cache.put('func1', 'hash1', embedding);

        final results = cache.findSimilar(
          embedding,
          threshold: 0.5,
          excludeId: 'func1',
        );

        expect(results.where((r) => r.functionId == 'func1'), isEmpty);
      });

      test('respects limit', () {
        // Add many similar embeddings
        for (var i = 0; i < 5; i++) {
          cache.put(
            'func$i',
            'hash$i',
            List.generate(768, (j) => (j + i) / 768.0),
          );
        }

        final query = List.generate(768, (i) => i / 768.0);
        final results = cache.findSimilar(query, threshold: 0.5, limit: 2);

        expect(results.length, lessThanOrEqualTo(2));
      });

      test('sorts by similarity descending', () {
        final base = List.generate(768, (i) => i / 768.0);

        for (var i = 0; i < 3; i++) {
          // Increasingly different embeddings
          final embedding = List.generate(768, (j) => (j + i * 10) / 768.0);
          cache.put('func$i', 'hash$i', embedding);
        }

        final results = cache.findSimilar(base, threshold: 0.5);

        // Should be sorted descending
        for (var i = 0; i < results.length - 1; i++) {
          expect(results[i].similarity, greaterThanOrEqualTo(results[i + 1].similarity));
        }
      });
    });

    group('hash computation', () {
      test('same content produces same hash', () {
        const code = 'void foo() { return 42; }';
        final hash1 = EmbeddingCache.computeHash(code);
        final hash2 = EmbeddingCache.computeHash(code);

        expect(hash1, equals(hash2));
      });

      test('different content produces different hash', () {
        final hash1 = EmbeddingCache.computeHash('void foo() {}');
        final hash2 = EmbeddingCache.computeHash('void bar() {}');

        expect(hash1, isNot(equals(hash2)));
      });

      test('hash is 8 hex characters', () {
        final hash = EmbeddingCache.computeHash('test code');

        expect(hash.length, equals(8));
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
      });
    });

    group('statistics', () {
      test('getStats returns correct values', () {
        final embedding = List.generate(768, (i) => i.toDouble());
        cache.put('func1', 'hash1', embedding);
        cache.put('func2', 'hash2', embedding);

        final stats = cache.getStats();

        expect(stats.entryCount, equals(2));
        expect(stats.maxEntries, equals(5));
        expect(stats.embeddingDimensions, equals(768));
        expect(stats.utilizationPercent, equals(40.0));
      });

      test('getStats handles empty cache', () {
        final stats = cache.getStats();

        expect(stats.entryCount, equals(0));
        expect(stats.embeddingDimensions, equals(0));
      });
    });
  });

  group('SimilarityResult', () {
    test('toString formats correctly', () {
      final result = SimilarityResult(
        functionId: 'testFunc',
        similarity: 0.95,
      );

      expect(result.toString(), equals('SimilarityResult(testFunc, 95.0%)'));
    });
  });

  group('CacheStats', () {
    test('toString formats correctly', () {
      const stats = CacheStats(
        entryCount: 50,
        maxEntries: 100,
        embeddingDimensions: 768,
      );

      expect(stats.toString(), equals('CacheStats(entries: 50/100, dims: 768)'));
    });

    test('utilizationPercent calculates correctly', () {
      const stats = CacheStats(
        entryCount: 25,
        maxEntries: 100,
        embeddingDimensions: 768,
      );

      expect(stats.utilizationPercent, equals(25.0));
    });
  });
}
