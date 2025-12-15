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
        _errorMessage = 'Lỗi khi chọn ảnh: $e';
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
        _errorMessage = 'Lỗi khi chụp ảnh: $e';
      });
    }
  }

  Future<void> _runCalibration() async {
    if (_chessboardImages.length < 10) {
      setState(() {
        _errorMessage =
            'Cần ít nhất 10 hình ảnh để hiệu chuẩn. Hiện tại: ${_chessboardImages.length}';
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
          _errorMessage = result['errorMessage'] ?? 'Hiệu chuẩn thất bại';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Hiệu chuẩn thất bại: $e';
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
        title: const Text('Lưu Hồ Sơ Hiệu Chuẩn'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Tên Hồ Sơ',
            hintText: 'Ví dụ: Hiệu chuẩn của tôi',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
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
          SnackBar(content: Text('Đã lưu hồ sơ "${updatedProfile.name}"!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hiệu Chuẩn (Calibration)'),
        actions: [
          if (_calibratedProfile != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: 'Lưu Hồ Sơ',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                  'Hướng Dẫn Hiệu Chuẩn',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStep('1', 'In mẫu ChArUco (ví dụ: 5x7 hoặc 8x11)'),
            _buildStep(
                '2', 'Chụp 15-30 ảnh từ các góc độ và khoảng cách khác nhau'),
            _buildStep('3', 'Đảm bảo toàn bộ bảng đều nằm trong khung hình'),
            _buildStep('4', 'Nhấn "Chạy Hiệu Chuẩn" để xử lý'),
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
              'Cài Đặt Mục Tiêu',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Chiều Rộng Bảng [mm]',
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
                      labelText: 'Chiều Cao Bảng [mm]',
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
                      labelText: 'Số Hàng',
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
                      labelText: 'Số Cột',
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
                labelText: 'Kích Thước Ô Vuông (mm)',
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
                labelText: 'Từ Điển Marker',
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
                labelText: 'ID Bắt Đầu',
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
                  'Hình Ảnh (${_chessboardImages.length})',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: _captureImage,
                      tooltip: 'Chụp ảnh',
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: _pickImages,
                      tooltip: 'Chọn từ thư viện',
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
                    'Chưa có hình ảnh nào',
                    style: TextStyle(
                        color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              Container(
                height: 300, // Fixed height for grid
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
      label: Text(_isProcessing ? 'Đang xử lý...' : 'Chạy Hiệu Chuẩn'),
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
                  'Hiệu Chuẩn Hoàn Tất',
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
                'Sai số RMS',
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

  Widget _buildCharucoSummary() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.grid_4x4, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'ChArUco Board là gì?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Bảng ChArUco là sự kết hợp giữa bàn cờ vua tiêu chuẩn và các điểm đánh dấu ArUco. '
              'Các ô trắng của bàn cờ chứa các marker ArUco nhỏ. '
              'Thiết kế lai này mang lại độ chính xác cao của việc phát hiện góc bàn cờ '
              'cùng với sự mạnh mẽ của việc nhận dạng marker, cho phép hiệu chuẩn ngay cả khi bảng bị che khuất một phần.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 200,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: CustomPaint(
                  painter: _CharucoPreviewPainter(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Minh họa đơn giản',
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Giải thích thông số:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildParamInfo(
                'Bảng', 'Chiều rộng/cao vật lý của toàn bộ bảng giấy'),
            _buildParamInfo(
                'Hàng/Cột', 'Số lượng ô vuông theo chiều dọc/ngang'),
            _buildParamInfo(
                'Ô Vuông', 'Kích thước cạnh của một ô vuông đen/trắng'),
            _buildParamInfo(
                'Từ Điển', 'Bộ từ điển ArUco được sử dụng để tạo marker'),
            _buildParamInfo(
                'ID Bắt Đầu', 'ID của marker đầu tiên (thường là 0)'),
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
          style: const TextStyle(fontSize: 12, color: Colors.black87),
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
