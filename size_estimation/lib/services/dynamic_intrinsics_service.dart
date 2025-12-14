import 'dart:async';
import 'package:size_estimation/models/camera_metadata.dart';
import 'package:size_estimation/services/camera_metadata_service.dart';
import 'package:size_estimation/models/calibration_profile.dart';

/// Service to stream real-time camera metadata including crop region
class DynamicIntrinsicsService {
  final CameraMetadataService _metadataService = CameraMetadataService();

  CameraMetadata? _baseMetadata;
  final _intrinsicsController = StreamController<IntrinsicMatrix>.broadcast();
  final _metadataController = StreamController<CameraMetadata>.broadcast();

  Stream<IntrinsicMatrix> get intrinsicsStream => _intrinsicsController.stream;
  Stream<CameraMetadata> get metadataStream => _metadataController.stream;

  IntrinsicMatrix? _currentIntrinsics;
  CameraMetadata? _currentMetadata;

  IntrinsicMatrix? get currentIntrinsics => _currentIntrinsics;
  CameraMetadata? get currentMetadata => _currentMetadata;

  /// Initialize with camera properties
  Future<void> initialize({
    required int outputWidth,
    required int outputHeight,
    CalibrationProfile? customProfile,
    String cameraId = '0',
  }) async {
    try {
      final properties = await _metadataService.getCameraProperties(
        cameraId: cameraId,
      );

      _baseMetadata = _metadataService.createMetadataFromDevice(
        properties: properties,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        customProfile: customProfile,
      );

      if (_baseMetadata != null) {
        // Compute initial K_out (without crop, assumes full sensor)
        _updateIntrinsics(_baseMetadata!);
      }
    } catch (e) {
      print('Error initializing dynamic intrinsics: $e');
    }
  }

  /// Update with new output size (e.g., when resolution changes)
  void updateOutputSize(int width, int height) {
    if (_baseMetadata == null) return;

    _baseMetadata = CameraMetadata(
      sensorIntrinsics: _baseMetadata!.sensorIntrinsics,
      activeArraySize: _baseMetadata!.activeArraySize,
      cropRegion: _baseMetadata!.cropRegion,
      outputWidth: width,
      outputHeight: height,
      distortionCoefficients: _baseMetadata!.distortionCoefficients,
    );

    _updateIntrinsics(_baseMetadata!);
  }

  /// Update with crop region from CaptureResult
  /// This should be called whenever zoom changes or new frame is captured
  void updateCropRegion(CropRegion cropRegion) {
    if (_baseMetadata == null) return;

    final updatedMetadata = _metadataService.updateWithCropRegion(
      _baseMetadata!,
      cropRegion,
    );

    _updateIntrinsics(updatedMetadata);
  }

  /// Update with custom calibration profile
  Future<void> updateCalibrationProfile(CalibrationProfile? profile) async {
    if (_baseMetadata == null) return;

    // Recreate base metadata with new profile
    final properties = await _metadataService.getCameraProperties();

    _baseMetadata = _metadataService.createMetadataFromDevice(
      properties: properties,
      outputWidth: _baseMetadata!.outputWidth,
      outputHeight: _baseMetadata!.outputHeight,
      customProfile: profile,
    );

    if (_baseMetadata != null) {
      // Restore crop region if it exists
      if (_currentMetadata?.cropRegion != null) {
        _baseMetadata = _metadataService.updateWithCropRegion(
          _baseMetadata!,
          _currentMetadata!.cropRegion!,
        );
      }
      _updateIntrinsics(_baseMetadata!);
    }
  }

  void _updateIntrinsics(CameraMetadata metadata) {
    _currentMetadata = metadata;
    _currentIntrinsics = metadata.computeOutputIntrinsics();

    _metadataController.add(metadata);
    if (_currentIntrinsics != null) {
      _intrinsicsController.add(_currentIntrinsics!);
    }
  }

  /// Parse crop region from camera controller
  /// Note: Flutter's camera package doesn't directly expose SCALER_CROP_REGION
  /// We estimate it based on zoom level and sensor size
  CropRegion? estimateCropFromZoom(double zoomLevel) {
    if (_baseMetadata == null) return null;

    final activeArray = _baseMetadata!.activeArraySize;

    // Estimate crop based on zoom
    // zoom = 1.0 means full sensor, zoom = 2.0 means center 50% crop
    final cropWidth = (activeArray.width / zoomLevel).round();
    final cropHeight = (activeArray.height / zoomLevel).round();

    final x0 = ((activeArray.width - cropWidth) / 2).round();
    final y0 = ((activeArray.height - cropHeight) / 2).round();

    return CropRegion(
      x0: x0,
      y0: y0,
      width: cropWidth,
      height: cropHeight,
    );
  }

  /// Update based on zoom level
  void updateZoom(double zoomLevel) {
    final cropRegion = estimateCropFromZoom(zoomLevel);
    if (cropRegion != null) {
      updateCropRegion(cropRegion);
    }
  }

  void dispose() {
    _intrinsicsController.close();
    _metadataController.close();
  }
}
