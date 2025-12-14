import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:size_estimation/models/calibration_profile.dart';

class CalibrationService {
  static const String _profilesKey = 'calibration_profiles';
  static const String _activeProfileKey = 'active_calibration_profile';

  /// Save a calibration profile
  Future<void> saveProfile(CalibrationProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAllProfiles();

    // Remove existing profile with same name
    profiles.removeWhere((p) => p.name == profile.name);
    profiles.add(profile);

    final jsonList = profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_profilesKey, jsonEncode(jsonList));
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
