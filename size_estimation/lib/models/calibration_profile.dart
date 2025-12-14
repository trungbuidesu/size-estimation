import 'dart:convert';

class CalibrationProfile {
  final String name;
  final double fx;
  final double fy;
  final double cx;
  final double cy;
  final List<double> distortionCoefficients;
  final double? rmsError;
  final DateTime createdAt;
  final String source; // 'device', 'manual', 'chessboard'

  CalibrationProfile({
    required this.name,
    required this.fx,
    required this.fy,
    required this.cx,
    required this.cy,
    this.distortionCoefficients = const [],
    this.rmsError,
    DateTime? createdAt,
    this.source = 'manual',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fx': fx,
      'fy': fy,
      'cx': cx,
      'cy': cy,
      'distortionCoefficients': distortionCoefficients,
      'rmsError': rmsError,
      'createdAt': createdAt.toIso8601String(),
      'source': source,
    };
  }

  factory CalibrationProfile.fromJson(Map<String, dynamic> json) {
    return CalibrationProfile(
      name: json['name'] as String,
      fx: (json['fx'] as num).toDouble(),
      fy: (json['fy'] as num).toDouble(),
      cx: (json['cx'] as num).toDouble(),
      cy: (json['cy'] as num).toDouble(),
      distortionCoefficients: (json['distortionCoefficients'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      rmsError: json['rmsError'] != null
          ? (json['rmsError'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      source: json['source'] as String? ?? 'manual',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory CalibrationProfile.fromJsonString(String jsonString) {
    return CalibrationProfile.fromJson(jsonDecode(jsonString));
  }

  CalibrationProfile copyWith({
    String? name,
    double? fx,
    double? fy,
    double? cx,
    double? cy,
    List<double>? distortionCoefficients,
    double? rmsError,
    DateTime? createdAt,
    String? source,
  }) {
    return CalibrationProfile(
      name: name ?? this.name,
      fx: fx ?? this.fx,
      fy: fy ?? this.fy,
      cx: cx ?? this.cx,
      cy: cy ?? this.cy,
      distortionCoefficients:
          distortionCoefficients ?? this.distortionCoefficients,
      rmsError: rmsError ?? this.rmsError,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }
}
