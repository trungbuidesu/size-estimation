import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:size_estimation/models/researcher_config.dart';

class CameraSettingsOverlay extends StatelessWidget {
  final Animation<double> animation;
  final bool isFlashOn;
  final bool isInitialized;
  final CameraController? controller;
  final VoidCallback onToggleFlash;
  final VoidCallback onClose;
  final GlobalKey settingsButtonKey;

  // New properties
  final int timerDuration; // 0, 3, 10
  final ValueChanged<int> onTimerChanged;
  final List<int> timerPresets;
  final int aspectRatioIndex; // 0 = Full, 1 = 4:3
  final ValueChanged<int> onAspectRatioChanged;

  // Zoom properties
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;

  // Debug properties
  final bool isDebugVisible;
  final VoidCallback onToggleDebug;

  // Researcher Config
  final ResearcherConfig? researcherConfig;
  final ValueChanged<ResearcherConfig>? onConfigChanged;

  // Calibration actions
  final VoidCallback? onShowKMatrix;
  final VoidCallback? onShowIMU;
  final VoidCallback? onCalibrationPlayground;

  // Ground Plane Measurement
  final bool? groundPlaneMode;
  final ValueChanged<bool>? onGroundPlaneModeChanged;
  final double? cameraHeightMeters;
  final ValueChanged<double>? onCameraHeightChanged;

  // Planar Object Measurement
  final bool? planarObjectMode;
  final ValueChanged<bool>? onPlanarObjectModeChanged;
  final String? referenceObject;
  final ValueChanged<String?>? onReferenceObjectChanged;

  // Vertical Object Measurement
  final bool? verticalObjectMode;
  final ValueChanged<bool>? onVerticalObjectModeChanged;

  // Advanced Processing
  final bool? applyUndistortion;
  final ValueChanged<bool>? onUndistortionChanged;
  final bool? edgeSnapping;
  final ValueChanged<bool>? onEdgeSnappingChanged;
  final bool? multiFrameMode;
  final ValueChanged<bool>? onMultiFrameModeChanged;

  const CameraSettingsOverlay({
    super.key,
    required this.animation,
    required this.isFlashOn,
    required this.isInitialized,
    required this.controller,
    required this.onToggleFlash,
    required this.onClose,
    required this.settingsButtonKey,
    required this.timerDuration,
    required this.onTimerChanged,
    required this.timerPresets,
    required this.aspectRatioIndex,
    required this.onAspectRatioChanged,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
    required this.isDebugVisible,
    required this.onToggleDebug,
    this.researcherConfig,
    this.onConfigChanged,
    this.onShowKMatrix,
    this.onShowIMU,
    this.onCalibrationPlayground,
    this.groundPlaneMode,
    this.onGroundPlaneModeChanged,
    this.cameraHeightMeters,
    this.onCameraHeightChanged,
    this.planarObjectMode,
    this.onPlanarObjectModeChanged,
    this.referenceObject,
    this.onReferenceObjectChanged,
    this.verticalObjectMode,
    this.onVerticalObjectModeChanged,
    this.applyUndistortion,
    this.onUndistortionChanged,
    this.edgeSnapping,
    this.onEdgeSnappingChanged,
    this.multiFrameMode,
    this.onMultiFrameModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.2),
      end: Offset.zero,
    ).animate(animation);

    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (animation.value == 0) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: safeAreaTop + 60,
                    left: 16,
                    right: 16,
                  ),
                  child: SlideTransition(
                    position: slideAnimation,
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: 400,
                          maxHeight: MediaQuery.of(context).size.height * 0.85,
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181818).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // --- Flash Setting ---
                              _buildSettingRow(
                                title: 'FLASH',
                                currentValue: isFlashOn ? 'On' : 'Off',
                                children: [
                                  _buildOptionButton(
                                    Icon(
                                        isFlashOn
                                            ? Icons.flash_on
                                            : Icons.flash_off,
                                        size: 20),
                                    isSelected: isFlashOn,
                                    onTapAction: onToggleFlash,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // --- Zoom Setting (Moved from Bottom) ---
                              _buildSettingRow(
                                title: 'ZOOM',
                                currentValue:
                                    '${currentZoom.toStringAsFixed(1)}x',
                                children: [
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor:
                                            const Color(0xFFA8C7FA),
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                        overlayColor: const Color(0xFFA8C7FA)
                                            .withOpacity(0.2),
                                        trackHeight: 2,
                                        disabledThumbColor: Colors
                                            .grey, // Visual feedback for disabled
                                        disabledActiveTrackColor:
                                            Colors.grey.withOpacity(0.5),
                                      ),
                                      child: Slider(
                                        value: currentZoom.clamp(
                                            minZoom, maxZoom), // Safely clamp
                                        min: minZoom,
                                        max: maxZoom,
                                        // Logic: If min == max, disable slider (return null)
                                        onChanged: (minZoom < maxZoom)
                                            ? onZoomChanged
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // --- Timer Setting ---
                              _buildSettingRow(
                                title: 'TIMER',
                                currentValue: timerDuration == 0
                                    ? 'Off'
                                    : '${timerDuration}s',
                                children: timerPresets.map((preset) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: _buildCircleTextButton(
                                      '${preset}s',
                                      isSelected: timerDuration == preset,
                                      onTap: () => onTimerChanged(
                                          timerDuration == preset ? 0 : preset),
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 24),

                              // --- Ratio Setting ---
                              _buildSettingRow(
                                title: 'RATIO',
                                currentValue: _getRatioLabel(aspectRatioIndex),
                                children: [
                                  _buildCircleTextButton(
                                    '1:1',
                                    isSelected: aspectRatioIndex == 0,
                                    onTap: () => onAspectRatioChanged(0),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildCircleTextButton(
                                    '4:3',
                                    isSelected: aspectRatioIndex == 1,
                                    onTap: () => onAspectRatioChanged(1),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildCircleTextButton(
                                    '16:9',
                                    isSelected: aspectRatioIndex == 2,
                                    onTap: () => onAspectRatioChanged(2),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // --- Researcher/Debug Mode ---
                              _buildSettingRow(
                                title: 'ADVANCED',
                                currentValue: isDebugVisible ? 'On' : 'Off',
                                children: [
                                  _buildOptionButton(
                                    Icon(
                                        isDebugVisible
                                            ? Icons.science
                                            : Icons.science_outlined,
                                        size: 20),
                                    isSelected: isDebugVisible,
                                    onTapAction: onToggleDebug,
                                  ),
                                ],
                              ),

                              // Detailed Researcher Options
                              if (isDebugVisible &&
                                  researcherConfig != null) ...[
                                const Divider(
                                    height: 32, color: Colors.white24),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text("RESEARCHER OPTIONS",
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                                ),
                                const SizedBox(height: 8),
                                _buildResearcherSwitch(
                                    "Show Grid", researcherConfig!.showGrid,
                                    (v) {
                                  researcherConfig!.showGrid = v;
                                  onConfigChanged?.call(researcherConfig!);
                                }),
                                _buildResearcherSwitch(
                                    "Show IMU", researcherConfig!.showImuInfo,
                                    (v) {
                                  researcherConfig!.showImuInfo = v;
                                  onConfigChanged?.call(researcherConfig!);
                                }),
                                _buildResearcherSwitch("Undistort",
                                    researcherConfig!.applyUndistortion, (v) {
                                  researcherConfig!.applyUndistortion = v;
                                  onConfigChanged?.call(researcherConfig!);
                                }),
                                _buildResearcherSwitch("Edge Snapping",
                                    researcherConfig!.edgeBasedSnapping, (v) {
                                  researcherConfig!.edgeBasedSnapping = v;
                                  onConfigChanged?.call(researcherConfig!);
                                }),

                                const SizedBox(height: 16),
                                const Divider(height: 1, color: Colors.white24),
                                const SizedBox(height: 16),

                                // Calibration Tools
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text("CALIBRATION TOOLS",
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                                ),
                                const SizedBox(height: 8),

                                _buildActionButton(
                                  "Show K Matrix",
                                  Icons.grid_3x3,
                                  onShowKMatrix,
                                ),
                                const SizedBox(height: 8),
                                _buildActionButton(
                                  "Show IMU Orientation",
                                  Icons.explore,
                                  onShowIMU,
                                ),
                                const SizedBox(height: 8),
                                _buildActionButton(
                                  "Calibration Playground",
                                  Icons.tune,
                                  onCalibrationPlayground,
                                ),

                                const SizedBox(height: 16),
                                const Divider(height: 1, color: Colors.white24),
                                const SizedBox(height: 16),

                                // Advanced Processing
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text("ADVANCED PROCESSING",
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                                ),
                                const SizedBox(height: 8),

                                if (applyUndistortion != null &&
                                    onUndistortionChanged != null)
                                  _buildResearcherSwitch(
                                      "Lens Undistortion", applyUndistortion!,
                                      (v) {
                                    onUndistortionChanged!(v);
                                  }),

                                if (edgeSnapping != null &&
                                    onEdgeSnappingChanged != null)
                                  _buildResearcherSwitch(
                                      "Edge Snapping", edgeSnapping!, (v) {
                                    onEdgeSnappingChanged!(v);
                                  }),

                                if (multiFrameMode != null &&
                                    onMultiFrameModeChanged != null)
                                  _buildResearcherSwitch(
                                      "Multi-frame Averaging", multiFrameMode!,
                                      (v) {
                                    onMultiFrameModeChanged!(v);
                                  }),

                                const SizedBox(height: 16),
                                const Divider(height: 1, color: Colors.white24),
                                const SizedBox(height: 16),

                                // Measurement Modes (Debug/Researcher Only)
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text("MEASUREMENT MODES (DEBUG)",
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Use swipe gesture on camera screen to activate modes",
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Ground Plane Mode (Debug Info Only)
                                if (groundPlaneMode != null &&
                                    onGroundPlaneModeChanged != null)
                                  _buildResearcherSwitch(
                                      "Ground Plane Mode (Debug)",
                                      groundPlaneMode!, (v) {
                                    onGroundPlaneModeChanged!(v);
                                  }),

                                // Camera Height Input (Only if ground plane is active)
                                if (groundPlaneMode == true &&
                                    cameraHeightMeters != null &&
                                    onCameraHeightChanged != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        const Text(
                                          "Camera Height:",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Slider(
                                            value: cameraHeightMeters!,
                                            min: 0.1,
                                            max: 3.0,
                                            divisions: 29,
                                            label:
                                                '${cameraHeightMeters!.toStringAsFixed(1)}m',
                                            onChanged: onCameraHeightChanged,
                                          ),
                                        ),
                                        Text(
                                          '${cameraHeightMeters!.toStringAsFixed(1)}m',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Planar Object Mode (Debug Info Only)
                                if (planarObjectMode != null &&
                                    onPlanarObjectModeChanged != null)
                                  _buildResearcherSwitch(
                                      "Planar Object Mode (Debug)",
                                      planarObjectMode!, (v) {
                                    onPlanarObjectModeChanged!(v);
                                  }),

                                // Reference Object Selector (Only if planar mode is active)
                                if (planarObjectMode == true &&
                                    referenceObject != null &&
                                    onReferenceObjectChanged != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Reference Object:",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        DropdownButton<String?>(
                                          value: referenceObject,
                                          isExpanded: true,
                                          dropdownColor:
                                              const Color(0xFF181818),
                                          style: const TextStyle(
                                              color: Colors.white),
                                          items: [
                                            const DropdownMenuItem(
                                              value: null,
                                              child: Text('None (Auto-detect)'),
                                            ),
                                            ...[
                                              'A4 Paper',
                                              'A5 Paper',
                                              'Letter Paper',
                                              'Credit Card',
                                              'iPhone 14',
                                              'iPad'
                                            ].map((ref) => DropdownMenuItem(
                                                  value: ref,
                                                  child: Text(ref),
                                                )),
                                          ],
                                          onChanged: onReferenceObjectChanged,
                                        ),
                                      ],
                                    ),
                                  ),

                                // Vertical Object Mode (Debug Info Only)
                                if (verticalObjectMode != null &&
                                    onVerticalObjectModeChanged != null)
                                  _buildResearcherSwitch(
                                      "Vertical Object Mode (Debug)",
                                      verticalObjectMode!, (v) {
                                    onVerticalObjectModeChanged!(v);
                                  }),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingRow({
    required String title,
    required String currentValue,
    required List<Widget> children,
  }) {
    return Row(
      children: [
        // Left Side: Label and Value
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentValue,
                style: const TextStyle(
                  color: Color(0xFFA8C7FA),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Right Side: Toggle Buttons
        Expanded(
          flex: 7, // Give more space for buttons if needed
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildResearcherSwitch(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.yellowAccent,
            activeTrackColor: Colors.yellowAccent.withOpacity(0.4),
            inactiveThumbColor: Colors.white70,
            inactiveTrackColor: Colors.white12,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    Widget icon, {
    required bool isSelected,
    required VoidCallback onTapAction,
  }) {
    return GestureDetector(
      onTap: onTapAction,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? const Color(0xFFA8C7FA)
              : Colors.white.withOpacity(0.1),
        ),
        child: Theme(
          data: ThemeData(
              iconTheme: IconThemeData(
            color: isSelected ? const Color(0xFF000000) : Colors.white,
          )),
          child: Center(child: icon),
        ),
      ),
    );
  }

  Widget _buildCircleTextButton(
    String text, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? const Color(0xFFA8C7FA)
              : Colors.white.withOpacity(0.1),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  String _getRatioLabel(int index) {
    switch (index) {
      case 0:
        return '1:1';
      case 1:
        return '4:3';
      case 2:
        return '16:9';
      default:
        return '4:3';
    }
  }
}
