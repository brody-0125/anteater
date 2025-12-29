import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// ONNX Runtime C API type definitions.
///
/// Reference: https://onnxruntime.ai/docs/api/c/
///
/// This file contains FFI bindings for the ONNX Runtime C API.
/// The actual native library must be provided at runtime.

// ONNX Runtime opaque pointer types
typedef OrtEnv = Void;
typedef OrtSession = Void;
typedef OrtSessionOptions = Void;
typedef OrtRunOptions = Void;
typedef OrtValue = Void;
typedef OrtMemoryInfo = Void;
typedef OrtAllocator = Void;
typedef OrtApi = Void;
typedef OrtStatus = Void;

// ONNX tensor element types
abstract class OnnxTensorElementType {
  static const int undefined = 0;
  static const int float32 = 1;
  static const int uint8 = 2;
  static const int int8 = 3;
  static const int uint16 = 4;
  static const int int16 = 5;
  static const int int32 = 6;
  static const int int64 = 7;
  static const int string = 8;
  static const int bool_ = 9;
  static const int float16 = 10;
  static const int float64 = 11;
  static const int uint32 = 12;
  static const int uint64 = 13;
}

/// FFI function type definitions for ONNX Runtime C API.
///
/// These match the function signatures in onnxruntime_c_api.h

// OrtApi* OrtGetApiBase()->GetApi(ORT_API_VERSION)
typedef OrtGetApiBaseNative = Pointer<OrtApi> Function();
typedef OrtGetApiBaseDart = Pointer<OrtApi> Function();

// OrtStatus* CreateEnv(OrtLoggingLevel level, const char* logid, OrtEnv** out)
typedef OrtCreateEnvNative = Pointer<OrtStatus> Function(
  Int32 logLevel,
  Pointer<Utf8> logId,
  Pointer<Pointer<OrtEnv>> out,
);
typedef OrtCreateEnvDart = Pointer<OrtStatus> Function(
  int logLevel,
  Pointer<Utf8> logId,
  Pointer<Pointer<OrtEnv>> out,
);

// OrtStatus* CreateSessionOptions(OrtSessionOptions** out)
typedef OrtCreateSessionOptionsNative = Pointer<OrtStatus> Function(
  Pointer<Pointer<OrtSessionOptions>> out,
);
typedef OrtCreateSessionOptionsDart = Pointer<OrtStatus> Function(
  Pointer<Pointer<OrtSessionOptions>> out,
);

// OrtStatus* CreateSession(OrtEnv*, const char* model_path, OrtSessionOptions*, OrtSession**)
typedef OrtCreateSessionNative = Pointer<OrtStatus> Function(
  Pointer<OrtEnv> env,
  Pointer<Utf8> modelPath,
  Pointer<OrtSessionOptions> options,
  Pointer<Pointer<OrtSession>> out,
);
typedef OrtCreateSessionDart = Pointer<OrtStatus> Function(
  Pointer<OrtEnv> env,
  Pointer<Utf8> modelPath,
  Pointer<OrtSessionOptions> options,
  Pointer<Pointer<OrtSession>> out,
);

// OrtStatus* CreateTensorWithDataAsOrtValue(...)
typedef OrtCreateTensorNative = Pointer<OrtStatus> Function(
  Pointer<OrtMemoryInfo> info,
  Pointer<Void> data,
  Size dataLength,
  Pointer<Int64> shape,
  Size shapeLength,
  Int32 elementType,
  Pointer<Pointer<OrtValue>> out,
);
typedef OrtCreateTensorDart = Pointer<OrtStatus> Function(
  Pointer<OrtMemoryInfo> info,
  Pointer<Void> data,
  int dataLength,
  Pointer<Int64> shape,
  int shapeLength,
  int elementType,
  Pointer<Pointer<OrtValue>> out,
);

// OrtStatus* Run(OrtSession*, OrtRunOptions*, ...)
typedef OrtRunNative = Pointer<OrtStatus> Function(
  Pointer<OrtSession> session,
  Pointer<OrtRunOptions> runOptions,
  Pointer<Pointer<Utf8>> inputNames,
  Pointer<Pointer<OrtValue>> inputValues,
  Size inputCount,
  Pointer<Pointer<Utf8>> outputNames,
  Size outputCount,
  Pointer<Pointer<OrtValue>> outputValues,
);
typedef OrtRunDart = Pointer<OrtStatus> Function(
  Pointer<OrtSession> session,
  Pointer<OrtRunOptions> runOptions,
  Pointer<Pointer<Utf8>> inputNames,
  Pointer<Pointer<OrtValue>> inputValues,
  int inputCount,
  Pointer<Pointer<Utf8>> outputNames,
  int outputCount,
  Pointer<Pointer<OrtValue>> outputValues,
);

// OrtStatus* GetTensorMutableData(OrtValue*, void**)
typedef OrtGetTensorDataNative = Pointer<OrtStatus> Function(
  Pointer<OrtValue> value,
  Pointer<Pointer<Void>> out,
);
typedef OrtGetTensorDataDart = Pointer<OrtStatus> Function(
  Pointer<OrtValue> value,
  Pointer<Pointer<Void>> out,
);

// void ReleaseSession(OrtSession*)
typedef OrtReleaseSessionNative = Void Function(Pointer<OrtSession> session);
typedef OrtReleaseSessionDart = void Function(Pointer<OrtSession> session);

// void ReleaseEnv(OrtEnv*)
typedef OrtReleaseEnvNative = Void Function(Pointer<OrtEnv> env);
typedef OrtReleaseEnvDart = void Function(Pointer<OrtEnv> env);

// void ReleaseValue(OrtValue*)
typedef OrtReleaseValueNative = Void Function(Pointer<OrtValue> value);
typedef OrtReleaseValueDart = void Function(Pointer<OrtValue> value);

// void ReleaseStatus(OrtStatus*)
typedef OrtReleaseStatusNative = Void Function(Pointer<OrtStatus> status);
typedef OrtReleaseStatusDart = void Function(Pointer<OrtStatus> status);

// const char* GetErrorMessage(OrtStatus*)
typedef OrtGetErrorMessageNative = Pointer<Utf8> Function(
  Pointer<OrtStatus> status,
);
typedef OrtGetErrorMessageDart = Pointer<Utf8> Function(
  Pointer<OrtStatus> status,
);

/// Logging levels for ONNX Runtime.
abstract class OrtLoggingLevel {
  static const int verbose = 0;
  static const int info = 1;
  static const int warning = 2;
  static const int error = 3;
  static const int fatal = 4;
}

/// ONNX Runtime FFI bindings.
///
/// This class provides low-level FFI access to the ONNX Runtime C API.
/// For high-level usage, see [OnnxRuntime] in onnx_runtime.dart.
class OnnxFfi {
  OnnxFfi._(this._lib);

  final DynamicLibrary _lib;

  late final OrtGetApiBaseDart getApiBase;
  late final OrtCreateEnvDart createEnv;
  late final OrtCreateSessionOptionsDart createSessionOptions;
  late final OrtCreateSessionDart createSession;
  late final OrtCreateTensorDart createTensor;
  late final OrtRunDart run;
  late final OrtGetTensorDataDart getTensorData;
  late final OrtReleaseSessionDart releaseSession;
  late final OrtReleaseEnvDart releaseEnv;
  late final OrtReleaseValueDart releaseValue;
  late final OrtReleaseStatusDart releaseStatus;
  late final OrtGetErrorMessageDart getErrorMessage;

  /// Loads the ONNX Runtime library from the specified path.
  ///
  /// Throws [OnnxLoadException] if the library cannot be loaded.
  static OnnxFfi load(String libraryPath) {
    try {
      final lib = DynamicLibrary.open(libraryPath);
      final ffi = OnnxFfi._(lib);
      ffi._bindFunctions();
      return ffi;
    } on ArgumentError catch (e) {
      throw OnnxLoadException(
        'Failed to load ONNX Runtime from $libraryPath: $e',
      );
    }
  }

  /// Attempts to load ONNX Runtime from default locations.
  ///
  /// Searches in:
  /// 1. Current directory
  /// 2. System library paths
  /// 3. Common installation locations
  static OnnxFfi? tryLoadDefault() {
    final paths = _getDefaultLibraryPaths();

    for (final path in paths) {
      try {
        return load(path);
      } on OnnxLoadException {
        // Try next path
        continue;
      }
    }

    return null;
  }

  static List<String> _getDefaultLibraryPaths() {
    if (Platform.isMacOS) {
      return [
        'libonnxruntime.dylib',
        '/usr/local/lib/libonnxruntime.dylib',
        '/opt/homebrew/lib/libonnxruntime.dylib',
      ];
    } else if (Platform.isLinux) {
      return [
        'libonnxruntime.so',
        '/usr/lib/libonnxruntime.so',
        '/usr/local/lib/libonnxruntime.so',
      ];
    } else if (Platform.isWindows) {
      return [
        'onnxruntime.dll',
        r'C:\Program Files\onnxruntime\lib\onnxruntime.dll',
      ];
    }

    return [];
  }

  void _bindFunctions() {
    // Note: The actual ONNX Runtime C API uses an API struct approach.
    // This is a simplified version - full implementation would need to:
    // 1. Call OrtGetApiBase() to get the base API
    // 2. Call GetApi(version) on the base to get the versioned API struct
    // 3. Access functions through the API struct

    // For now, we attempt direct symbol lookup which works for some builds
    try {
      releaseStatus = _lib
          .lookupFunction<OrtReleaseStatusNative, OrtReleaseStatusDart>(
            'OrtReleaseStatus',
          );
      getErrorMessage = _lib
          .lookupFunction<OrtGetErrorMessageNative, OrtGetErrorMessageDart>(
            'OrtGetErrorMessage',
          );
    } catch (e) {
      // Functions may not be directly exported; full implementation needed
      throw OnnxLoadException(
        'ONNX Runtime API functions not found. '
        'This may require a different binding approach.',
      );
    }
  }

  /// Checks an OrtStatus and throws if it indicates an error.
  void checkStatus(Pointer<OrtStatus> status) {
    if (status == nullptr) return;

    final message = getErrorMessage(status).toDartString();
    releaseStatus(status);
    throw OnnxRuntimeException(message);
  }
}

/// Exception thrown when ONNX Runtime library cannot be loaded.
class OnnxLoadException implements Exception {
  OnnxLoadException(this.message);

  final String message;

  @override
  String toString() => 'OnnxLoadException: $message';
}

/// Exception thrown during ONNX Runtime operations.
class OnnxRuntimeException implements Exception {
  OnnxRuntimeException(this.message);

  final String message;

  @override
  String toString() => 'OnnxRuntimeException: $message';
}

/// Helper class for managing ONNX tensor memory.
class OnnxTensor {
  OnnxTensor._({
    required this.data,
    required this.shape,
    required this.elementCount,
  });

  /// Creates a tensor from a list of floats.
  factory OnnxTensor.fromList(List<double> values, List<int> shape) {
    final expectedCount = shape.fold<int>(1, (a, b) => a * b);
    if (values.length != expectedCount) {
      throw ArgumentError(
        'Value count ${values.length} does not match shape $shape '
        '(expected $expectedCount)',
      );
    }

    final data = calloc<Float>(values.length);
    for (var i = 0; i < values.length; i++) {
      data[i] = values[i];
    }

    return OnnxTensor._(
      data: data,
      shape: shape,
      elementCount: values.length,
    );
  }

  /// Creates a tensor for BERT-style input IDs.
  factory OnnxTensor.fromInputIds(List<int> inputIds) {
    final data = calloc<Float>(inputIds.length);
    for (var i = 0; i < inputIds.length; i++) {
      data[i] = inputIds[i].toDouble();
    }

    return OnnxTensor._(
      data: data,
      shape: [1, inputIds.length], // Batch size 1
      elementCount: inputIds.length,
    );
  }

  final Pointer<Float> data;
  final List<int> shape;
  final int elementCount;

  /// Extracts data as a list of doubles.
  List<double> toList() {
    final result = <double>[];
    for (var i = 0; i < elementCount; i++) {
      result.add(data[i]);
    }
    return result;
  }

  /// Frees the native memory.
  void dispose() {
    calloc.free(data);
  }
}

// Note: Use `string.toNativeUtf8()` from package:ffi for string conversion.
// The ffi package already provides this extension method.
