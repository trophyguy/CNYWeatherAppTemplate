import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static AppConfig? _instance;
  static AppConfig get instance {
    if (_instance == null) {
      throw StateError('AppConfig not initialized. Call AppConfig.load() first.');
    }
    return _instance!;
  }

  static const String _testTagUrlKey = 'testtag_url';
  static const String _clientRawUrlKey = 'clientraw_url';
  static const String _latitudeKey = 'latitude';
  static const String _longitudeKey = 'longitude';
  static const String _appNameKey = 'app_name';
  static const String _countiesKey = 'counties';
  static const String _testTagUpdateIntervalKey = 'testtag_update_interval';
  static const String _clientRawUpdateIntervalKey = 'clientraw_update_interval';

  // Default values
  static const String _defaultTestTagUrl = 'your_testtag_url_path_here';
  static const String _defaultClientRawUrl = 'your_clientraw_url_path_here';
  static const double _defaultLatitude = 43.2105; // Rome, NY
  static const double _defaultLongitude = -75.4557; // Rome, NY
  static const String _defaultAppName = 'CNY Weather App Template';
  static const int _defaultTestTagUpdateInterval = 15; // minutes
  static const int _defaultClientRawUpdateInterval = 5; // minutes

  final SharedPreferences _prefs;
  String _testTagUrl;
  String _clientRawUrl;
  double _latitude;
  double _longitude;
  String _appName;
  List<String> _counties;
  int _testTagUpdateInterval;
  int _clientRawUpdateInterval;
  String? _radarStation;

  AppConfig._(this._prefs)
      : _testTagUrl = _prefs.getString(_testTagUrlKey) ?? _defaultTestTagUrl,
        _clientRawUrl = _prefs.getString(_clientRawUrlKey) ?? _defaultClientRawUrl,
        _latitude = _prefs.getDouble(_latitudeKey) ?? _defaultLatitude,
        _longitude = _prefs.getDouble(_longitudeKey) ?? _defaultLongitude,
        _appName = _prefs.getString(_appNameKey) ?? _defaultAppName,
        _counties = _prefs.getStringList(_countiesKey) ?? [],
        _testTagUpdateInterval = _prefs.getInt(_testTagUpdateIntervalKey) ?? _defaultTestTagUpdateInterval,
        _clientRawUpdateInterval = _prefs.getInt(_clientRawUpdateIntervalKey) ?? _defaultClientRawUpdateInterval;

  static Future<AppConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final config = AppConfig._(prefs);
    
    _instance = config;
    config._radarStation = prefs.getString('radar_station') ?? 'KTYX';
    return config;
  }

  // Getters
  String get testTagUrl => _testTagUrl;
  String get clientRawUrl => _clientRawUrl;
  double get latitude => _latitude;
  double get longitude => _longitude;
  String get appName => _appName;
  List<String> get counties => _counties;
  int get testTagUpdateInterval => _testTagUpdateInterval;
  int get clientRawUpdateInterval => _clientRawUpdateInterval;
  String? get radarStation => _radarStation;

  // Setters
  Future<void> setTestTagUrl(String url) async {
    _testTagUrl = url;
    await _prefs.setString(_testTagUrlKey, url);
  }

  Future<void> setClientRawUrl(String url) async {
    _clientRawUrl = url;
    await _prefs.setString(_clientRawUrlKey, url);
  }

  Future<void> setLocation(double latitude, double longitude) async {
    _latitude = latitude;
    _longitude = longitude;
    await _prefs.setDouble(_latitudeKey, latitude);
    await _prefs.setDouble(_longitudeKey, longitude);
  }

  Future<void> setAppName(String name) async {
    _appName = name;
    await _prefs.setString(_appNameKey, name);
  }

  Future<void> setCounties(List<String> counties) async {
    _counties = counties;
    await _prefs.setStringList(_countiesKey, counties);
  }

  Future<void> toggleCounty(String countyCode) async {
    if (_counties.contains(countyCode)) {
      _counties.remove(countyCode);
    } else {
      _counties.add(countyCode);
    }
    await setCounties(_counties);
  }

  Future<void> setTestTagUpdateInterval(int minutes) async {
    _testTagUpdateInterval = minutes;
    await _prefs.setInt(_testTagUpdateIntervalKey, minutes);
  }

  Future<void> setClientRawUpdateInterval(int minutes) async {
    _clientRawUpdateInterval = minutes;
    await _prefs.setInt(_clientRawUpdateIntervalKey, minutes);
  }

  Future<void> setRadarStation(String radarStation) async {
    _radarStation = radarStation;
    await _prefs.setString('radar_station', radarStation);
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    await setTestTagUrl(_defaultTestTagUrl);
    await setClientRawUrl(_defaultClientRawUrl);
    await setLocation(_defaultLatitude, _defaultLongitude);
    await setAppName(_defaultAppName);
    await setCounties([]);
    await setTestTagUpdateInterval(_defaultTestTagUpdateInterval);
    await setClientRawUpdateInterval(_defaultClientRawUpdateInterval);
    await setRadarStation('KTYX');
  }
} 