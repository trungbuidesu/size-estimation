import 'package:flutter/material.dart';
import 'package:size_estimation/models/calibration_profile.dart';
import 'package:size_estimation/services/calibration_service.dart';

class ProfileSelectionDialog extends StatefulWidget {
  final CalibrationProfile? currentProfile;

  const ProfileSelectionDialog({
    super.key,
    this.currentProfile,
  });

  @override
  State<ProfileSelectionDialog> createState() => _ProfileSelectionDialogState();
}

class _ProfileSelectionDialogState extends State<ProfileSelectionDialog> {
  final CalibrationService _calibrationService = CalibrationService();
  List<CalibrationProfile> _profiles = [];
  CalibrationProfile? _selectedProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedProfile = widget.currentProfile;
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final profiles = await _calibrationService.getAllProfiles();
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProfile(CalibrationProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to delete "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _calibrationService.deleteProfile(profile.name);
      if (_selectedProfile?.name == profile.name) {
        _selectedProfile = null;
      }
      await _loadProfiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune, color: Colors.blue),
          SizedBox(width: 8),
          Text('Select Calibration Profile'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _profiles.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No calibration profiles found',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create one in Calibration Playground',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _profiles.length,
                    itemBuilder: (context, index) {
                      final profile = _profiles[index];
                      final isSelected = _selectedProfile?.name == profile.name;

                      return Card(
                        color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                        child: ListTile(
                          leading: Icon(
                            _getSourceIcon(profile.source),
                            color: isSelected ? Colors.blue : Colors.grey,
                          ),
                          title: Text(
                            profile.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? Colors.blue : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Source: ${profile.source}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (profile.rmsError != null)
                                Text(
                                  'RMS: ${profile.rmsError!.toStringAsFixed(3)} px',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getRmsColor(profile.rmsError!),
                                  ),
                                ),
                              Text(
                                'Created: ${_formatDate(profile.createdAt)}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: Colors.blue),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                color: Colors.red,
                                onPressed: () => _deleteProfile(profile),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() => _selectedProfile = profile);
                          },
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_profiles.isNotEmpty)
          TextButton(
            onPressed: () {
              setState(() => _selectedProfile = null);
            },
            child: const Text('Clear Selection'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedProfile),
          child: const Text('Select'),
        ),
      ],
    );
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'chessboard':
        return Icons.grid_4x4;
      case 'manual':
        return Icons.edit;
      case 'device':
        return Icons.phone_android;
      default:
        return Icons.settings;
    }
  }

  Color _getRmsColor(double rms) {
    if (rms < 0.5) return Colors.green;
    if (rms < 1.0) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
