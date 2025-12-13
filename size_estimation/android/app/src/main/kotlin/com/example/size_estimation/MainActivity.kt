package com.example.size_estimation

import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val channelName = "com.example.size_estimation/arcore"
    private var yoloDetector: YoloDetector? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize detector
        try {
            yoloDetector = YoloDetector(this, "yolov8n.tflite", "labels.txt")
        } catch (e: Exception) {
             android.util.Log.e("Yolo", "Failed to init detector: ${e.message}")
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkArSupport" -> {
                        val availability = ArCoreApk.getInstance().checkAvailability(this)
                        val supported = availability.isSupported && !availability.isTransient
                        result.success(supported)
                    }
                    "detectObjects" -> {
                        val imagePath = call.argument<String>("imagePath")
                        if (imagePath != null && yoloDetector != null) {
                            Thread {
                                try {
                                    val results = yoloDetector!!.detect(imagePath)
                                    runOnUiThread { result.success(results) }
                                } catch (e: Exception) {
                                    runOnUiThread { result.error("DETECTION_ERROR", e.message, null) }
                                }
                            }.start()
                        } else {
                            result.error("ERROR", "Invalid path or detector not ready", null)
                        }
                    }
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
                    else -> result.notImplemented()
                }
            }
    }
    
    override fun onDestroy() {
        yoloDetector?.close()
        super.onDestroy()
    }
}
