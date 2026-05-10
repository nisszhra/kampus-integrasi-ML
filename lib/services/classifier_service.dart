import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ClassifierService {
  Interpreter? _interpreter;
  List<String>? _labels;
  static const int inputSize = 224;
  bool _isReady = false;

  bool get isReady => _isReady;

  /// Load model dan labels dari assets
  Future<void> loadModel() async {
    try {
      // fromAsset() memerlukan path SAMA PERSIS dengan yang di pubspec.yaml
      _interpreter = await Interpreter.fromAsset('assets/ml/model.tflite');
      final labelData = await rootBundle.loadString('assets/ml/labels.txt');
      _labels = labelData.split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.replaceAll(RegExp(r'^\d+\s*'), ''))
          .toList();
      _isReady = true;
      print('Model loaded successfully. Labels: $_labels');
    } catch (e) {
      print('Error loading model: $e');
      _isReady = false;
      rethrow;
    }
  }

  /// Konversi img.Image ke buffer input (Float32List atau Uint8List)
  List _imageToInputBuffer(img.Image image) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);
    final inputType = _interpreter!.getInputTensor(0).type;

    if (inputType == TensorType.uint8) {
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
          // Normalisasi 0-255 ke 0.0-1.0
          buf[idx++] = p.r / 255.0;
          buf[idx++] = p.g / 255.0;
          buf[idx++] = p.b / 255.0;
        }
      }
      return buf;
    }
  }

  /// Jalankan inferensi dari buffer input
  Map<String, double> _runInference(List inputBuffer) {
    final input = inputBuffer.reshape([1, inputSize, inputSize, 3]);
    
    final outputType = _interpreter!.getOutputTensor(0).type;
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    var output;
    
    if (outputType == TensorType.uint8) {
      output = Uint8List(outputShape.reduce((a, b) => a * b)).reshape(outputShape);
    } else {
      output = Float32List(outputShape.reduce((a, b) => a * b)).reshape(outputShape);
    }
    
    _interpreter!.run(input, output);

    final results = <String, double>{};
    for (int i = 0; i < _labels!.length; i++) {
      if (outputType == TensorType.uint8) {
        // Normalisasi probabilitas jika uint8 (0-255)
        results[_labels![i]] = output[0][i] / 255.0;
      } else {
        results[_labels![i]] = output[0][i];
      }
    }

    return Map.fromEntries(results.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));
  }

  /// Klasifikasi dari file gambar (untuk mode galeri/kamera)
  Future<Map<String, double>> classify(File imageFile) async {
    if (!_isReady || _interpreter == null || _labels == null) {
      throw Exception('Model belum dimuat. Panggil loadModel() terlebih dahulu.');
    }

    final buffer = await Future(() {
      final raw = img.decodeImage(imageFile.readAsBytesSync())!;
      return _imageToInputBuffer(raw);
    });

    return _runInference(buffer);
  }

  /// Konversi CameraImage (YUV420) ke img.Image
  img.Image _convertCameraImage(CameraImage camImg) {
    final width = camImg.width;
    final height = camImg.height;
    final image = img.Image(width: width, height: height);

    // YUV420 format (Android)
    final yPlane = camImg.planes[0];
    final uPlane = camImg.planes[1];
    final vPlane = camImg.planes[2];

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final yVal = yPlane.bytes[yIndex];
        final uVal = uPlane.bytes[uvIndex];
        final vVal = vPlane.bytes[uvIndex];

        // YUV -> RGB conversion
        int r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
        int g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128))
            .round().clamp(0, 255);
        int b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  /// Klasifikasi dari CameraImage (untuk mode realtime)
  Map<String, double> classifyFromCameraImage(CameraImage camImg) {
    if (!_isReady || _interpreter == null || _labels == null) {
      return {};
    }

    final image = _convertCameraImage(camImg);
    final buffer = _imageToInputBuffer(image);
    return _runInference(buffer);
  }

  void dispose() {
    _interpreter?.close();
  }
}