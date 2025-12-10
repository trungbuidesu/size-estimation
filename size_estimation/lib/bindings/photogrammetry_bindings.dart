import 'dart:ffi'; // For FFI
import 'dart:io'; // For Platform.isX
import 'package:ffi/ffi.dart'; // For Utf8

// Define the C function signature
typedef EstimateHeightC = Double Function(
  Pointer<Pointer<Utf8>> imagePaths,
  Int32 numImages,
  Double knownBaselineCm,
  Double focalLength,
  Double cx,
  Double cy,
  Double sensorWidth,
  Double sensorHeight,
  Pointer<Double> distortionCoeffs,
  Int32 numDistortionCoeffs,
  Pointer<Utf8> boundingBoxesJson, // NEW: JSON string of bounding boxes
);

// Define the Dart function signature
typedef EstimateHeightDart = double Function(
  Pointer<Pointer<Utf8>> imagePaths,
  int numImages,
  double knownBaselineCm,
  double focalLength,
  double cx,
  double cy,
  double sensorWidth,
  double sensorHeight,
  Pointer<Double> distortionCoeffs,
  int numDistortionCoeffs,
  Pointer<Utf8> boundingBoxesJson, // NEW
);

class PhotogrammetryBindings {
  static DynamicLibrary? _lib;
  static EstimateHeightDart? _estimateHeight;

  static void initialize() {
    if (_lib != null) return;

    // Load the library
    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libphotogrammetry.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process(); // Or specific framework
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('photogrammetry.dll');
      } else {
        // Fallback or error
        print('Unsupported platform for photogrammetry');
        return;
      }

      // Look up the function
      _estimateHeight = _lib!
          .lookup<NativeFunction<EstimateHeightC>>('EstimateHeightFromBaseline')
          .asFunction<EstimateHeightDart>();
    } catch (e) {
      print('Failed to load native photogrammetry library: $e');
    }
  }

  static double estimateHeight({
    required List<String> imagePaths,
    required double knownBaselineCm,
    required double focalLength,
    required double cx,
    required double cy,
    double sensorWidth = 0.0,
    double sensorHeight = 0.0,
    List<double> distortionCoefficients = const [],
    String? boundingBoxesJson, // NEW: Optional bounding boxes
  }) {
    if (_estimateHeight == null) {
      initialize();
      if (_estimateHeight == null) {
        throw Exception('Native library not initialized');
      }
    }

    // Allocate memory for image paths
    final pointerList = calloc<Pointer<Utf8>>(imagePaths.length);
    final List<Pointer<Utf8>> pointers = [];

    // Allocate memory for distortion coefficients
    final distortionPtr = calloc<Double>(distortionCoefficients.length);
    for (int i = 0; i < distortionCoefficients.length; i++) {
      distortionPtr[i] = distortionCoefficients[i];
    }

    // Allocate memory for bounding boxes JSON
    final Pointer<Utf8> boxesPtr;
    if (boundingBoxesJson != null) {
      boxesPtr = boundingBoxesJson.toNativeUtf8();
    } else {
      boxesPtr = nullptr;
    }

    try {
      for (int i = 0; i < imagePaths.length; i++) {
        final ptr = imagePaths[i].toNativeUtf8();
        pointers.add(ptr);
        pointerList[i] = ptr;
      }

      final result = _estimateHeight!(
        pointerList,
        imagePaths.length,
        knownBaselineCm,
        focalLength,
        cx,
        cy,
        sensorWidth,
        sensorHeight,
        distortionPtr,
        distortionCoefficients.length,
        boxesPtr, // NEW: Pass bounding boxes
      );

      return result;
    } finally {
      // Free memory
      for (var ptr in pointers) {
        calloc.free(ptr);
      }
      calloc.free(pointerList);
      calloc.free(distortionPtr);
      if (boxesPtr != nullptr) {
        calloc.free(boxesPtr);
      }
    }
  }
}
