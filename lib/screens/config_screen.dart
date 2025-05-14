import 'package:flutter/material.dart';
import '../models/app_config.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late Future<AppConfig> _configFuture;
  late AppConfig _config;
  bool _isLoading = true;
  
  // Form controllers
  final _testTagUrlController = TextEditingController();
  final _clientRawUrlController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _appNameController = TextEditingController();
  final _testTagUpdateIntervalController = TextEditingController();
  final _clientRawUpdateIntervalController = TextEditingController();
  final _newCountyController = TextEditingController();
  List<String> _selectedCounties = [];
  static const int _maxCounties = 6;
  String? _countyLimitError;

  @override
  void initState() {
    super.initState();
    _configFuture = AppConfig.load();
    _configFuture.then((config) {
      setState(() {
        _config = config;
        _isLoading = false;
        // Initialize form controllers with current values
        _testTagUrlController.text = config.testTagUrl;
        _clientRawUrlController.text = config.clientRawUrl;
        _latitudeController.text = config.latitude.toString();
        _longitudeController.text = config.longitude.toString();
        _appNameController.text = config.appName;
        _testTagUpdateIntervalController.text = config.testTagUpdateInterval.toString();
        _clientRawUpdateIntervalController.text = config.clientRawUpdateInterval.toString();
        _selectedCounties = List.from(config.counties);
      });
    });
  }

  @override
  void dispose() {
    _testTagUrlController.dispose();
    _clientRawUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _appNameController.dispose();
    _testTagUpdateIntervalController.dispose();
    _clientRawUpdateIntervalController.dispose();
    _newCountyController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    try {
      await _config.setTestTagUrl(_testTagUrlController.text);
      await _config.setClientRawUrl(_clientRawUrlController.text);
      await _config.setLocation(
        double.parse(_latitudeController.text),
        double.parse(_longitudeController.text),
      );
      await _config.setAppName(_appNameController.text);
      await _config.setTestTagUpdateInterval(int.parse(_testTagUpdateIntervalController.text));
      await _config.setClientRawUpdateInterval(int.parse(_clientRawUpdateIntervalController.text));
      await _config.setCounties(_selectedCounties);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving configuration: $e')),
        );
      }
    }
  }

  Future<void> _resetToDefaults() async {
    try {
      await _config.resetToDefaults();
      setState(() {
        _testTagUrlController.text = _config.testTagUrl;
        _clientRawUrlController.text = _config.clientRawUrl;
        _latitudeController.text = _config.latitude.toString();
        _longitudeController.text = _config.longitude.toString();
        _appNameController.text = _config.appName;
        _testTagUpdateIntervalController.text = _config.testTagUpdateInterval.toString();
        _clientRawUpdateIntervalController.text = _config.clientRawUpdateInterval.toString();
        _selectedCounties = List.from(_config.counties);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset to defaults successful')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting to defaults: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _appNameController,
              decoration: const InputDecoration(
                labelText: 'App Name',
                hintText: 'Enter your app name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _testTagUrlController,
              decoration: const InputDecoration(
                labelText: 'TestTag URL',
                hintText: 'Enter your TestTag URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clientRawUrlController,
              decoration: const InputDecoration(
                labelText: 'ClientRaw URL',
                hintText: 'Enter your ClientRaw URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: 'Enter latitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: 'Enter longitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _testTagUpdateIntervalController,
                    decoration: const InputDecoration(
                      labelText: 'TestTag Update Interval (minutes)',
                      hintText: 'e.g. 15',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _clientRawUpdateIntervalController,
                    decoration: const InputDecoration(
                      labelText: 'ClientRaw Update Interval (seconds)',
                      hintText: 'e.g. 5',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Counties/Zones to Monitor',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCountyController,
                    decoration: const InputDecoration(
                      labelText: 'Add County/Zone Code',
                      hintText: 'e.g. NYC065',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final newCode = _newCountyController.text.trim();
                    if (_selectedCounties.length >= _maxCounties) {
                      setState(() {
                        _countyLimitError = 'You can only add up to $_maxCounties counties/zones.';
                      });
                    } else if (newCode.isNotEmpty && !_selectedCounties.contains(newCode)) {
                      setState(() {
                        _selectedCounties.add(newCode);
                        _newCountyController.clear();
                        _countyLimitError = null;
                      });
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_countyLimitError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _countyLimitError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Column(
              children: [
                for (final county in _selectedCounties)
                  CheckboxListTile(
                    title: Text(county),
                    value: true,
                    onChanged: (checked) {
                      if (checked == false) {
                        setState(() {
                          _selectedCounties.remove(county);
                        });
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveConfig,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Configuration'),
            ),
          ],
        ),
      ),
    );
  }
} 