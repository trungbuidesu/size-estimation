import 'package:flutter/material.dart';
import 'package:size_estimation/models/captured_image.dart';

class CaptureCompletion extends StatefulWidget {
  final List<CapturedImage> images;
  final VoidCallback onRetakeAll;
  final Function(double) onSubmit;

  const CaptureCompletion({
    super.key,
    required this.images,
    required this.onRetakeAll,
    required this.onSubmit,
  });

  @override
  State<CaptureCompletion> createState() => _CaptureCompletionState();
}

class _CaptureCompletionState extends State<CaptureCompletion> {
  final TextEditingController _baselineCtrl =
      TextEditingController(text: "10.0");

  @override
  void dispose() {
    _baselineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle for better UX since it's dismissible now
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Hoàn tất chụp ảnh',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                final img = widget.images[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          img.file,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (img.hasWarnings)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ),
                        )
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _baselineCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Khoảng cách di chuyển (Baseline)',
              suffixText: 'cm',
              border: OutlineInputBorder(),
              helperText: 'Khoảng cách camera di chuyển giữa các lần chụp',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onRetakeAll,
                  child: const Text('Chụp lại'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final baseline = double.tryParse(_baselineCtrl.text);
                    if (baseline == null || baseline <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Vui lòng nhập khoảng cách hợp lệ')),
                      );
                      return;
                    }
                    widget.onSubmit(baseline);
                  },
                  child: const Text('Tính toán'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
