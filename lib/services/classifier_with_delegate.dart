import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

enum DelegateType { cpu, gpu, nnapi }

// Kelas model untuk menyimpan hasil benchmark
class BenchmarkSummary {
  final DelegateType delegate;
  final double avgTimeMs;
  final double minTimeMs;
  final double maxTimeMs;
  final int totalRuns;
  final int successRuns;
  final String? error;

  BenchmarkSummary({
    required this.delegate,
    required this.avgTimeMs,
    required this.minTimeMs,
    required this.maxTimeMs,
    required this.totalRuns,
    required this.successRuns,
    this.error,
  });
}

class ClassifierWithDelegate {
  static const int inputSize = 224;

  Future<Interpreter> _createInterpreter(DelegateType delegate) async {
    final options = InterpreterOptions();
    try {
      switch (delegate) {
        case DelegateType.gpu:
          options.addDelegate(GpuDelegateV2());
          break;
        case DelegateType.nnapi:
          options.useNnApiForAndroid = true;
          break;
        case DelegateType.cpu:
          options.threads = 4;
          break;
      }
    } catch (e) {
      print("Delegate $delegate not supported: $e");
    }

    return await Interpreter.fromAsset(
      'assets/ml/model.tflite',
      options: options,
    );
  }

  // Fungsi untuk memproses gambar menjadi input model (Float32 atau Uint8)
  List _preprocess(File imageFile, TensorType type) {
    final raw = img.decodeImage(imageFile.readAsBytesSync())!;
    final resized = img.copyResize(raw, width: inputSize, height: inputSize);
    
    if (type == TensorType.uint8) {
      var buf = Uint8List(1 * inputSize * inputSize * 3);
      int idx = 0;
      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          final p = resized.getPixel(x, y);
          buf[idx++] = p.r.toInt();
          buf[idx++] = p.g.toInt();
          buf[idx++] = p.b.toInt();
        }
      }
      return buf;
    } else {
      var buf = Float32List(1 * inputSize * inputSize * 3);
      int idx = 0;
      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          final p = resized.getPixel(x, y);
          buf[idx++] = p.r / 255.0;
          buf[idx++] = p.g / 255.0;
          buf[idx++] = p.b / 255.0;
        }
      }
      return buf;
    }
  }

  // FUNGSI UTAMA: Menjalankan Benchmark
  Future<List<BenchmarkSummary>> runBenchmark(
    File imageFile, {
    int iterations = 10,
    Function(DelegateType delegate, int current, int total)? onProgress,
  }) async {
    final List<BenchmarkSummary> summaries = [];
    // Cek tipe model terlebih dahulu
    final tempInterpreter = await Interpreter.fromAsset('assets/ml/model.tflite');
    final inputType = tempInterpreter.getInputTensor(0).type;
    final outputType = tempInterpreter.getOutputTensor(0).type;
    final outputShape = tempInterpreter.getOutputTensor(0).shape;
    tempInterpreter.close();

    final input = _preprocess(imageFile, inputType).reshape([1, inputSize, inputSize, 3]);

    for (var delegate in DelegateType.values) {
      Interpreter? interpreter;
      try {
        interpreter = await _createInterpreter(delegate);
        
        // Output placeholder adaptif
        var output;
        if (outputType == TensorType.uint8) {
          output = Uint8List(outputShape.reduce((a, b) => a * b)).reshape(outputShape);
        } else {
          output = Float32List(outputShape.reduce((a, b) => a * b)).reshape(outputShape);
        }

        // 1. Warmup
        interpreter.run(input, output);

        List<double> times = [];
        int successCount = 0;

        // 2. Loop Iterasi
        for (int i = 1; i <= iterations; i++) {
          onProgress?.call(delegate, i, iterations);
          
          final stopwatch = Stopwatch()..start();
          interpreter.run(input, output);
          stopwatch.stop();
          
          times.add(stopwatch.elapsedMicroseconds / 1000.0); // Simpan dalam ms
          successCount++;
        }

        summaries.add(BenchmarkSummary(
          delegate: delegate,
          avgTimeMs: times.reduce((a, b) => a + b) / times.length,
          minTimeMs: times.reduce((a, b) => a < b ? a : b),
          maxTimeMs: times.reduce((a, b) => a > b ? a : b),
          totalRuns: iterations,
          successRuns: successCount,
        ));
      } catch (e) {
        summaries.add(BenchmarkSummary(
          delegate: delegate,
          avgTimeMs: 0, minTimeMs: 0, maxTimeMs: 0,
          totalRuns: iterations,
          successRuns: 0,
          error: e.toString(),
        ));
      } finally {
        interpreter?.close();
      }
    }
    return summaries;
  }
}
