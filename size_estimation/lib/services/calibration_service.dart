import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:size_estimation/models/calibration_profile.dart';

class CalibrationService {
  static const String _profilesKey = 'calibration_profiles';
  static const String _activeProfileKey = 'active_calibration_profile';
  static const String _customProfileName = 'Custom Calibration';

  /// Save a calibration profile
  /// For custom calibration (from CalibrationScreen), only 1 profile is kept (overwrite)
  Future<void> saveProfile(CalibrationProfile profile,
      {bool isCustom = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAllProfiles();

    if (isCustom) {
      // Custom calibration: Remove all custom profiles and save only this one
      profiles.removeWhere((p) => p.name == _customProfileName);

      // Force name to be "Custom Calibration"
      final customProfile = profile.copyWith(name: _customProfileName);
      profiles.add(customProfile);
    } else {
      // Regular profile: Remove existing profile with same name
      profiles.removeWhere((p) => p.name == profile.name);
      profiles.add(profile);
    }

    final jsonList = profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_profilesKey, jsonEncode(jsonList));
  }

  /// Get the custom calibration profile (latest)
  Future<CalibrationProfile?> getCustomProfile() async {
    return getProfile(_customProfileName);
  }

  /// Get all saved calibration profiles
  Future<List<CalibrationProfile>> getAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_profilesKey);

    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => CalibrationProfile.fromJson(json)).toList();
  }

  /// Get a specific profile by name
  Future<CalibrationProfile?> getProfile(String name) async {
    final profiles = await getAllProfiles();
    try {
      return profiles.firstWhere((p) => p.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Delete a profile
  Future<void> deleteProfile(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAllProfiles();
    profiles.removeWhere((p) => p.name == name);

    final jsonList = profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_profilesKey, jsonEncode(jsonList));
  }

  /// Set active profile
  Future<void> setActiveProfile(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, name);
  }

  /// Get active profile name
  Future<String?> getActiveProfileName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey);
  }

  /// Get active profile
  Future<CalibrationProfile?> getActiveProfile() async {
    final name = await getActiveProfileName();
    if (name == null) return null;
    return getProfile(name);
  }

  /// Clear active profile (use device intrinsics)
  Future<void> clearActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeProfileKey);
  }

  /// Export profile to JSON string
  String exportProfile(CalibrationProfile profile) {
    return profile.toJsonString();
  }

  /// Import profile from JSON string
  CalibrationProfile importProfile(String jsonString) {
    return CalibrationProfile.fromJsonString(jsonString);
  }
}
