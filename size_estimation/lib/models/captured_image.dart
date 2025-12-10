import 'dart:io';

class CapturedImage {
  final File file;
  final List<String> warnings;

  CapturedImage({required this.file, this.warnings = const []});

  bool get hasWarnings => warnings.isNotEmpty;
}
