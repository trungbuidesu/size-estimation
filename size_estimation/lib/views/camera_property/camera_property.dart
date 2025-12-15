import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraPropertiesWidget extends StatefulWidget {
  const CameraPropertiesWidget({super.key});

  @override
  State<CameraPropertiesWidget> createState() => _CameraPropertiesWidgetState();
}

class _CameraPropertiesWidgetState extends State<CameraPropertiesWidget> {
  static const platform =
      MethodChannel('com.example.size_estimation/camera_utils');
  Map<String, dynamic> _cameraProperties = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCameraProperties();
  }

  Future<void> _fetchCameraProperties() async {
    try {
      // By default, we request properties for camera "0" (back camera usually)
      final Map<dynamic, dynamic> result =
          await platform.invokeMethod('getCameraProperties', {'cameraId': '0'});

      setState(() {
        _cameraProperties = result.cast<String, dynamic>();
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = "Failed to get camera properties: '${e.message}'.";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "An error occurred: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the sheet is full screen on mount, if inside DraggableScrollableSheet
    // Note: We can't easily force the parent sheet's controller from here without passing it down.
    // However, the request was "when clicked, it will automatically pull up to the top of the screen".
    // This is best handled by the parent widget setting initialChildSize to a high value (e.g. 0.95),
    // OR we can use a post-frame callback to animate the sheet if we had access to the controller.
    // Assuming the parent `_showCameraProperties` in `methods_screen.dart` is updated or this widget
    // is large enough to naturally fill space.
    // Let's ensure the content is tall enough or structured well.

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'Camera Properties',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _buildScoreSection(),
          _buildPropertyTile(
            'Lens Intrinsic Calibration',
            'Hiệu chuẩn nội tại ống kính',
            _cameraProperties['LENS_INTRINSIC_CALIBRATION'],
          ),
          _buildPropertyTile(
            'Lens Radial Distortion',
            'Biến dạng hướng tâm ống kính',
            _cameraProperties['LENS_RADIAL_DISTORTION'],
          ),
          _buildPropertyTile(
            'Sensor Info Physical Size',
            'Kích thước vật lý cảm biến',
            _cameraProperties['SENSOR_INFO_PHYSICAL_SIZE'],
          ),
          _buildPropertyTile(
            'Sensor Info Active Array Size',
            'Kích thước mảng hoạt động',
            _cameraProperties['SENSOR_INFO_ACTIVE_ARRAY_SIZE'],
          ),
          _buildPropertyTile(
            'Request Available Capabilities',
            'Các khả năng hiện có',
            _cameraProperties['REQUEST_AVAILABLE_CAPABILITIES'],
          ),
          _buildPropertyTile(
            'Scaler Crop Region',
            'Vùng cắt tỷ lệ (Zoom)',
            _cameraProperties['SCALER_CROP_REGION'],
          ),
          const SizedBox(height: 50), // Bottom padding
        ],
      ),
    );
  }

  Map<String, String> _getPropertyInfo(String title) {
    switch (title) {
      case 'Lens Intrinsic Calibration':
        return {
          'description':
              'Các tham số mô tả sự ánh xạ từ không gian 3D sang mặt phẳng hình ảnh 2D (tiêu cự, điểm chính).',
          'purpose':
              'Cần thiết để chuyển đổi các điểm ảnh 2D trở lại thành các tia 3D. Được sử dụng trong đo lường chính xác.',
          'missing':
              'Không thể tái tạo chính xác hình học 3D từ một hình ảnh duy nhất. Các tính toán kích thước sẽ không chính xác.'
        };
      case 'Lens Radial Distortion':
        return {
          'description':
              'Các hệ số mô tả cách ống kính bẻ cong ánh sáng (biến dạng thùng/gối).',
          'purpose':
              'Sửa biến dạng hình học để các đường thẳng trong thực tế cũng thẳng trong hình ảnh.',
          'missing':
              'Các phép đo gần các cạnh của hình ảnh sẽ không chính xác.'
        };
      case 'Sensor Info Physical Size':
        return {
          'description':
              'Kích thước vật lý (chiều rộng x chiều cao) của cảm biến camera tính bằng milimet.',
          'purpose':
              'Xác định tỷ lệ vật lý của các đối tượng được chiếu lên cảm biến. Quan trọng để tính toán "pixel trên milimet".',
          'missing':
              'Không thể tính toán kích thước thế giới thực từ pixel nếu không có đối tượng tham chiếu đã biết.'
        };
      case 'Sensor Info Active Array Size':
        return {
          'description':
              'Vùng của cảm biến thực sự được sử dụng để chụp ảnh (tính bằng pixel).',
          'purpose':
              'Được sử dụng cùng với kích thước vật lý để tính kích thước điểm ảnh (kích thước vật lý của một pixel).',
          'missing':
              'Không thể ánh xạ tọa độ pixel sang tọa độ cảm biến vật lý một cách chính xác.'
        };
      case 'Request Available Capabilities':
        return {
          'description':
              'Danh sách các tính năng mà camera hỗ trợ (ví dụ: RAW, MANUAL_SENSOR, DEPTH_OUTPUT).',
          'purpose':
              'Kiểm tra xem thiết bị có hỗ trợ các tính năng nâng cao như ước lượng độ sâu hoặc điều khiển thủ công hay không.',
          'missing':
              'Ứng dụng có thể giả định các khả năng không có, dẫn đến sự cố hoặc tính năng bị thiếu.'
        };
      case 'Scaler Crop Region':
        return {
          'description':
              'Vùng của cảm biến hiện đang được đọc để tạo ra luồng hình ảnh.',
          'purpose':
              'Triển khai zoom kỹ thuật số. Cho biết phần nào của cảm biến đầy đủ tương ứng với khung hình hiện tại của bạn.',
          'missing':
              'Mức zoom kỹ thuật số không xác định. Các phép đo sẽ hoàn toàn sai nếu người dùng phóng to.'
        };
      default:
        return {
          'description': 'Không có mô tả.',
          'purpose': 'Không xác định.',
          'missing': 'Không xác định.'
        };
    }
  }

  void _showPropertyInfo(String title) {
    final info = _getPropertyInfo(title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection('Mô tả', info['description']!),
              const SizedBox(height: 12),
              _buildInfoSection('Mục đích', info['purpose']!),
              const SizedBox(height: 12),
              _buildInfoSection('Nếu thiếu', info['missing']!,
                  isWarning: true),
            ],
          ),
        ),
        actions: [
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(String header, String content,
      {bool isWarning = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isWarning ? Colors.deepOrangeAccent : Colors.black87,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildPropertyTile(String title, String subtitle, dynamic value) {
    String displayValue;
    if (value == null) {
      displayValue = 'N/A';
    } else if (value is List) {
      displayValue = value.join(', ');
    } else if (value is Map) {
      displayValue =
          value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    } else {
      displayValue = value.toString();
    }

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: () => _showPropertyInfo(title),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showPropertyInfo(title),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.info_outline,
                          color: Colors.white54, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                displayValue,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: 'Courier', // Monospace for numbers
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


    int score = 0;
    // 1. Sensor & Spatial (Max 60)
    // Check Depth/Capabilities
    final caps = _cameraProperties['REQUEST_AVAILABLE_CAPABILITIES'].toString();
    if (caps.contains('DEPTH_OUTPUT')) score += 20;
    if (caps.contains('LOGICAL_MULTI_CAMERA')) score += 10;

    // Check Resolution (Approximation from Active Array Size)
    final activeArray =
        _cameraProperties['SENSOR_INFO_ACTIVE_ARRAY_SIZE'].toString();
    // Expected format: Rect(0, 0 - w, h) or similar string depending on platform impl.
    // If just checking presence of data:
    if (activeArray != 'null') score += 15;

    // Check Calibration Data
    if (_cameraProperties['LENS_INTRINSIC_CALIBRATION'] != null) score += 10;
    if (_cameraProperties['LENS_RADIAL_DISTORTION'] != null) score += 5;

    // 2. Processing (Max 25)
    // Hardware Level (proxied by capabilities)
    if (caps.contains('MANUAL_SENSOR')) score += 10;
    if (caps.contains('RAW')) score += 5;
    // Base speed score
    score += 10;

    // 3. Compatibility (Max 15)
    score += 15; // Assume compatible if running app



  Widget _buildScoreSection() {
    // 1. Sensor & Spatial (Max 60)
    int spatialScore = 0;
    final caps = _cameraProperties['REQUEST_AVAILABLE_CAPABILITIES'].toString();
    final hasDepth = caps.contains('DEPTH_OUTPUT');
    if (hasDepth) spatialScore += 20;
    if (caps.contains('LOGICAL_MULTI_CAMERA')) spatialScore += 10;

    final activeArray =
        _cameraProperties['SENSOR_INFO_ACTIVE_ARRAY_SIZE'].toString();
    if (activeArray != 'null') spatialScore += 15;

    final hasIntrinsics =
        _cameraProperties['LENS_INTRINSIC_CALIBRATION'] != null;
    if (hasIntrinsics) spatialScore += 10;
    if (_cameraProperties['LENS_RADIAL_DISTORTION'] != null) spatialScore += 5;

    // 2. Processing (Max 25)
    int processingScore = 0;
    if (caps.contains('MANUAL_SENSOR')) processingScore += 10;
    if (caps.contains('RAW')) processingScore += 5;
    processingScore += 10; // Base speed

    // 3. Compatibility (Max 15)
    int compatScore = 15;

    final totalScore =
        (spatialScore + processingScore + compatScore).clamp(0, 100);

    Color scoreColor = Colors.red;
    if (totalScore >= 80)
      scoreColor = Colors.green;
    else if (totalScore >= 50) scoreColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const Text(
            'ĐIỂM HIỆU NĂNG (BETA)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$totalScore',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 10, left: 4),
                child: Text(
                  '/ 100',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totalScore >= 80
                ? 'Tuyệt vời cho Photogrammetry'
                : totalScore >= 50
                    ? 'Đủ điều kiện cơ bản'
                    : 'Hạn chế tính năng',
            style: TextStyle(color: scoreColor, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildScoreAttribute('Không gian & Cảm biến', spatialScore, 60),
          _buildScoreAttribute('Xử lý hình ảnh', processingScore, 25),
          _buildScoreAttribute('Tương thích', compatScore, 15),
          const Divider(color: Colors.white10),
          if (hasDepth)
            _buildScoreBadge(Icons.check_circle, Colors.green, 'Hỗ trợ Depth'),
          if (hasIntrinsics)
            _buildScoreBadge(
                Icons.check_circle, Colors.green, 'Hỗ trợ Intrinsics'),
        ],
      ),
    );
  }

  Widget _buildScoreAttribute(String label, int value, int max) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text('$value/$max',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
