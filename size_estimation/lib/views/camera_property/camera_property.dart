import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:size_estimation/views/shared_components/index.dart';
import 'package:size_estimation/constants/index.dart';

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
        _errorMessage = "${AppStrings.failedGetProps}${e.message}'.";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "${AppStrings.errorOccurred}$e";
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            AppStrings.cameraPropsTitle,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        _buildScoreSection(),
        _buildPropertyTile(
          AppStrings.propLensIntrinsic,
          AppStrings.propLensIntrinsicDesc,
          _cameraProperties['LENS_INTRINSIC_CALIBRATION'],
        ),
        _buildPropertyTile(
          AppStrings.propLensDistortion,
          AppStrings.propLensDistortionDesc,
          _cameraProperties['LENS_RADIAL_DISTORTION'],
        ),
        _buildPropertyTile(
          AppStrings.propSensorPhysical,
          AppStrings.propSensorPhysicalDesc,
          _cameraProperties['SENSOR_INFO_PHYSICAL_SIZE'],
        ),
        _buildPropertyTile(
          AppStrings.propSensorActive,
          AppStrings.propSensorActiveDesc,
          _cameraProperties['SENSOR_INFO_ACTIVE_ARRAY_SIZE'],
        ),
        _buildPropertyTile(
          AppStrings.propCapabilities,
          AppStrings.propCapabilitiesDesc,
          _cameraProperties['REQUEST_AVAILABLE_CAPABILITIES'],
        ),
        _buildPropertyTile(
          AppStrings.propCropRegion,
          AppStrings.propCropRegionDesc,
          _cameraProperties['SCALER_CROP_REGION'],
        ),
        const SizedBox(height: 50), // Bottom padding
      ],
    );
  }

  Map<String, String> _getPropertyInfo(String title) {
    switch (title) {
      case AppStrings.propLensIntrinsic:
        return {
          'description': AppStrings.infoIntrinsicDesc,
          'purpose': AppStrings.infoIntrinsicPurpose,
          'missing': AppStrings.infoIntrinsicMissing
        };
      case AppStrings.propLensDistortion:
        return {
          'description': AppStrings.infoDistortionDesc,
          'purpose': AppStrings.infoDistortionPurpose,
          'missing': AppStrings.infoDistortionMissing
        };
      case AppStrings.propSensorPhysical:
        return {
          'description': AppStrings.infoSensorPhysDesc,
          'purpose': AppStrings.infoSensorPhysPurpose,
          'missing': AppStrings.infoSensorPhysMissing
        };
      case AppStrings.propSensorActive:
        return {
          'description': AppStrings.infoSensorActiveDesc,
          'purpose': AppStrings.infoSensorActivePurpose,
          'missing': AppStrings.infoSensorActiveMissing
        };
      case AppStrings.propCapabilities:
        return {
          'description': AppStrings.infoCapsDesc,
          'purpose': AppStrings.infoCapsPurpose,
          'missing': AppStrings.infoCapsMissing
        };
      case AppStrings.propCropRegion:
        return {
          'description': AppStrings.infoCropDesc,
          'purpose': AppStrings.infoCropPurpose,
          'missing': AppStrings.infoCropMissing
        };
      default:
        return {
          'description': AppStrings.noDesc,
          'purpose': AppStrings.unknown,
          'missing': AppStrings.unknown
        };
    }
  }

  void _showPropertyInfo(String title) {
    final info = _getPropertyInfo(title);
    CommonAlertDialog.show(
      context: context,
      title: title,
      icon: Icons.info_outline,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoSection(AppStrings.description, info['description']!),
            const SizedBox(height: 12),
            _buildInfoSection(AppStrings.purpose, info['purpose']!),
            const SizedBox(height: 12),
            _buildInfoSection(AppStrings.ifMissing, info['missing']!,
                isWarning: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.close),
        ),
      ],
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
      displayValue = AppStrings.na;
    } else if (value is List) {
      displayValue = value.join(', ');
    } else if (value is Map) {
      displayValue =
          value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    } else {
      displayValue = value.toString();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
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
                          style: TextStyle(
                            color: colorScheme.primary, // Brand Blue
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant, // N500/N600
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
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.info_outline,
                          color: colorScheme.onSurfaceVariant, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                displayValue,
                style: TextStyle(
                  color: colorScheme.onSurface, // N800
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

    // Semantic Colors (Hardcoded to ADS constants or closest equivalents if not in Scheme)
    // Success: Green, Warning: Yellow/Orange, Error: Red
    Color scoreColor = const Color(0xFFCA3521); // Danger Bold
    if (totalScore >= 80)
      scoreColor = const Color(0xFF22A06B); // Success Bold
    else if (totalScore >= 50)
      scoreColor = const Color(0xFFE2B203); // Warning Bold

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        // If theme has distinct card color, border might be redundant, but keeping subtle
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Text(
            AppStrings.scoreTitle,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4),
                child: Text(
                  '/ 100',
                  style: TextStyle(
                      color: colorScheme.onSurfaceVariant, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totalScore >= 80
                ? AppStrings.scoreExcellent
                : totalScore >= 50
                    ? AppStrings.scoreGood
                    : AppStrings.scoreLimited,
            style: TextStyle(color: scoreColor, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildScoreAttribute(
              AppStrings.scoreSpatial, spatialScore, 60, colorScheme),
          _buildScoreAttribute(
              AppStrings.scoreProcessing, processingScore, 25, colorScheme),
          _buildScoreAttribute(
              AppStrings.scoreCompat, compatScore, 15, colorScheme),
          const Divider(),
          if (hasDepth)
            _buildScoreBadge(Icons.check_circle, const Color(0xFF22A06B),
                AppStrings.scoreSupportDepth, colorScheme),
          if (hasIntrinsics)
            _buildScoreBadge(Icons.check_circle, const Color(0xFF22A06B),
                AppStrings.scoreSupportIntrinsics, colorScheme),
        ],
      ),
    );
  }

  Widget _buildScoreAttribute(
      String label, int value, int max, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface)),
          Text('$value/$max',
              style: TextStyle(
                  color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(
      IconData icon, Color color, String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}
