import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/classifier_with_delegate.dart';

class BenchmarkPage extends StatefulWidget {
  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage>
    with SingleTickerProviderStateMixin {
  final _classifier = ClassifierWithDelegate();
  final _picker = ImagePicker();
  File? _selectedImage;
  List<BenchmarkSummary>? _results;
  bool _isRunning = false;
  String _progressText = '';
  int _iterations = 10;

  // Warna dan ikon per delegate
  static const _delegateInfo = {
    DelegateType.cpu: {
      'label': 'CPU',
      'icon': Icons.memory,
      'color': Colors.blue,
      'desc': 'Default, kompatibel semua perangkat',
    },
    DelegateType.gpu: {
      'label': 'GPU',
      'icon': Icons.graphic_eq,
      'color': Colors.green,
      'desc': 'Akselerasi GPU via OpenGL/OpenCL',
    },
    DelegateType.nnapi: {
      'label': 'NNAPI',
      'icon': Icons.developer_board,
      'color': Colors.orange,
      'desc': 'Android Neural Networks API',
    },
  };

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _selectedImage = File(picked.path);
      _results = null;
    });
  }

  Future<void> _runBenchmark() async {
    if (_selectedImage == null) return;

    setState(() {
      _isRunning = true;
      _results = null;
      _progressText = 'Memulai benchmark...';
    });

    try {
      final results = await _classifier.runBenchmark(
        _selectedImage!,
        iterations: _iterations,
        onProgress: (delegate, current, total) {
          setState(() {
            final label = _delegateInfo[delegate]!['label'] as String;
            _progressText = '$label: $current / $total';
          });
        },
      );

      setState(() {
        _results = results;
        _isRunning = false;
        _progressText = '';
      });
    } catch (e) {
      setState(() {
        _isRunning = false;
        _progressText = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Benchmark Performa')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.primary),
                      SizedBox(width: 8),
                      Text('Tentang Benchmark',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    SizedBox(height: 8),
                    Text(
                      'Bandingkan kecepatan inferensi model TFLite menggunakan '
                      'delegate berbeda. Setiap delegate akan dijalankan '
                      '$_iterations kali setelah 1x warmup.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Pilih gambar
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_selectedImage!,
                    height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isRunning ? null : _pickImage,
                  icon: Icon(Icons.photo_library),
                  label: Text(_selectedImage == null
                      ? 'Pilih Gambar'
                      : 'Ganti Gambar'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      (_isRunning || _selectedImage == null) ? null : _runBenchmark,
                  icon: _isRunning
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.speed),
                  label: Text(_isRunning ? 'Running...' : 'Jalankan'),
                ),
              ),
            ]),

            // Slider iterasi
            SizedBox(height: 8),
            Row(children: [
              Text('Iterasi: ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _iterations.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '$_iterations',
                  onChanged: _isRunning
                      ? null
                      : (v) => setState(() => _iterations = v.toInt()),
                ),
              ),
              Text('$_iterations',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ]),

            // Progress
            if (_isRunning && _progressText.isNotEmpty) ...[
              SizedBox(height: 12),
              Center(
                child: Text(_progressText,
                    style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500)),
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(borderRadius: BorderRadius.circular(4)),
            ],

            // Hasil benchmark
            if (_results != null) ...[
              SizedBox(height: 24),
              Text('Hasil Benchmark',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('$_iterations iterasi per delegate',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              SizedBox(height: 16),

              // Bar chart visual
              _buildBarChart(),
              SizedBox(height: 20),

              // Detail cards
              ..._results!.map((r) => _buildResultCard(r)),

              // Tabel perbandingan
              SizedBox(height: 20),
              _buildComparisonTable(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final successResults =
        _results!.where((r) => r.successRuns > 0).toList();
    if (successResults.isEmpty) return SizedBox.shrink();

    final maxTime =
        successResults.map((r) => r.maxTimeMs).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Waktu Rata-rata Inferensi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 16),
            ...successResults.map((r) {
              final info = _delegateInfo[r.delegate]!;
              final color = info['color'] as Color;
              final label = info['label'] as String;
              final ratio = maxTime > 0 ? r.avgTimeMs / maxTime : 0.0;

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(info['icon'] as IconData, size: 18, color: color),
                      SizedBox(width: 8),
                      Text(label,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Spacer(),
                      Text('${r.avgTimeMs.toStringAsFixed(2)} ms',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: color)),
                    ]),
                    SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 16,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(BenchmarkSummary r) {
    final info = _delegateInfo[r.delegate]!;
    final color = info['color'] as Color;
    final label = info['label'] as String;
    final desc = info['desc'] as String;

    if (r.error != null) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade50,
            child: Icon(info['icon'] as IconData, color: Colors.red),
          ),
          title: Text(label),
          subtitle: Text('❌ Tidak didukung: ${r.error}',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(info['icon'] as IconData, color: color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(desc,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ]),
            SizedBox(height: 16),
            Row(children: [
              _buildStatBox('Avg', '${r.avgTimeMs.toStringAsFixed(2)} ms',
                  color),
              SizedBox(width: 8),
              _buildStatBox('Min', '${r.minTimeMs.toStringAsFixed(2)} ms',
                  Colors.green),
              SizedBox(width: 8),
              _buildStatBox('Max', '${r.maxTimeMs.toStringAsFixed(2)} ms',
                  Colors.red),
            ]),
            SizedBox(height: 8),
            Text('Berhasil: ${r.successRuns}/${r.totalRuns} iterasi',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  Widget _buildComparisonTable() {
    final successResults =
        _results!.where((r) => r.successRuns > 0).toList();
    if (successResults.isEmpty) return SizedBox.shrink();

    // Cari yang tercepat
    final fastest = successResults.reduce(
        (a, b) => a.avgTimeMs < b.avgTimeMs ? a : b);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text('Perbandingan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            SizedBox(height: 12),
            Table(
              columnWidths: {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              border: TableBorder(
                horizontalInside:
                    BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              children: [
                // Header
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                  ),
                  children: ['Delegate', 'Avg', 'Min', 'Max']
                      .map((h) => Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Text(h,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ))
                      .toList(),
                ),
                // Data rows
                ...successResults.map((r) {
                  final info = _delegateInfo[r.delegate]!;
                  final isFastest = r.delegate == fastest.delegate;
                  final speedup = r.avgTimeMs > 0
                      ? fastest.avgTimeMs / r.avgTimeMs
                      : 0.0;

                  return TableRow(
                    decoration: isFastest
                        ? BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08))
                        : null,
                    children: [
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(children: [
                          if (isFastest)
                            Icon(Icons.emoji_events,
                                size: 14, color: Colors.amber),
                          SizedBox(width: isFastest ? 4 : 0),
                          Text(info['label'] as String,
                              style: TextStyle(
                                  fontWeight: isFastest
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12)),
                        ]),
                      ),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text('${r.avgTimeMs.toStringAsFixed(1)} ms',
                            style: TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text('${r.minTimeMs.toStringAsFixed(1)} ms',
                            style: TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text('${r.maxTimeMs.toStringAsFixed(1)} ms',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  );
                }),
              ],
            ),
            SizedBox(height: 12),
            if (successResults.length > 1)
              Text(
                '🏆 ${_delegateInfo[fastest.delegate]!['label']} adalah yang tercepat '
                '(avg ${fastest.avgTimeMs.toStringAsFixed(2)} ms)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.green.shade700),
              ),
          ],
        ),
      ),
    );
  }
}
