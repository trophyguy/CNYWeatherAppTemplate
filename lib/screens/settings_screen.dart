// **************************************************************************
// * WARNING: DO NOT MODIFY THIS FILE WITHOUT EXPLICIT APPROVAL                *
// * Changes to this file should be properly reviewed and authorized          *
// * Version: 1.1.0                                                          *
// **************************************************************************

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/weather_service.dart';
import '../models/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Settings> _settingsFuture;
  late Settings _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _settingsFuture = Settings.load();
    _settingsFuture.then((settings) {
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Alert Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Weather Alerts'),
            subtitle: const Text('Receive notifications for active weather alerts'),
            value: _settings.alertsEnabled,
            onChanged: (bool value) async {
              await _settings.setAlertsEnabled(value);
              setState(() {});
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Monitored Counties',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await _settings.setSelectedCounties(Settings.defaultCounties);
                    setState(() {});
                  },
                  icon: const Icon(Icons.select_all),
                  label: const Text('Select All'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await _settings.setSelectedCounties([]);
                    setState(() {});
                  },
                  icon: const Icon(Icons.deselect),
                  label: const Text('Deselect All'),
                ),
              ],
            ),
          ),
          ...Settings.defaultCounties.map((countyCode) {
            final countyName = _getCountyName(countyCode);
            return CheckboxListTile(
              title: Text(countyName),
              subtitle: Text(countyCode),
              value: _settings.selectedCounties.contains(countyCode),
              onChanged: (bool? value) async {
                if (value != null) {
                  await _settings.toggleCounty(countyCode);
                  setState(() {});
                }
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getCountyName(String countyCode) {
    switch (countyCode) {
      case 'NYC065':
        return 'Oneida County';
      case 'NYC053':
        return 'Madison County';
      case 'NYC067':
        return 'Onondaga County';
      case 'NYC075':
        return 'Oswego County';
      case 'NYC049':
        return 'Lewis County';
      case 'NYC043':
        return 'Herkimer County';
      case 'NYC057':
        return 'Otsego County';
      case 'NYC111':
        return 'Ulster County';
      default:
        return 'Unknown County';
    }
  }
} 