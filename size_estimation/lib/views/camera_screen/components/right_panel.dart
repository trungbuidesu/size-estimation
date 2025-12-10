import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class RightPanel extends StatelessWidget {
  final Animation<double> animation;
  final bool isFlashOn;
  final bool isInitialized;
  final CameraController? controller;
  final VoidCallback onToggleFlash;
  final VoidCallback onClose;
  final GlobalKey settingsButtonKey;

  const RightPanel({
    super.key,
    required this.animation,
    required this.isFlashOn,
    required this.isInitialized,
    required this.controller,
    required this.onToggleFlash,
    required this.onClose,
    required this.settingsButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the safe area top to position the panel below the top bar
    final safeAreaTop = MediaQuery.of(context).padding.top;

    // Animation for sliding down and fading in
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.2), // Start slightly above
      end: Offset.zero,
    ).animate(animation);

    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    return Positioned.fill(
      child: Stack(
        children: [
          // 1. Invisible backdrop to close panel when tapping on empty space
          // Only active when animation > 0 to render hits
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return animation.value > 0
                  ? GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    )
                  : const SizedBox.shrink();
            },
          ),

          // 2. The Floating Settings Card
          Positioned(
            top: safeAreaTop + 60, // Position below the top toolbar
            left: 16,
            right: 16,
            child: SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818)
                        .withOpacity(0.95), // Deep dark background
                    borderRadius: BorderRadius.circular(28),
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
                            onTapAction: (controller != null &&
                                    isInitialized &&
                                    isFlashOn)
                                ? onToggleFlash
                                : (() {
                                    if (isFlashOn) onToggleFlash();
                                  }),
                          ),
                          const SizedBox(width: 12),
                          _buildOptionButton(
                            const Icon(Icons.flash_on, size: 20),
                            isSelected: isFlashOn,
                            onTapAction: (controller != null &&
                                    isInitialized &&
                                    !isFlashOn)
                                ? onToggleFlash
                                : (() {
                                    if (!isFlashOn) onToggleFlash();
                                  }),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- Timer (Visual Only) ---
                      _buildSettingRow(
                        title: 'TIMER',
                        currentValue: 'Off',
                        children: [
                          _buildOptionButton(
                            const Icon(Icons.timer_off_outlined, size: 20),
                            isSelected: true,
                            onTapAction: () {},
                          ),
                          const SizedBox(width: 12),
                          _buildCircleTextButton(
                            '3s',
                            isSelected: false,
                            onTap: () {},
                          ),
                          const SizedBox(width: 12),
                          _buildCircleTextButton(
                            '10s',
                            isSelected: false,
                            onTap: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- Ratio (Visual Only) ---
                      _buildSettingRow(
                        title: 'RATIO',
                        currentValue: 'Full view',
                        children: [
                          _buildOptionButton(
                            const Icon(Icons.crop_free,
                                size: 20), // "Wide" approximation
                            isSelected: true,
                            onTapAction: () {},
                          ),
                          const SizedBox(width: 12),
                          _buildOptionButton(
                            const Icon(Icons.aspect_ratio,
                                size: 20), // 3:4 approximation
                            isSelected: false,
                            onTapAction: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      // Bottom Gear / More Settings
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () {
                            // Navigate to deeper settings if implemented
                          },
                          icon:
                              const Icon(Icons.settings, color: Colors.white70),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
                  color: Color(0xFFA8C7FA), // Google Blue-ish tint
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Right Side: Toggle Buttons
        Expanded(
          flex: 6,
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
}
