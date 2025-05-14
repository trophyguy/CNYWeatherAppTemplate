import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class PurpleAirService {
  final String _apiKey;
  final String _sensorId;
  static const String _baseUrl = 'https://api.purpleair.com/v1/sensors';
  static const String _lastUpdateKey = 'purpleair_last_update';
  static const Duration _cacheDuration = Duration(hours: 1);
  late SharedPreferences _prefs;

  PurpleAirService(this._apiKey, this._sensorId) {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<Map<String, dynamic>> getAirQuality() async {
    try {
      // Check if we have cached data that's not stale
      final cachedData = await _getCachedData();
      if (cachedData != null) {
        developer.log('Using cached PurpleAir data', name: 'PurpleAirService');
        return cachedData;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$_sensorId'),
        headers: {
          'X-API-Key': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sensor = data['sensor'];
        
        // Use the 10-minute average PM2.5 value
        final pm25 = sensor['pm2.5_10minute']?.toDouble() ?? 0.0;
        final aqi = _calculateAQI(pm25);
        final aqiDescription = _getAQIDescription(aqi);

        final result = {
          'aqi': aqi,
          'aqiDescription': aqiDescription,
          'pm25': pm25,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Cache the result
        await _cacheData(result);
        
        return result;
      } else {
        throw Exception('Failed to fetch PurpleAir data: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching PurpleAir data: $e', name: 'PurpleAirService');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getCachedData() async {
    try {
      final lastUpdateStr = _prefs.getString(_lastUpdateKey);
      if (lastUpdateStr == null) return null;

      final lastUpdate = DateTime.parse(lastUpdateStr);
      if (DateTime.now().difference(lastUpdate) > _cacheDuration) {
        return null;
      }

      final cachedData = _prefs.getString('purpleair_data');
      if (cachedData == null) return null;

      return json.decode(cachedData) as Map<String, dynamic>;
    } catch (e) {
      developer.log('Error getting cached PurpleAir data: $e', name: 'PurpleAirService');
      return null;
    }
  }

  Future<void> _cacheData(Map<String, dynamic> data) async {
    try {
      await _prefs.setString('purpleair_data', json.encode(data));
      await _prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    } catch (e) {
      developer.log('Error caching PurpleAir data: $e', name: 'PurpleAirService');
    }
  }

  double _calculateAQI(double pm25) {
    // EPA's NowCast algorithm for PM2.5
    if (pm25 <= 0) return 0;
    
    // EPA's AQI breakpoints for PM2.5
    if (pm25 <= 12.0) {
      return _linearScale(pm25, 0, 12.0, 0, 50);
    } else if (pm25 <= 35.4) {
      return _linearScale(pm25, 12.1, 35.4, 51, 100);
    } else if (pm25 <= 55.4) {
      return _linearScale(pm25, 35.5, 55.4, 101, 150);
    } else if (pm25 <= 150.4) {
      return _linearScale(pm25, 55.5, 150.4, 151, 200);
    } else if (pm25 <= 250.4) {
      return _linearScale(pm25, 150.5, 250.4, 201, 300);
    } else if (pm25 <= 350.4) {
      return _linearScale(pm25, 250.5, 350.4, 301, 400);
    } else if (pm25 <= 500.4) {
      return _linearScale(pm25, 350.5, 500.4, 401, 500);
    } else {
      return 500;
    }
  }

  double _linearScale(double value, double inMin, double inMax, double outMin, double outMax) {
    return ((value - inMin) * (outMax - outMin) / (inMax - inMin)) + outMin;
  }

  String _getAQIDescription(double aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    if (aqi <= 500) return 'Hazardous';
    return 'Hazardous';
  }
} 