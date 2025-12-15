package com.example.size_estimation


import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import androidx.annotation.NonNull
import org.opencv.android.OpenCVLoader

class MainActivity: FlutterActivity() {
    private val channelName = "com.example.size_estimation/camera_utils"


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize OpenCV
        if (!OpenCVLoader.initDebug()) {
            android.util.Log.e("OpenCV", "Failed to initialize OpenCV")
        } else {
            android.util.Log.d("OpenCV", "OpenCV initialized successfully")
        }
        


        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {


                    "getCameraProperties" -> {
                        try {
                            val cameraId = call.argument<String>("cameraId") ?: "0"
                            val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                            val characteristics = manager.getCameraCharacteristics(cameraId)

                            val properties = HashMap<String, Any?>()

                            // LENS_INTRINSIC_CALIBRATION
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val intrinsic = characteristics.get(CameraCharacteristics.LENS_INTRINSIC_CALIBRATION)
                                properties["LENS_INTRINSIC_CALIBRATION"] = intrinsic?.toList() ?: "Unavailable"
                            } else {
                                properties["LENS_INTRINSIC_CALIBRATION"] = "Requires API 23+"
                            }

                            // LENS_RADIAL_DISTORTION
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val distortion = characteristics.get(CameraCharacteristics.LENS_RADIAL_DISTORTION)
                                properties["LENS_RADIAL_DISTORTION"] = distortion?.toList() ?: "Unavailable"
                            } else {
                                properties["LENS_RADIAL_DISTORTION"] = "Requires API 23+"
                            }

                            // SENSOR_INFO_PHYSICAL_SIZE
                            val physicalSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
                            properties["SENSOR_INFO_PHYSICAL_SIZE"] = if (physicalSize != null) {
                                mapOf("width" to physicalSize.width, "height" to physicalSize.height)
                            } else "Unavailable"

                            // SENSOR_INFO_ACTIVE_ARRAY_SIZE
                            val activeArray = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
                            properties["SENSOR_INFO_ACTIVE_ARRAY_SIZE"] = if (activeArray != null) {
                                mapOf("left" to activeArray.left, "top" to activeArray.top, "right" to activeArray.right, "bottom" to activeArray.bottom)
                            } else "Unavailable"

                            // REQUEST_AVAILABLE_CAPABILITIES
                            val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                            properties["REQUEST_AVAILABLE_CAPABILITIES"] = capabilities?.toList() ?: "Unavailable"

                            // SCALER_CROP_REGION (Dynamic, usually request/result, but we can check if there's a default/max which is active array size)
                            // We return a note that it is a CaptureResult, not a Characteristic
                            properties["SCALER_CROP_REGION"] = "Dynamic (Capture Result Only)"

                            result.success(properties)
                        } catch (e: Exception) {
                            result.error("CAMERA_ERROR", e.message, null)
                        }
                    }
                    "calibrateCamera" -> {
                        val imagePaths = call.argument<List<String>>("imagePaths")
                        val targetType = call.argument<String>("targetType") ?: "Chessboard"
                        val boardWidth = call.argument<Int>("boardWidth") ?: 9
                        val boardHeight = call.argument<Int>("boardHeight") ?: 6
                        val squareSize = call.argument<Double>("squareSize")?.toFloat() ?: 25.0f
                        
                        // ChArUco Params
                        val dictionaryId = call.argument<String>("dictionaryId") ?: "DICT_4x4"
                        val startId = call.argument<Int>("startId") ?: 0
                        
                        // Note: For standard calibration logic, we might not strictly need mm dimensions other than squareSize,
                        // unless we are doing something specific with board size validation or Aruco board creation.
                        // I will pass them just in case.
                        
                        if (imagePaths == null || imagePaths.isEmpty()) {
                            result.error("INVALID_ARGS", "Image paths required", null)
                            return@setMethodCallHandler
                        }
                        
                        Thread {
                            try {
                                val calibrationService = CameraCalibrationService()
                                val calibResult = calibrationService.calibrateCamera(
                                    imagePaths,
                                    boardWidth,
                                    boardHeight,
                                    squareSize,
                                    targetType,
                                    dictionaryId
                                )
                                
                                val resultMap = hashMapOf<String, Any?>(
                                    "success" to calibResult.success,
                                    "fx" to calibResult.fx,
                                    "fy" to calibResult.fy,
                                    "cx" to calibResult.cx,
                                    "cy" to calibResult.cy,
                                    "distortionCoefficients" to calibResult.distortionCoefficients.toList(),
                                    "rmsError" to calibResult.rmsError,
                                    "errorMessage" to calibResult.errorMessage
                                )
                                
                                runOnUiThread { result.success(resultMap) }
                            } catch (e: Exception) {
                                runOnUiThread { 
                                    result.error("CALIBRATION_ERROR", e.message, null) 
                                }
                            }
                        }.start()
                    }
                    "detectChessboard" -> {
                        val imagePath = call.argument<String>("imagePath")
                        val boardWidth = call.argument<Int>("boardWidth") ?: 9
                        val boardHeight = call.argument<Int>("boardHeight") ?: 6
                        
                        if (imagePath == null) {
                            result.error("INVALID_ARGS", "Image path required", null)
                            return@setMethodCallHandler
                        }
                        
                        Thread {
                            try {
                                val calibrationService = CameraCalibrationService()
                                val found = calibrationService.detectChessboard(
                                    imagePath,
                                    boardWidth,
                                    boardHeight
                                )
                                runOnUiThread { result.success(found) }
                            } catch (e: Exception) {
                                runOnUiThread { 
                                    result.error("DETECTION_ERROR", e.message, null) 
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    override fun onDestroy() {
        super.onDestroy()
    }
}
