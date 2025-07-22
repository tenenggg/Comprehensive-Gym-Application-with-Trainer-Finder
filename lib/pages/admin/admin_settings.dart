import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  final AdminService _adminService = AdminService();
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _adminService.getSystemSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _adminService.updateSystemSettings({key: value});
      setState(() {
        _settings[key] = value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setting updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating setting: $e')),
        );
      }
    }
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required String settingKey,
    required Widget control,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: control,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'System Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildSettingTile(
          title: 'Allow New Registrations',
          subtitle: 'Enable or disable new user registrations',
          settingKey: 'allowRegistrations',
          control: Switch(
            value: _settings['allowRegistrations'] ?? true,
            onChanged: (value) => _updateSetting('allowRegistrations', value),
          ),
        ),
        _buildSettingTile(
          title: 'Trainer Verification Required',
          subtitle: 'Require admin verification for new trainers',
          settingKey: 'requireTrainerVerification',
          control: Switch(
            value: _settings['requireTrainerVerification'] ?? true,
            onChanged: (value) => _updateSetting('requireTrainerVerification', value),
          ),
        ),
        _buildSettingTile(
          title: 'Maintenance Mode',
          subtitle: 'Put the app in maintenance mode',
          settingKey: 'maintenanceMode',
          control: Switch(
            value: _settings['maintenanceMode'] ?? false,
            onChanged: (value) => _updateSetting('maintenanceMode', value),
          ),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'App Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildSettingTile(
          title: 'Maximum Active Bookings',
          subtitle: 'Maximum number of active bookings per user',
          settingKey: 'maxActiveBookings',
          control: DropdownButton<int>(
            value: _settings['maxActiveBookings'] ?? 5,
            items: [3, 5, 10, 15, 20].map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text(value.toString()),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateSetting('maxActiveBookings', value);
              }
            },
          ),
        ),
        _buildSettingTile(
          title: 'Booking Cancellation Period',
          subtitle: 'Hours before session when cancellation is allowed',
          settingKey: 'cancellationPeriod',
          control: DropdownButton<int>(
            value: _settings['cancellationPeriod'] ?? 24,
            items: [12, 24, 48, 72].map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value hours'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateSetting('cancellationPeriod', value);
              }
            },
          ),
        ),
      ],
    );
  }
} 