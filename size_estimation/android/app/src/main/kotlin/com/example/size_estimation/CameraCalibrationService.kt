package com.example.size_estimation

import org.opencv.core.Mat
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Size
import org.opencv.core.CvType
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.aruco.Aruco
import org.opencv.aruco.Dictionary
import org.opencv.aruco.CharucoBoard
import android.util.Log
import java.io.File
import java.util.ArrayList

class CameraCalibrationService {

    data class CalibrationResult(
        val success: Boolean,
        val fx: Double = 0.0,
        val fy: Double = 0.0,
        val cx: Double = 0.0,
        val cy: Double = 0.0,
        val distortionCoefficients: DoubleArray = doubleArrayOf(),
        val rmsError: Double = 0.0,
        val errorMessage: String? = null
    )

    companion object {
        init {
            // Load the native library if needed for other things, but OpenCV JAR loads its own natives usually.
            // Often "opencv_java4" or similar.
            System.loadLibrary("photogrammetry")
        }
    }

    // IMPORTANT: Remove the generic native method definition since we are using Kotlin wrappers now.
    // external fun performCalibration(...) 

    fun calibrateCamera(
        imagePaths: List<String>,
        boardWidth: Int,
        boardHeight: Int,
        squareSize: Float,
        markerLength: Float, // Received from Dart
        targetType: String,
        dictionaryId: String
    ): CalibrationResult {
        return try {
            Log.d("CameraCalibration", "Starting Kotlin-based ChArUco calibration. Images: ${imagePaths.size}")

            if (targetType != "ChArUco") {
                 return CalibrationResult(success = false, errorMessage = "Only ChArUco is supported in this implementation")
            }
            
            val markerSize = if (markerLength > 0) markerLength else squareSize * 0.8f

            // 1. Setup Dictionary
            // Supported: DICT_4X4_50, _100, _250, _1000, etc.
            val dictCode = when(dictionaryId) {
                "DICT_4x4_50" -> Aruco.DICT_4X4_50
                "DICT_4x4_100" -> Aruco.DICT_4X4_100
                "DICT_4x4_250" -> Aruco.DICT_4X4_250
                "DICT_4x4_1000" -> Aruco.DICT_4X4_1000
                "DICT_5x5_50" -> Aruco.DICT_5X5_50
                "DICT_5x5_100" -> Aruco.DICT_5X5_100
                "DICT_5x5_250" -> Aruco.DICT_5X5_250
                "DICT_5x5_1000" -> Aruco.DICT_5X5_1000
                "DICT_6x6_50" -> Aruco.DICT_6X6_50
                "DICT_6x6_100" -> Aruco.DICT_6X6_100
                "DICT_6x6_250" -> Aruco.DICT_6X6_250
                "DICT_6x6_1000" -> Aruco.DICT_6X6_1000
                // Legacy/Short fallbacks
                "DICT_4x4" -> Aruco.DICT_4X4_50
                "DICT_5x5" -> Aruco.DICT_5X5_50
                "DICT_6x6" -> Aruco.DICT_6X6_50
                else -> Aruco.DICT_4X4_50
            }
            val dictionary = Aruco.getPredefinedDictionary(dictCode)

            // 2. Setup Board
            // CharucoBoard.create(int squaresX, int squaresY, float squareLength, float markerLength, Dictionary dictionary)
            val board = CharucoBoard.create(boardWidth, boardHeight, squareSize, markerSize, dictionary)

            // 3. Detect
            val allCharucoCorners = ArrayList<Mat>()
            val allCharucoIds = ArrayList<Mat>()
            
            var width = 0
            var height = 0

            for (path in imagePaths) {
                val img = Imgcodecs.imread(path)
                if (img.empty()) continue
                
                // Consistency Check
                if (width == 0) {
                    width = img.cols()
                    height = img.rows()
                } else {
                    if (img.cols() != width || img.rows() != height) {
                        Log.w("CameraCalibration", "Skipping image $path due to size mismatch: ${img.cols()}x${img.rows()} vs ${width}x${height}")
                        img.release()
                        continue
                    }
                }

                val markerCorners = ArrayList<Mat>()
                val markerIds = Mat()
                
                // Detect Markers
                Aruco.detectMarkers(img, dictionary, markerCorners, markerIds)

                if (markerIds.rows() > 0) {
                    val charucoCorners = Mat()
                    val charucoIds = Mat()
                    
                    // Interpolate Charuco
                    Aruco.interpolateCornersCharuco(markerCorners, markerIds, img, board, charucoCorners, charucoIds)
                    
                    if (charucoIds.rows() > 4) {
                        allCharucoCorners.add(charucoCorners)
                        allCharucoIds.add(charucoIds)
                    }
                }
                img.release()
            }

            if (allCharucoCorners.size < 5) {
                return CalibrationResult(success = false, errorMessage = "Not enough valid frames (detected ${allCharucoCorners.size} boards, need 5+)")
            }

            // 4. Calibrate
            val cameraMatrix = Mat.eye(3, 3, CvType.CV_64F)
            val distCoeffs = Mat()
            val rvecs = ArrayList<Mat>()
            val tvecs = ArrayList<Mat>()
            
            val imageSize = Size(width.toDouble(), height.toDouble())

            val rms = Aruco.calibrateCameraCharuco(
                allCharucoCorners,
                allCharucoIds,
                board,
                imageSize,
                cameraMatrix,
                distCoeffs,
                rvecs,
                tvecs
            )

            // 5. Extract Result
            val fx = cameraMatrix.get(0, 0)[0]
            val fy = cameraMatrix.get(1, 1)[0]
            val cx = cameraMatrix.get(0, 2)[0]
            val cy = cameraMatrix.get(1, 2)[0]
            
            val distArray = DoubleArray(distCoeffs.total().toInt())
            distCoeffs.get(0, 0, distArray)

            CalibrationResult(
                success = true,
                fx = fx,
                fy = fy,
                cx = cx,
                cy = cy,
                distortionCoefficients = distArray,
                rmsError = rms
            )

        } catch (e: Exception) {
            e.printStackTrace()
            // Check for linkage errors
            if (e is UnsatisfiedLinkError || e is NoClassDefFoundError) {
                 CalibrationResult(success = false, errorMessage = "OpenCV Linkage Error: ${e.message}. Ensure opencv-contrib is included.")
            } else {
                 CalibrationResult(success = false, errorMessage = e.message)
            }
        }
    }
    
    fun detectChessboard(imagePath: String, width: Int, height: Int): Boolean {
        // Placeholder
        return false
    }
}
