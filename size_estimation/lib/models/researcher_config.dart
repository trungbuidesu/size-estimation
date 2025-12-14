class ResearcherConfig {
  // Group A - Intrinsics
  bool useDeviceIntrinsics = true;
  bool showMatrixK = false;

  // Group B - Image Processing
  bool applyUndistortion = false;
  bool edgeBasedSnapping = false;
  bool applyRectification = false;
  bool multiFrameAveraging = false;

  // Group C - Estimation Model
  String estimationModel = 'Ground-plane'; // 'Combined' for now

  // Group D - Debug Overlay
  bool showPrincipalPoint = false;
  bool showGrid = false;
  bool showVanishingPoints = false;
  bool showImuInfo = false;

  // Group E - Logging
  bool enableLogging = true;

  ResearcherConfig();
}
