package com.example.size_estimation

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.common.FileUtil
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.util.Collections
import kotlin.math.max
import kotlin.math.min

data class BoundingBox(
    val x1: Float,
    val y1: Float,
    val x2: Float,
    val y2: Float,
    val cx: Float,
    val cy: Float,
    val w: Float,
    val h: Float,
    val cnf: Float,
    val cls: Int,
    val clsName: String
)

class YoloDetector(
    private val context: Context,
    private val modelPath: String,
    private val labelPath: String
) {
    private var interpreter: Interpreter? = null
    private var labels = emptyList<String>()
    
    // Model parameters (standard YOLOv8n)
    private val inputSize = 640
    private val numClass = 80 // COCO
    private val outputSize = 8400 // default anchors
    
    // Config
    private val confThreshold = 0.25f
    private val iouThreshold = 0.45f

    fun init() {
        val options = Interpreter.Options()
        interpreter = Interpreter(loadModelFile(modelPath), options)
        labels = FileUtil.loadLabels(context, labelPath)
    }

    private fun loadModelFile(path: String): MappedByteBuffer {
        val fileDescriptor = context.assets.openFd(path)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }

    fun detect(imagePath: String): List<Map<String, Any>> {
        if (interpreter == null) init()

        val bitmap = BitmapFactory.decodeFile(imagePath) ?: return emptyList()
        val rotatedBitmap = rotateBitmap(bitmap) // Handle rotation? Usually Flutter handles it or we pass it? 
        // ML Kit handles InputImage rotation from file. 
        // Here we assume image is upright or we need exiff extraction. 
        // Ideally we should handle EXIF. For now, basic decode.

        val (resizedBitmap, ratio, padding) = resizeAndPad(rotatedBitmap)
        val byteBuffer = convertBitmapToByteBuffer(resizedBitmap)

        val output = Array(1) { Array(4 + numClass) { FloatArray(outputSize) } }
        interpreter?.run(byteBuffer, output)

        val boxes = parseOutput(output, ratio, padding)
        val nmsBoxes = applyNMS(boxes)

        return nmsBoxes.map { box ->
            mapOf(
                "rect" to mapOf(
                    "left" to box.x1 / rotatedBitmap.width, // Normalize
                    "top" to box.y1 / rotatedBitmap.height,
                    "right" to box.x2 / rotatedBitmap.width,
                    "bottom" to box.y2 / rotatedBitmap.height,
                    "width" to box.w / rotatedBitmap.width,
                    "height" to box.h / rotatedBitmap.height,
                ),
                "confidence" to box.cnf,
                "label" to box.clsName,
                "classIndex" to box.cls
            )
        }
    }
    
    // Simple EXIF handling not included for brevity, assuming upright images or handled by flutter camera
    private fun rotateBitmap(bitmap: Bitmap): Bitmap {
        // Implementation omitted for brevity, returning as is
        return bitmap
    }

    private fun resizeAndPad(bitmap: Bitmap): Triple<Bitmap, Float, FloatArray> {
        val w = bitmap.width
        val h = bitmap.height
        val scale = inputSize.toFloat() / max(w, h)
        val newW = (w * scale).toInt()
        val newH = (h * scale).toInt()
        
        val resized = Bitmap.createScaledBitmap(bitmap, newW, newH, true)
        val output = Bitmap.createBitmap(inputSize, inputSize, Bitmap.Config.ARGB_8888)
        
        val canvas = android.graphics.Canvas(output)
        canvas.drawColor(android.graphics.Color.BLACK) // padding color
        canvas.drawBitmap(resized, 0f, 0f, null)
        
        return Triple(output, scale, floatArrayOf(0f, 0f)) // simplified padding calc if needed
    }

    private fun convertBitmapToByteBuffer(bitmap: Bitmap): ByteBuffer {
        val byteBuffer = ByteBuffer.allocateDirect(1 * inputSize * inputSize * 3 * 4)
        byteBuffer.order(ByteOrder.nativeOrder())
        
        val intValues = IntArray(inputSize * inputSize)
        bitmap.getPixels(intValues, 0, inputSize, 0, 0, inputSize, inputSize)
        
        // Normalize 0-255 to 0-1
        for (pixelValue in intValues) {
            byteBuffer.putFloat(((pixelValue shr 16) and 0xFF) / 255.0f)
            byteBuffer.putFloat(((pixelValue shr 8) and 0xFF) / 255.0f)
            byteBuffer.putFloat((pixelValue and 0xFF) / 255.0f)
        }
        return byteBuffer
    }

    private fun parseOutput(output: Array<Array<FloatArray>>, ratio: Float, padding: FloatArray): List<BoundingBox> {
        val boxes = mutableListOf<BoundingBox>()
        // output shape [1, 84, 8400]
        // [0][row][col]
        // row 0: x center
        // row 1: y center
        // row 2: width
        // row 3: height
        // row 4..83: class scores

        val data = output[0] // 84 x 8400
        val rows = data.size // 84
        val cols = data[0].size // 8400

        for (i in 0 until cols) {
            // Find max class score
            var maxScore = 0f
            var maxClassIndex = -1
            for (c in 4 until rows) {
                val score = data[c][i]
                if (score > maxScore) {
                    maxScore = score
                    maxClassIndex = c - 4
                }
            }

            if (maxScore > confThreshold) {
                val cx = data[0][i]
                val cy = data[1][i]
                val w = data[2][i]
                val h = data[3][i]

                val x1 = (cx - w / 2) / ratio
                val y1 = (cy - h / 2) / ratio
                val x2 = (cx + w / 2) / ratio
                val y2 = (cy + h / 2) / ratio
                
                boxes.add(BoundingBox(
                    x1, y1, x2, y2, cx, cy, w / ratio, h / ratio, 
                    maxScore, maxClassIndex, labels.getOrElse(maxClassIndex) { "unknown" }
                ))
            }
        }
        return boxes
    }

    private fun applyNMS(boxes: List<BoundingBox>): List<BoundingBox> {
        val sortedBoxes = boxes.sortedByDescending { it.cnf }
        val selectedBoxes = mutableListOf<BoundingBox>()

        for (box in sortedBoxes) {
            var keep = true
            for (selected in selectedBoxes) {
                if (calculateIoU(box, selected) > iouThreshold) {
                    keep = false
                    break
                }
            }
            if (keep) selectedBoxes.add(box)
        }
        return selectedBoxes
    }

    private fun calculateIoU(box1: BoundingBox, box2: BoundingBox): Float {
        val x1 = max(box1.x1, box2.x1)
        val y1 = max(box1.y1, box2.y1)
        val x2 = min(box1.x2, box2.x2)
        val y2 = min(box1.y2, box2.y2)

        if (x1 >= x2 || y1 >= y2) return 0f

        val intersection = (x2 - x1) * (y2 - y1)
        val area1 = (box1.x2 - box1.x1) * (box1.y2 - box1.y1)
        val area2 = (box2.x2 - box2.x1) * (box2.y2 - box2.y1)
        
        return intersection / (area1 + area2 - intersection)
    }
    
    fun close() {
        interpreter?.close()
    }
}
