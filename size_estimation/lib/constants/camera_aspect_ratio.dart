class CameraAspectRatios {
  static const int square = 0;
  static const int ratio4_3 = 1;
  static const int ratio16_9 = 2;

  static const Map<int, double> values = {
    square: 1.0,
    ratio4_3: 3.0 / 4.0, // Portrait
    ratio16_9: 9.0 / 16.0, // Portrait
  };

  static double getRatio(int index) => values[index] ?? (9.0 / 16.0);
}
