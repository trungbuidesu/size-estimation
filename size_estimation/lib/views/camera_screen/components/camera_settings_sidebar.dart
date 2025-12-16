import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:size_estimation/models/researcher_config.dart';
import 'package:size_estimation/constants/translate.dart';
import 'package:size_estimation/views/camera_screen/animations/index.dart';

class CameraSettingsSidebar extends StatelessWidget {
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
  final VoidCallback? onShowMathDetails;

  // Advanced Processing
  final bool? applyUndistortion;
  final ValueChanged<bool>? onUndistortionChanged;
  final bool? edgeSnapping;
  final ValueChanged<bool>? onEdgeSnappingChanged;
  final bool? multiFrameMode;
  final ValueChanged<bool>? onMultiFrameModeChanged;

  const CameraSettingsSidebar({
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
    this.applyUndistortion,
    this.onUndistortionChanged,
    this.edgeSnapping, // Keep one
    this.onEdgeSnappingChanged, // Keep one
    this.multiFrameMode,
    this.onMultiFrameModeChanged,
    this.onShowMathDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeAreaTop = MediaQuery.of(context).padding.top;

    final slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Slide from right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

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
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.zero, // Full height
                  child: SlideTransition(
                    position: slideAnimation,
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity! > 500) {
                            // Swipe Right to Close
                            onClose();
                          }
                        },
                        child: Container(
                          width: 300, // Fixed width sidebar
                          height: double.infinity,
                          padding: EdgeInsets.only(
                              top: safeAreaTop + 20,
                              bottom: 20,
                              left: 20,
                              right: 20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(24)),
                            border: Border(
                              left: BorderSide(
                                  color: theme.dividerColor, width: 1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // --- Flash Setting ---
                                _buildSettingRow(
                                  context,
                                  title: 'FLASH',
                                  currentValue: isFlashOn ? 'On' : 'Off',
                                  children: [
                                    _buildOptionButton(
                                      context,
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

                                // --- Zoom Setting ---
                                _buildSettingRow(
                                  context,
                                  title: 'ZOOM',
                                  currentValue:
                                      '${currentZoom.toStringAsFixed(1)}x',
                                  children: [
                                    SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor:
                                            theme.colorScheme.primary,
                                        inactiveTrackColor: theme.dividerColor,
                                        thumbColor: Colors.white,
                                        overlayColor: theme.colorScheme.primary
                                            .withOpacity(0.2),
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 8),
                                      ),
                                      child: Slider(
                                        value:
                                            currentZoom.clamp(minZoom, maxZoom),
                                        min: minZoom,
                                        max: maxZoom,
                                        onChanged: (minZoom < maxZoom)
                                            ? onZoomChanged
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // --- Timer Setting ---
                                _buildSettingRow(
                                  context,
                                  title: 'TIMER',
                                  currentValue: timerDuration == 0
                                      ? 'Off'
                                      : '${timerDuration}s',
                                  children: [
                                    _buildSegmentedControl<int>(
                                      context,
                                      items: timerPresets
                                          .map((p) => MapEntry('$p\s', p))
                                          .toList(),
                                      selectedValue: timerDuration,
                                      onChanged: (val) => onTimerChanged(
                                          timerDuration == val ? 0 : val),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // --- Ratio Setting ---
                                _buildSettingRow(
                                  context,
                                  title: 'RATIO',
                                  currentValue:
                                      _getRatioLabel(aspectRatioIndex),
                                  children: [
                                    _buildSegmentedControl<int>(
                                      context,
                                      items: const [
                                        MapEntry('1:1', 0),
                                        MapEntry('4:3', 1),
                                        MapEntry('16:9', 2),
                                      ],
                                      selectedValue: aspectRatioIndex,
                                      onChanged: onAspectRatioChanged,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // --- Researcher/Debug Mode ---
                                _buildSettingRow(
                                  context,
                                  title: 'ADVANCED',
                                  currentValue: isDebugVisible ? 'On' : 'Off',
                                  children: [
                                    _buildOptionButton(
                                      context,
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

                                if (researcherConfig != null)
                                  IgnorePointer(
                                    ignoring: !isDebugVisible,
                                    child: AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      opacity: isDebugVisible ? 1.0 : 0.5,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Divider(
                                              height: 32,
                                              color: theme.dividerColor),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text("CALIBRATION TOOLS",
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withOpacity(0.5),
                                                  fontWeight: FontWeight.bold,
                                                )),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildActionButton(
                                            context,
                                            "Show K Matrix",
                                            Icons.grid_3x3,
                                            onShowKMatrix,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildActionButton(
                                            context,
                                            "Show IMU Orientation",
                                            Icons.explore,
                                            onShowIMU,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildActionButton(
                                            context,
                                            "Calibration Playground",
                                            Icons.tune,
                                            onCalibrationPlayground,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildActionButton(
                                            context,
                                            "Math Details",
                                            Icons.functions,
                                            onShowMathDetails,
                                          ),
                                          const SizedBox(height: 16),
                                          Divider(
                                              height: 1,
                                              color: theme.dividerColor),
                                          const SizedBox(height: 16),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text("TÍNH NĂNG NÂNG CAO",
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withOpacity(0.5),
                                                  fontWeight: FontWeight.bold,
                                                )),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildResearcherSwitch(
                                              context,
                                              "Enable Grid", // Moved from Researcher Options
                                              researcherConfig!.showGrid, (v) {
                                            researcherConfig!.showGrid = v;
                                            onConfigChanged
                                                ?.call(researcherConfig!);
                                          }, onInfoTap: () {
                                            // TODO: Show info for Grid
                                          }),
                                          if (applyUndistortion != null &&
                                              onUndistortionChanged != null)
                                            _buildResearcherSwitch(
                                                context,
                                                "Lens Undistortion",
                                                applyUndistortion!, (v) {
                                              onUndistortionChanged!(v);
                                            }, onInfoTap: () {
                                              // TODO: Show info for Undistortion
                                            }),
                                          if (edgeSnapping != null &&
                                              onEdgeSnappingChanged != null)
                                            _buildResearcherSwitch(
                                                context,
                                                "Edge Snapping",
                                                edgeSnapping!, (v) {
                                              onEdgeSnappingChanged!(v);
                                            }, onInfoTap: () {
                                              // TODO: Show info for Edge Snapping
                                            }),
                                          if (multiFrameMode != null &&
                                              onMultiFrameModeChanged != null)
                                            _buildResearcherSwitch(
                                                context,
                                                "Multi-frame Averaging",
                                                multiFrameMode!, (v) {
                                              onMultiFrameModeChanged!(v);
                                            }, onInfoTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: Text(AppStrings
                                                      .multiFrameAveragingTitle),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // Animation Placeholder
                                                      const SizedBox(
                                                        height: 120,
                                                        width: 200,
                                                        child:
                                                            MultiFrameAnimation(),
                                                      ),
                                                      const SizedBox(
                                                          height: 16),
                                                      Text(
                                                        AppStrings
                                                            .multiFrameAveragingProcess,
                                                        style: const TextStyle(
                                                            fontSize: 14),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        AppStrings
                                                            .multiFrameAveragingBenefit,
                                                        style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(),
                                                      child: Text(
                                                          AppStrings.close),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          const SizedBox(height: 16),
                                          Divider(
                                              height: 1,
                                              color: theme.dividerColor),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

  Widget _buildSettingRow(
    BuildContext context, {
    required String title,
    required String currentValue,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentValue,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildResearcherSwitch(BuildContext context, String label, bool value,
      ValueChanged<bool> onChanged,
      {VoidCallback? onInfoTap}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onLongPress: onInfoTap,
                child: Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    )),
              ),
              if (onInfoTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: GestureDetector(
                    onTap: onInfoTap,
                    child: Icon(Icons.info_outline,
                        size: 16, color: theme.colorScheme.primary),
                  ),
                ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            // Defaults from theme
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, String label, IconData icon, VoidCallback? onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.iconTheme.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: theme.disabledColor),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context,
    Widget icon, {
    required bool isSelected,
    required VoidCallback onTapAction,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTapAction,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onInverseSurface,
        ),
        child: Theme(
          data: ThemeData(
              iconTheme: IconThemeData(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.iconTheme.color,
          )),
          child: Center(child: icon),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl<T>(
    BuildContext context, {
    required List<MapEntry<String, T>> items,
    required T selectedValue,
    required ValueChanged<T> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = item.value == selectedValue;
          final isFirst = index == 0;
          final isLast = index == items.length - 1;

          return GestureDetector(
            onTap: () => onChanged(item.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.horizontal(
                  left: isFirst ? const Radius.circular(7) : Radius.zero,
                  right: isLast ? const Radius.circular(7) : Radius.zero,
                ),
              ),
              child: Text(
                item.key,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).expand((widget) {
          // Add dividers between unselected items if needed, but simple row is fine for now.
          // Or better, just return the widget. The design requested "button group".
          return [widget];
        }).toList(),
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
