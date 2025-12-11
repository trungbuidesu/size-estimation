import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraPropertiesWidget extends StatefulWidget {
  const CameraPropertiesWidget({super.key});

  @override
  State<CameraPropertiesWidget> createState() => _CameraPropertiesWidgetState();
}

class _CameraPropertiesWidgetState extends State<CameraPropertiesWidget> {
  static const platform = MethodChannel('com.example.size_estimation/arcore');
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

    return Column(
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
          _cameraProperties['LENS_INTRINSIC_CALIBRATION'],
        ),
        _buildPropertyTile(
          'Lens Radial Distortion',
          _cameraProperties['LENS_RADIAL_DISTORTION'],
        ),
        _buildPropertyTile(
          'Sensor Info Physical Size',
          _cameraProperties['SENSOR_INFO_PHYSICAL_SIZE'],
        ),
        _buildPropertyTile(
          'Sensor Info Active Array Size',
          _cameraProperties['SENSOR_INFO_ACTIVE_ARRAY_SIZE'],
        ),
        _buildPropertyTile(
          'Request Available Capabilities',
          _cameraProperties['REQUEST_AVAILABLE_CAPABILITIES'],
        ),
        _buildPropertyTile(
          'Scaler Crop Region',
          _cameraProperties['SCALER_CROP_REGION'],
        ),
      ],
    );
  }

  Map<String, String> _getPropertyInfo(String title) {
    switch (title) {
      case 'Lens Intrinsic Calibration':
        return {
          'description':
              'Parameters describing the mapping from 3D space to the 2D image plane (focal length, principal point).',
          'purpose':
              'Essential for converting 2D pixels back to 3D rays. Used in AR and precise measurement.',
          'missing':
              'Cannot accurately reconstruct 3D geometry from a single image. ARCore/ARKit won\'t work well or at all.'
        };
      case 'Lens Radial Distortion':
        return {
          'description':
              'Coefficients describing how the lens bends light (barrel/pincushion distortion).',
          'purpose':
              'Correcting geometric distortion so straight lines in real life appear straight in the image.',
          'missing':
              'Measurements near the edges of the image will be inaccurate.'
        };
      case 'Sensor Info Physical Size':
        return {
          'description':
              'The physical dimensions (width x height) of the camera sensor in millimeters.',
          'purpose':
              'Determining the physical scale of objects projected onto the sensor. Critical for calculating "pixels per millimeter".',
          'missing':
              'Impossible to calculate real-world size from pixels without a known reference object.'
        };
      case 'Sensor Info Active Array Size':
        return {
          'description':
              'The area of the sensor actually used to capture the image (in pixels).',
          'purpose':
              'Used with physical size to calculate pixel pitch (physical size of one pixel).',
          'missing':
              'Cannot map pixel coordinates to physical sensor coordinates accurately.'
        };
      case 'Request Available Capabilities':
        return {
          'description':
              'List of features the camera supports (e.g., RAW, MANUAL_SENSOR, DEPTH_OUTPUT).',
          'purpose':
              'Checks if device supports advanced features like depth estimation or manual control.',
          'missing':
              'Application might assume capabilities that aren\'t there, leading to crashes.'
        };
      case 'Scaler Crop Region':
        return {
          'description':
              'The region of the sensor currently being read out to produce the image stream.',
          'purpose':
              'Digital zoom implementation. Tells you what part of the full sensor corresponds to your current image frame.',
          'missing':
              'Digital zoom level is unknown. Measurements will be totally wrong if the user zooms in.'
        };
      default:
        return {
          'description': 'No description available.',
          'purpose': 'Unknown.',
          'missing': 'Unknown.'
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
              _buildInfoSection('Description', info['description']!),
              const SizedBox(height: 12),
              _buildInfoSection('Purpose', info['purpose']!),
              const SizedBox(height: 12),
              _buildInfoSection('If Missing', info['missing']!,
                  isWarning: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
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

  Widget _buildPropertyTile(String title, dynamic value) {
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
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

  int _calculateScore() {
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

    return score.clamp(0, 100);
  }

  Widget _buildScoreSection() {
    final score = _calculateScore();
    Color scoreColor = Colors.red;
    if (score >= 80)
      scoreColor = Colors.green;
    else if (score >= 50) scoreColor = Colors.orange;

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
                '$score',
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
            score >= 80
                ? 'Tuyệt vời cho Photogrammetry'
                : score >= 50
                    ? 'Đủ điều kiện cơ bản'
                    : 'Hạn chế tính năng',
            style: TextStyle(color: scoreColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
