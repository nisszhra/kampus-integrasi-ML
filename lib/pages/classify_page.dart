import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/classifier_service.dart';

class ClassifyPage extends StatefulWidget {
  @override
  State<ClassifyPage> createState() => _ClassifyPageState();
}

class _ClassifyPageState extends State<ClassifyPage> {
  final _classifier = ClassifierService();
  final _picker = ImagePicker();
  File? _selectedImage;
  Map<String, double>? _results;
  bool _isLoading = false;
  bool _modelLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  /// Inisialisasi model dengan await dan error handling
  Future<void> _initModel() async {
    try {
      await _classifier.loadModel();
      setState(() {
        _modelLoading = false;
      });
    } catch (e) {
      setState(() {
        _modelLoading = false;
        _errorMessage = 'Gagal memuat model: $e';
      });
    }
  }

  Future<void> _pickAndClassify(ImageSource src) async {
    final picked = await _picker.pickImage(source: src);
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _isLoading = true;
      _results = null;
      _errorMessage = null;
    });

    try {
      // classify() sekarang async, jadi UI thread tidak terblokir
      final res = await _classifier.classify(_selectedImage!);
      setState(() {
        _results = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mengklasifikasi gambar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Classifier')),
      body: _modelLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat model...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(children: [
                if (_errorMessage != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 12),
                        Expanded(child: Text(_errorMessage!,
                            style: TextStyle(color: Colors.red.shade800))),
                      ]),
                    ),
                  ),
                if (_selectedImage != null) ...[
                  SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_selectedImage!,
                        height: 250, fit: BoxFit.cover)),
                ],
                SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _pickAndClassify(ImageSource.camera),
                    icon: Icon(Icons.camera_alt),
                    label: Text('Kamera')),
                  SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _pickAndClassify(ImageSource.gallery),
                    icon: Icon(Icons.photo_library),
                    label: Text('Galeri')),
                ]),
                SizedBox(height: 24),
                if (_isLoading)
                  Column(children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Mengklasifikasi gambar...'),
                  ]),
                if (_results != null)
                  ..._results!.entries.map((e) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(e.key,
                          style: TextStyle(fontWeight: FontWeight.w600))),
                      Expanded(flex: 7, child: LinearProgressIndicator(
                          value: e.value, minHeight: 12,
                          borderRadius: BorderRadius.circular(6))),
                      SizedBox(width: 8),
                      Text('${(e.value * 100).toStringAsFixed(1)}%'),
                    ]))),
              ]),
            ),
    );
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }
}