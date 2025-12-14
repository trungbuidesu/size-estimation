import 'dart:math';

class ResultAveragingService {
  final List<double> _samples = [];

  void addSample(double value) {
    if (value.isFinite && !value.isNaN) {
      _samples.add(value);
    }
  }

  void clear() => _samples.clear();

  bool get isEmpty => _samples.isEmpty;
  int get count => _samples.length;

  double get median {
    if (_samples.isEmpty) return 0.0;
    final sorted = List<double>.from(_samples)..sort();
    return sorted[sorted.length ~/ 2];
  }

  double get mean {
    if (_samples.isEmpty) return 0.0;
    return _samples.reduce((a, b) => a + b) / _samples.length;
  }

  /// Returns mean and standard deviation
  ({double mean, double stdDev}) get statistics {
    if (_samples.isEmpty) return (mean: 0.0, stdDev: 0.0);
    double m = mean;
    double sumSquaredDiff = _samples.fold(0.0, (sum, x) => sum + pow(x - m, 2));
    double variance = sumSquaredDiff / _samples.length;
    return (mean: m, stdDev: sqrt(variance));
  }
}
