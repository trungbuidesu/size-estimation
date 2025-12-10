import 'package:flutter/material.dart';
import 'package:size_estimation/models/captured_image.dart';

class ImageDetailModal extends StatelessWidget {
  final CapturedImage image;
  final int index;

  const ImageDetailModal({super.key, required this.image, required this.index});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blurred background or dark overlay handled by Dialog barrier usually,
          // but we can add a container for style.
          Container(
            decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black54, blurRadius: 20, spreadRadius: 5)
                ]),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Ảnh ${index + 1}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ),
                const SizedBox(height: 10),

                // Image
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      image.file,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Attributes / Warnings
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Thuộc tính:",
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("• Đường dẫn: ${image.file.path.split('/').last}",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      // Add more mock data if real data missing
                      const SizedBox(height: 10),
                      if (image.hasWarnings) ...[
                        const Text("Cảnh báo:",
                            style: TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold)),
                        for (var w in image.warnings)
                          Text("• $w",
                              style: const TextStyle(
                                  color: Colors.orange, fontSize: 12)),
                      ] else
                        const Text("Trạng thái: Tốt (Không có cảnh báo)",
                            style: TextStyle(
                                color: Colors.greenAccent, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
