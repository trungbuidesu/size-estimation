import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/constants/index.dart';
import 'package:size_estimation/views/camera_property/index.dart';
import 'package:size_estimation/views/settings_screen/settings_screen.dart';

import 'package:size_estimation/views/methods_screen/components/index.dart';
import 'package:size_estimation/views/shared_components/index.dart';
import 'package:size_estimation/models/calibration_profile.dart';
import 'package:size_estimation/services/calibration_service.dart';
import 'package:size_estimation/views/calibration_screen/profile_selection_dialog.dart';

class MethodsScreen extends StatefulWidget {
  const MethodsScreen({super.key});

  @override
  State<MethodsScreen> createState() => _MethodsScreenState();
}

class _MethodsScreenState extends State<MethodsScreen> {
  static const MethodChannel _cameraChannel =
      MethodChannel('com.example.size_estimation/camera_utils');
  bool _useAdvancedCorrection = false;
  bool _isCalibrationExpanded = false;
  CalibrationProfile? _selectedProfile;
  final CalibrationService _calibrationService = CalibrationService();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void initState() {
    super.initState();
    _loadActiveProfile();
  }

  Future<void> _loadActiveProfile() async {
    final profile = await _calibrationService.getActiveProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedProfile = profile;
        _useAdvancedCorrection = true;
      });
    }
  }

  Future<void> _onSelectMultiImage() async {
    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    String profileName = AppStrings.defaultProfileName;
    Map<String, String> params = {};
    List<double>? distortion;

    try {
      if (_useAdvancedCorrection && _selectedProfile != null) {
        profileName = _selectedProfile!.name;

        params['fx'] = _selectedProfile!.fx.toString();
        params['fy'] = _selectedProfile!.fy.toString();
        params['cx'] = _selectedProfile!.cx.toString();
        params['cy'] = _selectedProfile!.cy.toString();

        if (_selectedProfile!.distortionCoefficients.isNotEmpty) {
          distortion = _selectedProfile!.distortionCoefficients;
        }
      } else {
        // Fetch from Camera2 API via MethodChannel
        final Map<dynamic, dynamic> result = await _cameraChannel
            .invokeMethod('getCameraProperties', {'cameraId': '0'});

        final properties = result.cast<String, dynamic>();

        // Parse LENS_INTRINSIC_CALIBRATION [fx, fy, cx, cy, s]
        if (properties['LENS_INTRINSIC_CALIBRATION'] != null) {
          var val = properties['LENS_INTRINSIC_CALIBRATION'];
          List<dynamic> intrinsics = [];
          if (val is List) {
            intrinsics = val;
          } else if (val is String) {
            intrinsics = val
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',')
                .map((e) => e.trim())
                .toList();
          }

          if (intrinsics.length >= 5) {
            params['fx'] = intrinsics[0].toString();
            params['fy'] = intrinsics[1].toString();
            params['cx'] = intrinsics[2].toString();
            params['cy'] = intrinsics[3].toString();
            params['s'] = intrinsics[4].toString();
          }
        }

        // Parse LENS_RADIAL_DISTORTION [k1, k2, k3, k4, k5, k6]
        if (properties['LENS_RADIAL_DISTORTION'] != null) {
          var val = properties['LENS_RADIAL_DISTORTION'];
          List<dynamic> rawDist = [];

          if (val is List) {
            rawDist = val;
          } else if (val is String) {
            rawDist = val
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',')
                .map((e) => e.trim())
                .toList();
          }

          try {
            distortion = rawDist
                .map((e) => double.tryParse(e.toString()) ?? 0.0)
                .toList();
          } catch (e) {
            debugPrint("Error parsing distortion: $e");
          }
        }

        if (params.isEmpty) {
          params['Status'] = AppStrings.statusCannotRead;
        }
      }
    } catch (e) {
      debugPrint("Error fetching params: $e");
      params['Error'] = "${AppStrings.errorPrefix}${e.toString()}";
    } finally {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
    }

    if (!mounted) return;

    CommonAlertDialog.show(
      context: context,
      barrierDismissible: false,
      title: AppStrings.checkParams,
      icon: Icons.settings_input_component,
      iconColor: Colors.blue,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                // ADS: Use subtle background for status/tags (N20 or Brand Light)
                color: _useAdvancedCorrection
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
                // Border is optional in ADS if background is distinct, but adding subtle border matches input style
                border: Border.all(
                    color: _useAdvancedCorrection
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.primary,
                    width: 1),
              ),
              child: Text(
                profileName,
                style: TextStyle(
                  color: _useAdvancedCorrection
                      ? Theme.of(context).colorScheme.onTertiaryContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Text(AppStrings.intrinsicsHeader,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Divider(height: 8, color: Theme.of(context).dividerTheme.color),
            if (params.containsKey('Error'))
              Text(params['Error']!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12))
            else if (params.containsKey('Status'))
              Text(params['Status']!,
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant))
            else ...[
              _buildParamRow("Focal Length X (fx)", params['fx'] ?? 'N/A'),
              _buildParamRow("Focal Length Y (fy)", params['fy'] ?? 'N/A'),
              _buildParamRow("Principal Point X (cx)", params['cx'] ?? 'N/A'),
              _buildParamRow("Principal Point Y (cy)", params['cy'] ?? 'N/A'),
              if (params.containsKey('s'))
                _buildParamRow("Skew (s)", params['s'] ?? 'N/A'),
            ],
            if (distortion != null && distortion.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(AppStrings.distortionHeader,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Divider(height: 8, color: Theme.of(context).dividerTheme.color),
              Text(
                distortion.join(', '),
                style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              AppStrings.startPrompt,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.back),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.push('/${RouteNames.camera}');
          },
          icon: const Icon(Icons.camera_alt),
          label: const Text(AppStrings.start),
        ),
      ],
    );
  }

  Widget _buildParamRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _selectProfile() async {
    final selected = await showDialog<CalibrationProfile>(
      context: context,
      builder: (context) => ProfileSelectionDialog(
        currentProfile: _selectedProfile,
      ),
    );

    if (selected != null) {
      await _calibrationService.setActiveProfile(selected.name);
      setState(() {
        _selectedProfile = selected;
        _useAdvancedCorrection = true;
      });
    } else if (selected == null && _selectedProfile != null) {
      // User cleared selection
      await _calibrationService.clearActiveProfile();
      setState(() {
        _selectedProfile = null;
        _useAdvancedCorrection = false;
      });
    }
  }

  void _onShowTutorial() {
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.tutorialTodo),
      ),
    );
  }

  void _showMultiImageInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ListView(
                controller: controller,
                children: [
                  const Text(
                    AppStrings.multiImageTitle,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    AppStrings.multiImageDesc,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    AppStrings.quickTips,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    AppStrings.quickTipsDesc,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _onShowTutorial,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text(AppStrings.viewDetailedGuide),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCameraProperties() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.95,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                controller: controller, // Attach controller for dragging
                child: const CameraPropertiesWidget(),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAdvancedSwitch(bool value) async {
    if (!value) {
      await _calibrationService.clearActiveProfile();
      setState(() {
        _useAdvancedCorrection = false;
        _selectedProfile = null;
      });
      return;
    }

    // Check if there are any profiles available
    final profiles = await _calibrationService.getAllProfiles();
    if (profiles.isEmpty) {
      if (!mounted) return;
      CommonAlertDialog.show(
        context: context,
        title: AppStrings.noCalibrationData,
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
        content: const Text(AppStrings.noCalibrationContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.understood),
          ),
        ],
      );
      // Switch remains off (false)
      return;
    }

    // Show profile selection dialog
    await _selectProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.mainFunctions),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: AppStrings.settingsTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.perm_device_information),
            tooltip: AppStrings.cameraPropsTooltip,
            onPressed: _showCameraProperties,
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.measureObjectSize,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary),
                ),
                _buildMethodCard(
                  context: context,
                  title: AppStrings.estimateObjectSize,
                  subtitle: AppStrings.estimateObjectSubtitle,
                  icon: Icons.photo_library_outlined,
                  onTap: _onSelectMultiImage,
                  onLongPress: _showMultiImageInfoSheet,
                  // ADS: Cards are clean (Surface color), actions text is Brand color
                  cardColor: Theme.of(context).cardTheme.color ??
                      Theme.of(context).colorScheme.surface,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          AppStrings.useAdvancedCorrection,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7)),
                        ),
                      ),
                      Switch(
                        value: _useAdvancedCorrection,
                        onChanged: _handleAdvancedSwitch,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.advancedTools,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 8),
                _buildCalibrationCard(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalibrationCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // ADS: Use neutral card background, borders handled by Theme
    final backgroundColor = Theme.of(context).cardTheme.color;
    final onBackgroundColor = colorScheme.onSurface;

    return Card(
      color: backgroundColor,
      elevation: 0,
      // Shape is handled by CardTheme (Rounded rect with subtle border)
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            return InkWell(
              onLongPress: () {
                showDialog(
                  context: context,
                  builder: (ctx) =>
                      const CalibrationDescDialog(onConfirm: null),
                );
              },
              onTap: () {},
              onTapUp: (details) {
                final isRightSide =
                    details.localPosition.dx > constraints.maxWidth - 56;

                if (_isCalibrationExpanded) {
                  // When expanded, collapse on any tap
                  setState(() => _isCalibrationExpanded = false);
                } else {
                  if (isRightSide) {
                    // Tap on expand icon - expand to show settings
                    setState(() => _isCalibrationExpanded = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await Future.delayed(const Duration(milliseconds: 100));
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  } else {
                    // Tap on main area - go to Calibration Playground
                    context.push('/calibration-playground');
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.perm_data_setting_outlined,
                        size: 32,
                        color: colorScheme.primary), // Brand Blue Icon
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        AppStrings.advancedCalibration,
                        style: TextStyle(
                          fontSize: 16, // Standard list item size
                          fontWeight: FontWeight.w600,
                          color: onBackgroundColor,
                        ),
                      ),
                    ),
                    Icon(
                      _isCalibrationExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: onBackgroundColor.withOpacity(0.7),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_isCalibrationExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CalibrationDisplayWidget(),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/calibration-playground'),
                    icon: const Icon(Icons.science),
                    label: const Text(AppStrings.calibrationPlayground),
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    required Color cardColor,
    required Color textColor,
    Widget? child,
  }) {
    final isEnabled = onTap != null;
    final theme = Theme.of(context);

    // ADS: Disabled state uses "Subtlest" text and lighter background if needed
    final effectiveTextColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withOpacity(0.38);

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ADS: Primary icons often use Brand color
              Icon(icon,
                  size: 32,
                  color: isEnabled ? theme.primaryColor : effectiveTextColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: effectiveTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: effectiveTextColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[
            const Spacer(),
            child,
          ] else ...[
            const Spacer(),
            if (!isEnabled)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  AppStrings.notAvailable,
                  style: TextStyle(
                      color: effectiveTextColor.withOpacity(0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward,
                    color: theme.primaryColor), // Brand directional icon
              ),
          ],
        ],
      ),
    );

    return SizedBox(
      height: 170, // Keep height consistent
      child: Card(
        color: cardColor, // Uses standard neutral card color passed in
        elevation: 0, // Flat
        // Shape handled by Theme
        clipBehavior: Clip.antiAlias,
        child: isEnabled
            ? InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: content,
              )
            : GestureDetector(
                onLongPress: onLongPress,
                behavior: HitTestBehavior.opaque,
                child: SizedBox.expand(child: content),
              ),
      ),
    );
  }
}
