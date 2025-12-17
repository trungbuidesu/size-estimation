import 'package:flutter/material.dart';
import 'package:size_estimation/models/calibration_profile.dart';

class CalibrationDisplayWidget extends StatelessWidget {
  final CalibrationProfile? profile;

  const CalibrationDisplayWidget({
    super.key,
    this.profile,
  });

  Widget _buildRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            'Chưa có profile hiệu chỉnh',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Intrinsic Parameters",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildRow(
              context, "Focal Length X (fx):", profile!.fx.toStringAsFixed(2)),
          _buildRow(
              context, "Focal Length Y (fy):", profile!.fy.toStringAsFixed(2)),
          _buildRow(context, "Principal Point X (cx):",
              profile!.cx.toStringAsFixed(2)),
          _buildRow(context, "Principal Point Y (cy):",
              profile!.cy.toStringAsFixed(2)),
          const Divider(height: 24),
          Text("Distortion Coefficients",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (profile!.distortionCoefficients.isNotEmpty)
            Wrap(spacing: 16, runSpacing: 8, children: [
              if (profile!.distortionCoefficients.length > 0)
                _buildCompact(context, "k1",
                    profile!.distortionCoefficients[0].toStringAsFixed(4)),
              if (profile!.distortionCoefficients.length > 1)
                _buildCompact(context, "k2",
                    profile!.distortionCoefficients[1].toStringAsFixed(4)),
              if (profile!.distortionCoefficients.length > 4)
                _buildCompact(context, "k3",
                    profile!.distortionCoefficients[4].toStringAsFixed(4)),
              if (profile!.distortionCoefficients.length > 2)
                _buildCompact(context, "p1",
                    profile!.distortionCoefficients[2].toStringAsFixed(4)),
              if (profile!.distortionCoefficients.length > 3)
                _buildCompact(context, "p2",
                    profile!.distortionCoefficients[3].toStringAsFixed(4)),
            ])
          else
            Text(
              'Không có distortion coefficients',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}
