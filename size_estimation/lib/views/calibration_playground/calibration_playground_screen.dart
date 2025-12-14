import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:size_estimation/models/calibration_profile.dart';
import 'package:size_estimation/services/calibration_service.dart';

class CalibrationPlaygroundScreen extends StatefulWidget {
  const CalibrationPlaygroundScreen({super.key});

  @override
  State<CalibrationPlaygroundScreen> createState() =>
      _CalibrationPlaygroundScreenState();
}

class _CalibrationPlaygroundScreenState
    extends State<CalibrationPlaygroundScreen> {
  final CalibrationService _calibrationService = CalibrationService();
  final ImagePicker _picker = ImagePicker();

  List<File> _chessboardImages = [];
  bool _isProcessing = false;
  CalibrationProfile? _calibratedProfile;
  String? _errorMessage;

  // Chessboard parameters
  int _boardWidth = 9;
  int _boardHeight = 6;
  double _squareSize = 25.0; // mm

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _chessboardImages = images.map((xfile) => File(xfile.path)).toList();
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking images: $e';
      });
    }
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _chessboardImages.add(File(image.path));
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error capturing image: $e';
      });
    }
  }

  Future<void> _runCalibration() async {
    if (_chessboardImages.length < 10) {
      setState(() {
        _errorMessage =
            'Need at least 10 images for calibration. Current: ${_chessboardImages.length}';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      const platform = MethodChannel('com.example.size_estimation/arcore');

      final imagePaths = _chessboardImages.map((f) => f.path).toList();

      final result = await platform.invokeMethod('calibrateCamera', {
        'imagePaths': imagePaths,
        'boardWidth': _boardWidth,
        'boardHeight': _boardHeight,
        'squareSize': _squareSize,
      });

      if (result['success'] == true) {
        final profile = CalibrationProfile(
          name: 'Chessboard_${DateTime.now().millisecondsSinceEpoch}',
          fx: result['fx'] as double,
          fy: result['fy'] as double,
          cx: result['cx'] as double,
          cy: result['cy'] as double,
          distortionCoefficients:
              (result['distortionCoefficients'] as List<dynamic>)
                  .map((e) => (e as num).toDouble())
                  .toList(),
          rmsError: result['rmsError'] as double,
          source: 'chessboard',
        );

        setState(() {
          _calibratedProfile = profile;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _errorMessage = result['errorMessage'] ?? 'Calibration failed';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Calibration failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_calibratedProfile == null) return;

    final nameController =
        TextEditingController(text: _calibratedProfile!.name);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Calibration Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Profile Name',
            hintText: 'e.g., My Custom Calibration',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final updatedProfile = _calibratedProfile!.copyWith(
        name: nameController.text.trim(),
      );

      await _calibrationService.saveProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile "${updatedProfile.name}" saved!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration Playground'),
        actions: [
          if (_calibratedProfile != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: 'Save Profile',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructions(),
            const SizedBox(height: 24),
            _buildChessboardSettings(),
            const SizedBox(height: 24),
            _buildImageSection(),
            const SizedBox(height: 24),
            _buildCalibrationButton(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorMessage(),
            ],
            if (_calibratedProfile != null) ...[
              const SizedBox(height: 24),
              _buildResultSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'How to Calibrate',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStep('1', 'Print a chessboard pattern (9×6 or 7×5)'),
            _buildStep('2',
                'Capture 15-30 images from different angles and distances'),
            _buildStep('3', 'Ensure the entire board is visible in each image'),
            _buildStep('4', 'Tap "Run Calibration" to process'),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildChessboardSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chessboard Pattern',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Width (corners)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: _boardWidth.toString()),
                    onChanged: (v) => _boardWidth = int.tryParse(v) ?? 9,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Height (corners)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: _boardHeight.toString()),
                    onChanged: (v) => _boardHeight = int.tryParse(v) ?? 6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Square Size (mm)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _squareSize.toString()),
              onChanged: (v) => _squareSize = double.tryParse(v) ?? 25.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Images (${_chessboardImages.length})',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: _captureImage,
                      tooltip: 'Capture',
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: _pickImages,
                      tooltip: 'Pick from gallery',
                    ),
                  ],
                ),
              ],
            ),
            if (_chessboardImages.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No images added yet',
                    style: TextStyle(
                        color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _chessboardImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_chessboardImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _chessboardImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationButton() {
    return FilledButton.icon(
      onPressed:
          _isProcessing || _chessboardImages.isEmpty ? null : _runCalibration,
      icon: _isProcessing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.calculate),
      label: Text(_isProcessing ? 'Processing...' : 'Run Calibration'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Calibration Complete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultRow('fx', _calibratedProfile!.fx.toStringAsFixed(2)),
            _buildResultRow('fy', _calibratedProfile!.fy.toStringAsFixed(2)),
            _buildResultRow('cx', _calibratedProfile!.cx.toStringAsFixed(2)),
            _buildResultRow('cy', _calibratedProfile!.cy.toStringAsFixed(2)),
            if (_calibratedProfile!.rmsError != null) ...[
              const Divider(),
              _buildResultRow(
                'RMS Error',
                '${_calibratedProfile!.rmsError!.toStringAsFixed(3)} px',
                valueColor: _calibratedProfile!.rmsError! < 0.5
                    ? Colors.green
                    : _calibratedProfile!.rmsError! < 1.0
                        ? Colors.orange
                        : Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
