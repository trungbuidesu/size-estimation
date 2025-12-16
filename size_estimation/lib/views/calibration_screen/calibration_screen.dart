import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:size_estimation/models/calibration_profile.dart';
import 'package:size_estimation/services/calibration_service.dart';
import 'package:size_estimation/views/shared_components/index.dart';
import 'package:size_estimation/constants/index.dart';
import 'multi_capture_camera_screen.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final CalibrationService _calibrationService = CalibrationService();
  final ImagePicker _picker = ImagePicker();

  List<File> _chessboardImages = [];
  bool _isProcessing = false;
  CalibrationProfile? _calibratedProfile;
  String? _errorMessage;

  // Chessboard parameters
  // ChArUco parameters
  final String _targetType = 'ChArUco';
  int _boardWidth = 11; // Columns
  int _boardHeight = 8; // Rows
  double _squareSize = 15.0; // Checker Width (mm)

  // Other image fields
  double _boardWidthMm = 200.0;
  double _boardHeightMm = 150.0;
  String _dictionaryId = 'DICT_4x4';
  int _startId = 0;

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
        _errorMessage = '${AppStrings.errorPickImage}$e';
      });
    }
  }

  Future<void> _captureImages() async {
    try {
      final List<File>? selectedImages = await Navigator.push<List<File>>(
        context,
        MaterialPageRoute(
          builder: (context) => const MultiCaptureCameraScreen(),
        ),
      );

      if (selectedImages != null && selectedImages.isNotEmpty) {
        setState(() {
          _chessboardImages.addAll(selectedImages);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${AppStrings.errorCaptureImage}$e';
      });
    }
  }

  Future<void> _runCalibration() async {
    if (_chessboardImages.length < 10) {
      setState(() {
        _errorMessage =
            '${AppStrings.minImagesRequired}${_chessboardImages.length}';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      const platform =
          MethodChannel('com.example.size_estimation/camera_utils');

      final imagePaths = _chessboardImages.map((f) => f.path).toList();

      final result = await platform.invokeMethod('calibrateCamera', {
        'imagePaths': imagePaths,
        'targetType': _targetType,
        'boardWidth': _boardWidth, // Columns
        'boardHeight': _boardHeight, // Rows
        'squareSize': _squareSize, // Checker Width
        'markerLength':
            _squareSize * 0.8, // Estimate marker length (0.8 is common)
        'boardWidthMm': _boardWidthMm,
        'boardHeightMm': _boardHeightMm,
        'dictionaryId': _dictionaryId,
        'startId': _startId,
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
          _errorMessage =
              result['errorMessage'] ?? AppStrings.calibrationFailed;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${AppStrings.calibrationFailedPrefix}$e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_calibratedProfile == null) return;

    final nameController =
        TextEditingController(text: _calibratedProfile!.name);

    final result = await CommonAlertDialog.show<bool>(
      context: context,
      title: AppStrings.saveProfileTitle,
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: AppStrings.profileNameLabel,
          hintText: AppStrings.profileNameHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(AppStrings.save),
        ),
      ],
    );

    if (result == true) {
      final updatedProfile = _calibratedProfile!.copyWith(
        name: nameController.text.trim(),
      );

      await _calibrationService.saveProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppStrings.saveProfileSuccess}${updatedProfile.name}"!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.calibrationTitle),
        actions: [
          if (_calibratedProfile != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: AppStrings.saveTooltip,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCharucoSummary(),
            const SizedBox(height: 16),
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
      elevation: 0,
      color: Theme.of(context).cardTheme.color,
      shape: Theme.of(context).cardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  AppStrings.calibrationGuideTitle,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStep('1', AppStrings.step1),
            _buildStep('2', AppStrings.step2),
            _buildStep('3', AppStrings.step3),
            _buildStep('4', AppStrings.step4),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13, color: theme.colorScheme.onSurface))),
        ],
      ),
    );
  }

  Widget _buildChessboardSettings() {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.targetSettingsTitle,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: AppStrings.boardWidthLabel,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: _boardWidthMm.toString()),
                    onChanged: (v) =>
                        _boardWidthMm = double.tryParse(v) ?? 200.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: AppStrings.boardHeightLabel,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: _boardHeightMm.toString()),
                    onChanged: (v) =>
                        _boardHeightMm = double.tryParse(v) ?? 150.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: AppStrings.rowsLabel,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: _boardHeight.toString()),
                    onChanged: (v) => _boardHeight = int.tryParse(v) ?? 6,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: AppStrings.columnsLabel,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: _boardWidth.toString()),
                    onChanged: (v) => _boardWidth = int.tryParse(v) ?? 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: AppStrings.squareSizeLabel,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _squareSize.toString()),
              onChanged: (v) => _squareSize = double.tryParse(v) ?? 25.0,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: 'DICT_4x4',
              decoration: const InputDecoration(
                labelText: AppStrings.dictLabel,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'DICT_4x4', child: Text('DICT_4x4')),
                DropdownMenuItem(value: 'DICT_5x5', child: Text('DICT_5x5')),
                DropdownMenuItem(value: 'DICT_6x6', child: Text('DICT_6x6')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _dictionaryId = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: AppStrings.startIdLabel,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: "0"),
              onChanged: (v) => _startId = int.tryParse(v) ?? 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppStrings.imagesHeader}${_chessboardImages.length})',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: _captureImages,
                      tooltip: AppStrings.captureTooltip,
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: _pickImages,
                      tooltip: AppStrings.libraryTooltip,
                    ),
                  ],
                ),
              ],
            ),
            if (_chessboardImages.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    AppStrings.noImages,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              Container(
                height: 300,
                margin: const EdgeInsets.only(top: 8),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _chessboardImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
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
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _chessboardImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
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
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary),
            )
          : const Icon(Icons.calculate),
      label: Text(
          _isProcessing ? AppStrings.processing : AppStrings.runCalibration),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildErrorMessage() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final theme = Theme.of(context);
    return Card(
      // ADS Success state: Green background (light)
      color: const Color(0xFF22A06B).withOpacity(0.1), // Success token tint
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle,
                    color: Color(0xFF22A06B)), // Success token
                SizedBox(width: 8),
                Text(
                  AppStrings.calibrationComplete,
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
                AppStrings.rmsError,
                '${_calibratedProfile!.rmsError!.toStringAsFixed(3)} px',
                valueColor: _calibratedProfile!.rmsError! < 0.5
                    ? const Color(0xFF22A06B)
                    : _calibratedProfile!.rmsError! < 1.0
                        ? const Color(0xFFE2B203)
                        : theme.colorScheme.error,
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
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharucoSummary() {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_4x4, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Text(
                  AppStrings.charucoInfoTitle,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.charucoInfoDesc,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 200,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  color: Colors
                      .white, // Preview should arguably be white always as it is paper
                ),
                child: CustomPaint(
                  painter: _CharucoPreviewPainter(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                AppStrings.simpleIllustration,
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.paramExplanation,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            _buildParamInfo(AppStrings.paramBoard, AppStrings.paramBoardDesc),
            _buildParamInfo(AppStrings.paramRowCol, AppStrings.paramRowColDesc),
            _buildParamInfo(AppStrings.paramSquare, AppStrings.paramSquareDesc),
            _buildParamInfo(AppStrings.paramDict, AppStrings.paramDictDesc),
            _buildParamInfo(
                AppStrings.paramStartId, AppStrings.paramStartIdDesc),
          ],
        ),
      ),
    );
  }

  Widget _buildParamInfo(String label, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
          children: [
            TextSpan(
                text: '• $label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: desc),
          ],
        ),
      ),
    );
  }
}

class _CharucoPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintBlack = Paint()..color = Colors.black;
    final paintMarker = Paint()..color = Colors.black87;

    double rows = 5;
    double cols = 7;
    double cellW = size.width / cols;
    double cellH = size.height / rows;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Chessboard logic: if (r+c) is even/odd
        bool isBlack = (r + c) % 2 != 0;

        if (isBlack) {
          canvas.drawRect(
              Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH), paintBlack);
        } else {
          // White square -> Draw simulated Marker
          // Marker is smaller square inside
          double markerSize = cellW * 0.6;
          double offsetX = (cellW - markerSize) / 2;
          double offsetY = (cellH - markerSize) / 2;

          // Draw outer black box of marker
          canvas.drawRect(
              Rect.fromLTWH(c * cellW + offsetX, r * cellH + offsetY,
                  markerSize, markerSize),
              paintMarker);

          // Draw a tiny white dot to make it look like a marker
          canvas.drawRect(
              Rect.fromLTWH(
                  c * cellW + offsetX + markerSize / 3,
                  r * cellH + offsetY + markerSize / 3,
                  markerSize / 3,
                  markerSize / 3),
              Paint()..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
