import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import '../inference/onnx_runtime.dart';

/// Persistent embedding cache with content-based invalidation.
///
/// Features:
/// - Disk persistence via JSON serialization
/// - Content hash-based cache invalidation
/// - LRU eviction when cache exceeds size limit
/// - Fast similarity search across all cached embeddings
class EmbeddingCache {
  final String _cachePath;
  final int _maxEntries;

  /// Maps function ID to cached embedding entry.
  /// Uses LinkedHashMap for O(1) LRU operations (ADR-016 1.1).
  /// Insertion order is maintained, so oldest entries are at the front.
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();

  EmbeddingCache({
    required String cachePath,
    int maxEntries = 10000,
  })  : _cachePath = cachePath,
        _maxEntries = maxEntries;

  /// Number of cached entries.
  int get size => _cache.length;

  /// Maximum number of entries before eviction.
  int get maxEntries => _maxEntries;

  /// Whether the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// All cached function IDs.
  Iterable<String> get keys => _cache.keys;

  /// Loads cache from disk if it exists.
  Future<void> load() async {
    final file = File(_cachePath);
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final entries = json['entries'] as List<dynamic>;

      _cache.clear();

      // ADR-016 1.1: LinkedHashMap maintains insertion order
      for (final entry in entries) {
        final map = entry as Map<String, dynamic>;
        final id = map['id'] as String;
        _cache[id] = _CacheEntry.fromJson(map);
      }
    } on FormatException {
      // Invalid cache file, ignore and start fresh
      _cache.clear();
    }
  }

  /// Saves cache to disk.
  Future<void> save() async {
    final file = File(_cachePath);
    final dir = file.parent;

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final entries = _cache.entries.map((e) => e.value.toJson(e.key)).toList();
    final json = jsonEncode({'entries': entries, 'version': 1});
    await file.writeAsString(json);
  }

  /// Gets embedding for a function, or null if not cached or invalidated.
  ///
  /// Returns null if:
  /// - Function is not in cache
  /// - Content hash has changed (code was modified)
  ///
  /// ADR-016 1.1: Uses O(1) LinkedHashMap operations for LRU.
  List<double>? get(String functionId, String contentHash) {
    // O(1) remove - returns the entry if it exists
    final entry = _cache.remove(functionId);
    if (entry == null) return null;

    // Check if content has changed
    if (entry.contentHash != contentHash) {
      // Stale entry, don't re-add
      return null;
    }

    // O(1) add to end (most recently used)
    _cache[functionId] = entry;

    return entry.embedding;
  }

  /// Stores embedding for a function.
  ///
  /// ADR-016 1.1: Uses O(1) LinkedHashMap operations.
  void put(String functionId, String contentHash, List<double> embedding) {
    // O(1) remove if already exists (to update position)
    _cache.remove(functionId);

    // O(1) evict oldest entries if at capacity
    while (_cache.length >= _maxEntries && _cache.isNotEmpty) {
      _cache.remove(_cache.keys.first);
    }

    // O(1) add to end (most recently used)
    _cache[functionId] = _CacheEntry(
      contentHash: contentHash,
      embedding: List.unmodifiable(embedding),
    );
  }

  /// Removes a function from the cache.
  void remove(String functionId) {
    _cache.remove(functionId);
  }

  /// Clears all cached entries.
  void clear() {
    _cache.clear();
  }

  /// Checks if a function is cached with the given content hash.
  bool contains(String functionId, String contentHash) {
    final entry = _cache[functionId];
    return entry != null && entry.contentHash == contentHash;
  }

  /// Finds all functions with similarity above threshold.
  ///
  /// Returns a list of (functionId, similarity) pairs sorted by
  /// similarity descending.
  List<SimilarityResult> findSimilar(
    List<double> queryEmbedding, {
    double threshold = 0.85,
    int limit = 10,
    String? excludeId,
  }) {
    final results = <SimilarityResult>[];

    for (final entry in _cache.entries) {
      if (entry.key == excludeId) continue;

      final similarity = OnnxRuntime.cosineSimilarity(
        queryEmbedding,
        entry.value.embedding,
      );

      if (similarity >= threshold) {
        results.add(SimilarityResult(
          functionId: entry.key,
          similarity: similarity,
        ));
      }
    }

    // Sort by similarity descending
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    // Apply limit
    if (results.length > limit) {
      return results.sublist(0, limit);
    }

    return results;
  }

  /// Computes content hash for cache invalidation.
  ///
  /// Uses a simple hash of the code content. Changes in whitespace
  /// or comments will trigger invalidation.
  static String computeHash(String code) {
    // Simple FNV-1a hash
    var hash = 2166136261;
    for (var i = 0; i < code.length; i++) {
      hash ^= code.codeUnitAt(i);
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Gets cache statistics.
  CacheStats getStats() {
    return CacheStats(
      entryCount: _cache.length,
      maxEntries: _maxEntries,
      embeddingDimensions: _cache.isEmpty ? 0 : _cache.values.first.embedding.length,
    );
  }
}

/// A cached embedding entry.
class _CacheEntry {
  final String contentHash;
  final List<double> embedding;

  _CacheEntry({
    required this.contentHash,
    required this.embedding,
  });

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    return _CacheEntry(
      contentHash: json['hash'] as String,
      embedding: (json['embedding'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toJson(String id) {
    return {
      'id': id,
      'hash': contentHash,
      'embedding': embedding,
    };
  }
}

/// Result of a similarity search.
class SimilarityResult {
  final String functionId;
  final double similarity;

  const SimilarityResult({
    required this.functionId,
    required this.similarity,
  });

  @override
  String toString() =>
      'SimilarityResult($functionId, ${(similarity * 100).toStringAsFixed(1)}%)';
}

/// Cache statistics.
class CacheStats {
  final int entryCount;
  final int maxEntries;
  final int embeddingDimensions;

  const CacheStats({
    required this.entryCount,
    required this.maxEntries,
    required this.embeddingDimensions,
  });

  double get utilizationPercent => entryCount / maxEntries * 100;

  @override
  String toString() =>
      'CacheStats(entries: $entryCount/$maxEntries, dims: $embeddingDimensions)';
}
