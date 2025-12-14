package com.example.size_estimation

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import org.opencv.android.Utils
import org.opencv.calib3d.Calib3d
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.io.File

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
    
    /**
     * Calibrate camera using chessboard images
     * @param imagePaths List of image file paths
     * @param boardWidth Number of inner corners horizontally
     * @param boardHeight Number of inner corners vertically
     * @param squareSize Size of chessboard square in mm
     * @return CalibrationResult
     */
    fun calibrateCamera(
        imagePaths: List<String>,
        boardWidth: Int,
        boardHeight: Int,
        squareSize: Float
    ): CalibrationResult {
        try {
            val boardSize = Size(boardWidth.toDouble(), boardHeight.toDouble())
            val objectPoints = mutableListOf<Mat>()
            val imagePoints = mutableListOf<Mat>()
            
            // Prepare object points (0,0,0), (1,0,0), (2,0,0) ... (boardWidth-1, boardHeight-1, 0)
            val objp = Mat(boardHeight * boardWidth, 1, CvType.CV_32FC3)
            var idx = 0
            for (i in 0 until boardHeight) {
                for (j in 0 until boardWidth) {
                    objp.put(idx++, 0, 
                        floatArrayOf(j * squareSize, i * squareSize, 0f))
                }
            }
            
            var imageSize: Size? = null
            var successCount = 0
            
            // Process each image
            for (imagePath in imagePaths) {
                val bitmap = BitmapFactory.decodeFile(imagePath) ?: continue
                
                // Convert to OpenCV Mat
                val mat = Mat()
                Utils.bitmapToMat(bitmap, mat)
                
                // Convert to grayscale
                val gray = Mat()
                Imgproc.cvtColor(mat, gray, Imgproc.COLOR_BGR2GRAY)
                
                if (imageSize == null) {
                    imageSize = gray.size()
                }
                
                // Find chessboard corners
                val corners = MatOfPoint2f()
                val found = Calib3d.findChessboardCorners(
                    gray,
                    boardSize,
                    corners,
                    Calib3d.CALIB_CB_ADAPTIVE_THRESH + 
                    Calib3d.CALIB_CB_NORMALIZE_IMAGE +
                    Calib3d.CALIB_CB_FAST_CHECK
                )
                
                if (found) {
                    // Refine corner locations to subpixel accuracy
                    val criteria = TermCriteria(
                        TermCriteria.EPS + TermCriteria.MAX_ITER,
                        30,
                        0.001
                    )
                    Imgproc.cornerSubPix(gray, corners, Size(11.0, 11.0), 
                        Size(-1.0, -1.0), criteria)
                    
                    objectPoints.add(objp.clone())
                    imagePoints.add(corners)
                    successCount++
                }
                
                // Clean up
                mat.release()
                gray.release()
                corners.release()
                bitmap.recycle()
            }
            
            if (successCount < 10) {
                return CalibrationResult(
                    success = false,
                    errorMessage = "Not enough valid images. Found $successCount, need at least 10."
                )
            }
            
            if (imageSize == null) {
                return CalibrationResult(
                    success = false,
                    errorMessage = "Could not determine image size"
                )
            }
            
            // Calibrate camera
            val cameraMatrix = Mat()
            val distCoeffs = Mat()
            val rvecs = mutableListOf<Mat>()
            val tvecs = mutableListOf<Mat>()
            
            val rmsError = Calib3d.calibrateCamera(
                objectPoints,
                imagePoints,
                imageSize,
                cameraMatrix,
                distCoeffs,
                rvecs,
                tvecs,
                Calib3d.CALIB_FIX_PRINCIPAL_POINT
            )
            
            // Extract calibration parameters
            val fx = cameraMatrix.get(0, 0)[0]
            val fy = cameraMatrix.get(1, 1)[0]
            val cx = cameraMatrix.get(0, 2)[0]
            val cy = cameraMatrix.get(1, 2)[0]
            
            // Extract distortion coefficients (k1, k2, p1, p2, k3)
            val distArray = DoubleArray(distCoeffs.total().toInt())
            distCoeffs.get(0, 0, distArray)
            
            // Clean up
            objp.release()
            cameraMatrix.release()
            distCoeffs.release()
            objectPoints.forEach { it.release() }
            imagePoints.forEach { it.release() }
            rvecs.forEach { it.release() }
            tvecs.forEach { it.release() }
            
            return CalibrationResult(
                success = true,
                fx = fx,
                fy = fy,
                cx = cx,
                cy = cy,
                distortionCoefficients = distArray,
                rmsError = rmsError
            )
            
        } catch (e: Exception) {
            return CalibrationResult(
                success = false,
                errorMessage = "Calibration failed: ${e.message}"
            )
        }
    }
    
    /**
     * Detect chessboard corners in a single image (for preview/validation)
     */
    fun detectChessboard(
        imagePath: String,
        boardWidth: Int,
        boardHeight: Int
    ): Boolean {
        try {
            val bitmap = BitmapFactory.decodeFile(imagePath) ?: return false
            
            val mat = Mat()
            Utils.bitmapToMat(bitmap, mat)
            
            val gray = Mat()
            Imgproc.cvtColor(mat, gray, Imgproc.COLOR_BGR2GRAY)
            
            val boardSize = Size(boardWidth.toDouble(), boardHeight.toDouble())
            val corners = MatOfPoint2f()
            
            val found = Calib3d.findChessboardCorners(
                gray,
                boardSize,
                corners,
                Calib3d.CALIB_CB_ADAPTIVE_THRESH + 
                Calib3d.CALIB_CB_NORMALIZE_IMAGE +
                Calib3d.CALIB_CB_FAST_CHECK
            )
            
            mat.release()
            gray.release()
            corners.release()
            bitmap.recycle()
            
            return found
        } catch (e: Exception) {
            return false
        }
    }
}
