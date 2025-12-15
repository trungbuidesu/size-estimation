import 'package:flutter/services.dart';
import 'package:size_estimation/models/camera_metadata.dart';
import 'package:size_estimation/models/calibration_profile.dart';

/// Service to get camera metadata and compute dynamic intrinsics
class CameraMetadataService {
  static const MethodChannel _channel =
      MethodChannel('com.example.size_estimation/camera_utils');

  /// Get camera properties from Camera2 API
  Future<Map<String, dynamic>> getCameraProperties(
      {String cameraId = '0'}) async {
    try {
      final result = await _channel.invokeMethod('getCameraProperties', {
        'cameraId': cameraId,
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Failed to get camera properties: $e');
    }
  }

  /// Parse device intrinsics from camera properties
  IntrinsicMatrix? parseDeviceIntrinsics(Map<String, dynamic> properties) {
    try {
      final intrinsicData = properties['LENS_INTRINSIC_CALIBRATION'];

      if (intrinsicData == null || intrinsicData == 'Unavailable') {
        return null;
      }

      List<double> intrinsics;
      if (intrinsicData is List) {
        intrinsics = intrinsicData.map((e) => (e as num).toDouble()).toList();
      } else if (intrinsicData is String) {
        // Parse string format: "[fx, fy, cx, cy, s]"
        final cleaned = intrinsicData
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(',')
            .map((e) => e.trim())
            .toList();
        intrinsics = cleaned.map((e) => double.parse(e)).toList();
      } else {
        return null;
      }

      if (intrinsics.length < 4) {
        return null;
      }

      return IntrinsicMatrix(
        fx: intrinsics[0],
        fy: intrinsics[1],
        cx: intrinsics[2],
        cy: intrinsics[3],
        s: intrinsics.length > 4 ? intrinsics[4] : 0.0,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse active array size from camera properties
  ActiveArraySize? parseActiveArraySize(Map<String, dynamic> properties) {
    try {
      final arrayData = properties['SENSOR_INFO_ACTIVE_ARRAY_SIZE'];

      if (arrayData == null || arrayData == 'Unavailable') {
        return null;
      }

      if (arrayData is Map) {
        return ActiveArraySize.fromMap(arrayData);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse distortion coefficients from camera properties
  List<double>? parseDistortionCoefficients(Map<String, dynamic> properties) {
    try {
      final distortionData = properties['LENS_RADIAL_DISTORTION'];

      if (distortionData == null || distortionData == 'Unavailable') {
        return null;
      }

      List<double> distortion;
      if (distortionData is List) {
        distortion = distortionData.map((e) => (e as num).toDouble()).toList();
      } else if (distortionData is String) {
        final cleaned = distortionData
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(',')
            .map((e) => e.trim())
            .toList();
        distortion = cleaned.map((e) => double.parse(e)).toList();
      } else {
        return null;
      }

      return distortion;
    } catch (e) {
      return null;
    }
  }

  /// Create CameraMetadata from device properties and output size
  /// Note: cropRegion will be null here as it requires CaptureResult (runtime)
  CameraMetadata? createMetadataFromDevice({
    required Map<String, dynamic> properties,
    required int outputWidth,
    required int outputHeight,
    CalibrationProfile? customProfile,
  }) {
    IntrinsicMatrix? sensorIntrinsics;
    List<double>? distortion;

    // Use custom profile if provided, otherwise use device intrinsics
    if (customProfile != null) {
      sensorIntrinsics = IntrinsicMatrix(
        fx: customProfile.fx,
        fy: customProfile.fy,
        cx: customProfile.cx,
        cy: customProfile.cy,
      );
      distortion = customProfile.distortionCoefficients.isNotEmpty
          ? customProfile.distortionCoefficients
          : null;
    } else {
      sensorIntrinsics = parseDeviceIntrinsics(properties);
      distortion = parseDistortionCoefficients(properties);
    }

    final activeArray = parseActiveArraySize(properties);

    if (sensorIntrinsics == null || activeArray == null) {
      return null;
    }

    return CameraMetadata(
      sensorIntrinsics: sensorIntrinsics,
      activeArraySize: activeArray,
      cropRegion: null, // Will be updated with actual crop from CaptureResult
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      distortionCoefficients: distortion,
    );
  }

  /// Update metadata with crop region (from CaptureResult)
  CameraMetadata updateWithCropRegion(
    CameraMetadata metadata,
    CropRegion cropRegion,
  ) {
    return CameraMetadata(
      sensorIntrinsics: metadata.sensorIntrinsics,
      activeArraySize: metadata.activeArraySize,
      cropRegion: cropRegion,
      outputWidth: metadata.outputWidth,
      outputHeight: metadata.outputHeight,
      distortionCoefficients: metadata.distortionCoefficients,
    );
  }
}
