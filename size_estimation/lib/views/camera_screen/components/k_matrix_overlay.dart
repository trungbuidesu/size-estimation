import 'package:flutter/material.dart';
import 'package:size_estimation/models/calibration_profile.dart';
import 'package:size_estimation/models/camera_metadata.dart';

class KMatrixOverlay extends StatelessWidget {
  final CalibrationProfile? profile;
  final IntrinsicMatrix? kOut; // Dynamic K_out (takes priority)
  final VoidCallback onClose;

  const KMatrixOverlay({
    super.key,
    this.profile,
    this.kOut,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Use kOut if available, otherwise fall back to profile
    final hasData = kOut != null || profile != null;
    final isDynamic = kOut != null;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_3x3, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Intrinsic Matrix K',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isDynamic)
                        const Text(
                          'Dynamic (K_out)',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasData) ...[
            if (profile != null && !isDynamic)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile!.name,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Source: ${profile!.source}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _buildMatrix(),
            const SizedBox(height: 16),
            if (profile != null) _buildDistortion(profile!),
            if (profile?.rmsError != null && !isDynamic) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRmsColor(profile!.rmsError!).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getRmsIcon(profile!.rmsError!),
                      size: 14,
                      color: _getRmsColor(profile!.rmsError!),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'RMS Error: ${profile!.rmsError!.toStringAsFixed(3)} px',
                      style: TextStyle(
                        color: _getRmsColor(profile!.rmsError!),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else
            const Text(
              'No calibration profile loaded',
              style:
                  TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildMatrix() {
    // Use kOut if available, otherwise use profile
    final fx = kOut?.fx ?? profile?.fx ?? 0;
    final fy = kOut?.fy ?? profile?.fy ?? 0;
    final cx = kOut?.cx ?? profile?.cx ?? 0;
    final cy = kOut?.cy ?? profile?.cy ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'K =',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'Courier',
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMatrixRow(fx, 0, cx),
                    _buildMatrixRow(0, fy, cy),
                    _buildMatrixRow(0, 0, 1),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(double v1, double v2, double v3) {
    return Row(
      children: [
        const Text('[  ',
            style: TextStyle(color: Colors.white70, fontFamily: 'Courier')),
        SizedBox(
          width: 70,
          child: Text(
            v1 == 0 ? '0' : v1.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'Courier',
              fontSize: 12,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            v2 == 0 ? '0' : v2.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'Courier',
              fontSize: 12,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            v3 == 1 ? '1' : v3.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'Courier',
              fontSize: 12,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const Text('  ]',
            style: TextStyle(color: Colors.white70, fontFamily: 'Courier')),
      ],
    );
  }

  Widget _buildDistortion(CalibrationProfile profile) {
    if (profile.distortionCoefficients.isEmpty) {
      return const Text(
        'Distortion: None',
        style: TextStyle(
            color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distortion Coefficients:',
          style: TextStyle(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          profile.distortionCoefficients
              .map((d) => d.toStringAsFixed(4))
              .join(', '),
          style: const TextStyle(
            color: Colors.orangeAccent,
            fontSize: 11,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }

  Color _getRmsColor(double rms) {
    if (rms < 0.5) return Colors.green;
    if (rms < 1.0) return Colors.orange;
    return Colors.red;
  }

  IconData _getRmsIcon(double rms) {
    if (rms < 0.5) return Icons.check_circle;
    if (rms < 1.0) return Icons.warning;
    return Icons.error;
  }
}
