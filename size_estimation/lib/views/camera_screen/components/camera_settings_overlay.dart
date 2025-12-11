import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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
                        constraints: const BoxConstraints(maxWidth: 400),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // --- Flash Setting ---
                            _buildSettingRow(
                              title: 'FLASH',
                              currentValue: isFlashOn ? 'On' : 'Off',
                              children: [
                                _buildOptionButton(
                                  const Icon(Icons.flash_off, size: 20),
                                  isSelected: !isFlashOn,
                                  onTapAction: () {
                                    if (isFlashOn) onToggleFlash();
                                  },
                                ),
                                const SizedBox(width: 12),
                                _buildOptionButton(
                                  const Icon(Icons.flash_on, size: 20),
                                  isSelected: isFlashOn,
                                  onTapAction: () {
                                    if (!isFlashOn) onToggleFlash();
                                  },
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
                                      activeTrackColor: const Color(0xFFA8C7FA),
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

                            // No gear icon
                          ],
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
