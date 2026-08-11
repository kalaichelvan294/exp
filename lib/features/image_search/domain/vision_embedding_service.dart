import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

class VisionEmbeddingService {
  VisionEmbeddingService._();

  static final VisionEmbeddingService instance = VisionEmbeddingService._();

  static const String _assetPath = 'assets/models/vision_model_512.onnx';
  static const int _inputSize = 112;

  bool _envInitialized = false;
  OrtSession? _session;
  String? _inputName;
  String? _outputName;
  Future<void>? _loading;

  Future<void> _ensureLoaded() async {
    if (_session != null) return;
    final pending = _loading;
    if (pending != null) {
      await pending;
      return;
    }

    final loader = _load();
    _loading = loader;
    try {
      await loader;
    } finally {
      _loading = null;
    }
  }

  Future<void> _load() async {
    if (!_envInitialized) {
      OrtEnv.instance.init(level: OrtLoggingLevel.error, logId: 'Vision');
      _envInitialized = true;
    }

    final modelBytes = (await rootBundle.load(_assetPath)).buffer.asUint8List();
    final options = OrtSessionOptions();
    options.setIntraOpNumThreads(1);
    _session = OrtSession.fromBuffer(modelBytes, options);
    options.release();
    _inputName = _session!.inputNames.first;
    _outputName = _session!.outputNames.first;
  }

  Future<List<double>> embedImage(Uint8List bytes, {int? inputSize}) async {
    await _ensureLoaded();
    final size = inputSize ?? _inputSize;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unsupported image format.');
    }

    final resized = img.copyResize(
      decoded,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    final rgba = resized.getBytes(order: img.ChannelOrder.rgba);
    final area = size * size;
    final data = Float32List(area * 3);
    const mean = 127.5;
    const scale = 1.0 / 128.0;

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final pixelIndex = (y * size + x) * 4;
        final base = y * size + x;
        final r = rgba[pixelIndex].toDouble();
        final g = rgba[pixelIndex + 1].toDouble();
        final b = rgba[pixelIndex + 2].toDouble();
        data[base] = (r - mean) * scale;
        data[area + base] = (g - mean) * scale;
        data[area * 2 + base] = (b - mean) * scale;
      }
    }

    final session = _session!;
    final inputName = _inputName!;
    final outputName = _outputName!;
    final input = OrtValueTensor.createTensorWithDataList(
      [data],
      [1, 3, size, size],
    );
    final runOptions = OrtRunOptions();
    OrtValueTensor? output;
    try {
      final outputs = session.run(runOptions, {inputName: input}, [outputName]);
      final candidate = outputs.first;
      if (candidate is! OrtValueTensor) {
        throw StateError('Model output was not a tensor.');
      }
      output = candidate;
      final raw = output.value;
      final vector = _flattenTensor(raw);
      return _l2Normalize(vector);
    } finally {
      output?.release();
      input.release();
      runOptions.release();
    }
  }

  List<double> _flattenTensor(Object? value) {
    if (value is List) {
      if (value.isNotEmpty && value.first is List) {
        return (value.first as List).map((e) => (e as num).toDouble()).toList();
      }
      return value.map((e) => (e as num).toDouble()).toList();
    }
    if (value is num) return <double>[value.toDouble()];
    throw StateError('Unexpected tensor output.');
  }

  List<double> _l2Normalize(List<double> values) {
    var sum = 0.0;
    for (final value in values) {
      sum += value * value;
    }
    final norm = math.sqrt(sum);
    if (norm == 0) return values;
    return values.map((value) => value / norm).toList(growable: false);
  }
}
