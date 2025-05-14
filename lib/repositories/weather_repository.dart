// **************************************************************************
// * WARNING: DO NOT MODIFY THIS FILE WITHOUT EXPLICIT APPROVAL                *
// * Changes to this file should be properly reviewed and authorized          *
// * Version: 1.1.0                                                          *
// **************************************************************************

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';
import '../models/forecast_data.dart';
import '../models/weather_alert.dart';
import '../services/cache_service.dart';
import '../services/purpleair_service.dart';
import '../services/nws_service_base.dart';
import '../services/nws_service_cap.dart';
import '../services/notification_service.dart';
import '../models/settings.dart';
import '../models/app_config.dart';
import '../utils/weather_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cnyweatherapp/services/nws_service.dart';

class WeatherRepository {
  final CacheService _cacheService;
  final PurpleAirService _purpleAirService;
  final NWSServiceBase _nwsServiceCap;
  final NWSService _nwsServiceForecast;
  final NotificationService _notificationService;
  final Settings _settings;
  final AppConfig _config;

  WeatherRepository(
    this._cacheService,
    this._purpleAirService,
    this._settings,
    this._notificationService,
    this._config,
  )   : _nwsServiceCap = NWSServiceCAP(_notificationService, _settings),
        _nwsServiceForecast = NWSService();

  Future<void> _initialize() async {
    await _notificationService.initialize();
    await _nwsServiceCap.initialize();
  }

  Future<String?> _getCachedWeatherData() async {
    try {
      return await _cacheService.getWeatherData();
    } catch (e) {
      developer.log('Error getting cached weather data: $e', name: 'WeatherRepository');
      return null;
    }
  }

  Future<WeatherData> getWeatherData() async {
    try {
      // Try to get cached data first
      final cachedData = await _getCachedWeatherData();
      if (cachedData != null) {
        developer.log('Using cached weather data', name: 'WeatherRepository');
        final weatherData = parseTestTags(cachedData);
        // Get cached AQI data
        final cachedAQIData = await _cacheService.getCachedAQIData();
        // Fetch forecast even when using cache
        List<ForecastPeriod> forecastData = [];
        try {
          developer.log('Fetching forecast for cached data...', name: 'WeatherRepository');
          forecastData = await _nwsServiceForecast.getForecast();
          developer.log('Fetched forecast for cached data: ${forecastData.length} periods', name: 'WeatherRepository');
        } catch (e) {
          developer.log('Warning: Failed to fetch forecast for cached data: $e', name: 'WeatherRepository');
        }
        if (cachedAQIData != null) {
          return weatherData.copyWith(
            aqi: cachedAQIData['aqi']?.toDouble() ?? 0.0,
            aqiDescription: cachedAQIData['aqiDescription'] as String?,
            forecast: forecastData,
          );
        }
        return weatherData.copyWith(forecast: forecastData);
      }

      // If no cached data, fetch fresh data
      final response = await http.get(
        Uri.parse(_config.testTagUrl),
        headers: {'Accept-Charset': 'utf-8'},
      );
      
      if (response.statusCode == 200) {
        // Convert bytes to string, replacing any invalid UTF-8 sequences
        final cleanedBody = String.fromCharCodes(
          response.bodyBytes.where((byte) => byte < 128)
        );
        
        // Cache the raw data before parsing
        await _cacheService.saveWeatherData(cleanedBody);
        
        // Get AQI data from PurpleAir
        double aqiValue = 0.0;
        String? aqiDescription;
        try {
          final aqiData = await _purpleAirService.getAirQuality();
          aqiValue = aqiData['aqi']?.toDouble() ?? 0.0;
          aqiDescription = aqiData['aqiDescription'] as String?;
          
          // Cache the AQI data
          await _cacheService.cacheAQIData(aqiData);
        } catch (e) {
          developer.log('Warning: Failed to fetch AQI data: $e', name: 'WeatherRepository');
        }

        // Get forecast data from old NWSService
        List<ForecastPeriod> forecastData = [];
        try {
          developer.log('Attempting to fetch forecast data from NWSService...', name: 'WeatherRepository');
          forecastData = await _nwsServiceForecast.getForecast();
          developer.log('Successfully fetched forecast data: ${forecastData.length} periods', name: 'WeatherRepository');
          developer.log('First forecast period: ${forecastData.isNotEmpty ? forecastData[0].name : "No periods"}', name: 'WeatherRepository');
        } catch (e) {
          developer.log('Warning: Failed to fetch forecast data: $e', name: 'WeatherRepository');
        }
        
        // Parse and return the data with AQI and forecast
        final weatherData = parseTestTags(cleanedBody);
        developer.log('Created base WeatherData, adding forecast data...', name: 'WeatherRepository');
        final weatherDataWithForecast = weatherData.copyWith(
          aqi: aqiValue,
          aqiDescription: aqiDescription,
          forecast: forecastData,
        );
        developer.log('WeatherData with forecast created. Forecast periods: ${weatherDataWithForecast.forecast.length}', name: 'WeatherRepository');
        return weatherDataWithForecast;
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching weather data: $e', name: 'WeatherRepository');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getQuickUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(_config.clientRawUrl),
        headers: {'Accept-Charset': 'utf-8'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final cleanedBody = String.fromCharCodes(
          response.bodyBytes.where((byte) => byte < 128)
        );
        
        // Parse data in a separate isolate
        return await compute(_parseQuickUpdate, cleanedBody);
      }
      throw Exception('Invalid quick update data format');
    } catch (e) {
      developer.log('Error fetching quick update: $e', name: 'WeatherRepository');
      rethrow;
    }
  }

  // Static method for isolate computation
  static Map<String, dynamic> _parseQuickUpdate(String data) {
    final parts = data.split(' ');
    if (parts.length < 73) {  // Check if we have enough data for all fields including dew point
      developer.log('Quick update data too short: ${parts.length} parts', name: 'WeatherRepository');
      throw Exception('Invalid quick update data format: insufficient data');
    }

    try {
      // Debug log the raw data
      developer.log('Raw clientraw.txt data:', name: 'WeatherRepository');
      developer.log('Parts length: ${parts.length}', name: 'WeatherRepository');
      developer.log('Dew point raw value at index 72: ${parts[72]}', name: 'WeatherRepository');

      // Wind (fields 1-3)
      final double windSpeedKnots = double.tryParse(parts[1]) ?? 0.0;  // Current Windspeed
      final double windSpeed = windSpeedKnots * 1.15078;  // Convert knots to mph
      final String windDir = parts[2];  // Wind Direction
      final String windDirText = _getFullWindDirection(windDir);
      final double windGustKnots = double.tryParse(parts[2]) ?? 0.0;  // Wind Gust in knots
      final double windGust = windGustKnots * 1.15078;  // Convert knots to mph
      
      // Temperature (field 4)
      final double tempC = double.tryParse(parts[4]) ?? 0.0;  // Outside Temp
      final double tempF = (tempC * 9/5) + 32;
      
      // Humidity and Pressure (fields 5-6)
      final double humidity = double.tryParse(parts[5]) ?? 0.0;  // Outside Humidity
      final double pressureMB = double.tryParse(parts[6]) ?? 0.0;  // Barometer
      final double pressureInHg = pressureMB * 0.02953;
      
      // Rain (fields 7-8)
      final double dailyRainMM = double.tryParse(parts[7]) ?? 0.0;  // Daily Rain in millimeters
      final double dailyRain = dailyRainMM * 0.0393701;  // Convert mm to inches
      final double rainRateMMperMin = double.tryParse(parts[10]) ?? 0.0;  // Rain Rate in mm/min (field 10)
      debugPrint('Rain Rate Raw Value (mm/min): $rainRateMMperMin');
      final double rainRate = rainRateMMperMin * 0.0393701 * 60;  // Convert mm/min to in/hr (multiply by 60 for min->hr)
      debugPrint('Rain Rate Converted (in/hr): $rainRate');
      
      // Solar/UV (fields 9-10)
      final double solarRadiation = double.tryParse(parts[9]) ?? 0.0;  // Solar Radiation
      final double uvIndex = double.tryParse(parts[79]) ?? 0.0;  // UV Index (field 79)
      
      // Additional values
      final double dewPointC = double.tryParse(parts[72]) ?? 0.0;  // Dew Point in Celsius (field 72)
      developer.log('Dew point in Celsius: $dewPointC', name: 'WeatherRepository');
      final double dewPoint = (dewPointC * 9/5) + 32;  // Convert to Fahrenheit
      developer.log('Dew point in Fahrenheit: $dewPoint', name: 'WeatherRepository');
      final double windChill = double.tryParse(parts[12]) ?? 0.0;  // Wind Chill
      final double heatIndex = double.tryParse(parts[13]) ?? 0.0;  // Heat Index
      
      return {
        'temperature': tempF,
        'windSpeed': windSpeed,  // Now in mph
        'windDirection': windDirText,
        'windGust': windGust,  // Now in mph
        'humidity': humidity,
        'pressure': pressureInHg,
        'dailyRain': dailyRain,
        'rainRate': rainRate,
        'solarRadiation': solarRadiation,
        'uvIndex': uvIndex,
        'dewPoint': dewPoint.round().toDouble(),  // Round to nearest whole number
        'windChill': windChill,
        'heatIndex': heatIndex,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      developer.log('Error parsing quick update data: $e', name: 'WeatherRepository');
      throw Exception('Error parsing quick update data: $e');
    }
  }

  static String _getFullWindDirection(String direction) {
    const directions = {
      'N': 'North',
      'NNE': 'North-Northeast',
      'NE': 'Northeast',
      'ENE': 'East-Northeast',
      'E': 'East',
      'ESE': 'East-Southeast',
      'SE': 'Southeast',
      'SSE': 'South-Southeast',
      'S': 'South',
      'SSW': 'South-Southwest',
      'SW': 'Southwest',
      'WSW': 'West-Southwest',
      'W': 'West',
      'WNW': 'West-Northwest',
      'NW': 'Northwest',
      'NNW': 'North-Northwest'
    };
    return directions[direction] ?? direction;
  }

  // Static method for isolate computation
  static WeatherData parseTestTags(String data) {
    developer.log('=== WEATHER_PERF: Starting testtags parse ===', name: 'WeatherRepository');
    
    final Map<String, String> variables = {};
    // First try with double quotes
    final doubleQuotePattern = RegExp(r'\$(\w+)\s*=\s*"([^"]*)"\s*;');
    // Then try with single quotes
    final singleQuotePattern = RegExp(r"\$(\w+)\s*=\s*'([^']*)'\s*;");
    
    // Try both patterns
    for (final match in doubleQuotePattern.allMatches(data)) {
      final key = match.group(1)!;
      final value = match.group(2)!;
      variables[key] = value;
      developer.log('Parsed variable: $key = $value', name: 'WeatherRepository');
    }
    
    for (final match in singleQuotePattern.allMatches(data)) {
      final key = match.group(1)!;
      final value = match.group(2)!;
      variables[key] = value;
      developer.log('Parsed variable: $key = $value', name: 'WeatherRepository');
    }

    // Helper function to parse numeric values safely
    double? parseNumeric(String? value) {
      if (value == null) {
        developer.log('parseNumeric: value is null', name: 'WeatherRepository');
        return null;
      }
      value = value.trim();
      if (value.isEmpty) {
        developer.log('parseNumeric: value is empty', name: 'WeatherRepository');
        return null;
      }
      try {
        final result = double.parse(value);
        developer.log('parseNumeric: successfully parsed $value to $result', name: 'WeatherRepository');
        return result;
      } catch (e) {
        developer.log('parseNumeric: failed to parse $value: $e', name: 'WeatherRepository');
        return null;
      }
    }

    // Parse current temperature - try both temperature and temp variables
    final currentTemp = parseNumeric(variables['tempnodp']) ?? parseNumeric(variables['temperature']) ?? parseNumeric(variables['temp']);
    developer.log('Parsed temperature: $currentTemp', name: 'WeatherRepository');

    // Get current time for basic time fields
    final now = DateTime.now();

    final weatherData = WeatherData(
      lastUpdatedTime: variables['time'] ?? now.toString(),
      lastUpdatedDate: variables['date'] ?? now.toString(),
      date: variables['date'] ?? now.toString(),
      isNight: now.hour < 6 || now.hour >= 18,
      updateTime: variables['time'] ?? now.toString(),
      windDirectionText: variables['dirlabel'] ?? '',
      iconName: 'skc',
      temperature: currentTemp ?? 0.0,
      tempNoDecimal: (currentTemp ?? 0.0).round().toDouble(),
      maxTemp: parseNumeric(variables['maxtemp']) ?? 0.0,
      maxTempTime: variables['maxtempt'] ?? '',
      minTemp: parseNumeric(variables['mintemp']) ?? 0.0,
      minTempTime: variables['mintempt'] ?? '',
      maxTempLastYear: parseNumeric(variables['maxtempyrago']) ?? 0.0,
      minTempLastYear: parseNumeric(variables['mintempyrago']) ?? 0.0,
      maxTempRecord: parseNumeric(variables['maxtemp4today']) ?? 0.0,
      minTempRecord: parseNumeric(variables['mintemp4today']) ?? 0.0,
      maxTempAverage: parseNumeric(variables['maxtempfordaytimeofyearfromyourdata']) ?? 0.0,
      minTempAverage: parseNumeric(variables['mintempfordaytimeofyearfromyourdata']) ?? 0.0,
      feelsLike: parseNumeric(variables['feelslike']) ?? 0.0,
      tempChangeHour: parseNumeric(variables['tempchangehour']) ?? 0.0,
      humidity: parseNumeric(variables['humidity']) ?? 0.0,
      dewPoint: parseNumeric(variables['dewpt']) ?? 0.0,
      windChill: parseNumeric(variables['windchill']) ?? 0.0,
      heatIndex: parseNumeric(variables['heatindex']) ?? 0.0,
      aqi: null,
      aqiDescription: null,
      windSpeed: parseNumeric(variables['avgspd']) ?? parseNumeric(variables['wind_speed']) ?? 0.0,
      windGust: parseNumeric(variables['gstspd']) ?? 0.0,
      maxGust: parseNumeric(variables['maxgst']) ?? 0.0,
      maxGustTime: '',
      windDirection: variables['dirlabel'] ?? '',
      windDirectionDegrees: parseNumeric(variables['winddir'])?.toInt() ?? 0,
      avgWind10Min: 0.0,
      monthlyHighWindGust: parseNumeric(variables['mrecordwindgust']) ?? 0.0,
      beaufortScale: '',
      beaufortText: '',
      pressure: parseNumeric(variables['baro']) ?? parseNumeric(variables['pressure']) ?? 0.0,
      pressureTrend: '',
      pressureTrend3Hour: '',
      forecastText: '',
      dailyRain: parseNumeric(variables['dayrn']) ?? 0.0,
      yesterdayRain: parseNumeric(variables['yesterdayrain']) ?? 0.0,
      monthlyRain: parseNumeric(variables['monthrn']) ?? 0.0,
      yearlyRain: parseNumeric(variables['yearrn']) ?? 0.0,
      daysWithNoRain: 0,
      daysWithRain: 0,
      currentRainRate: parseNumeric(variables['precip_rate']) ?? 0.0,
      maxRainRate: 0.0,
      maxRainRateTime: '',
      solarRadiation: parseNumeric(variables['solar_radiation']) ?? 0.0,
      uvIndex: parseNumeric(variables['VPuv']) ?? 0.0,
      highSolar: 0.0,
      highUV: 0.0,
      highSolarTime: '',
      highUVTime: '',
      burnTime: 0,
      snowSeason: 0.0,
      snowMonth: 0.0,
      snowToday: 0.0,
      snowYesterday: 0.0,
      snowHeight: 0.0,
      snowDepth: 0.0,
      snowDaysThisMonth: 0,
      snowDaysThisYear: 0,
      advisories: [],
      maxTempYesterday: parseNumeric(variables['maxtempyest']) ?? 0.0,
      minTempYesterday: parseNumeric(variables['mintempyest']) ?? 0.0,
      forecast: [],
      alerts: [],
      sunrise: _parseTime(variables['sunrise'] ?? ''),
      sunset: _parseTime(variables['sunset'] ?? ''),
      daylightChange: _parseDuration(variables['changeinday'] ?? '00:00:00'),
      possibleDaylight: _parseDaylightHours(variables['hoursofpossibledaylight'] ?? '00:00'),
      moonrise: _parseTime(variables['moonrise'] ?? ''),
      moonset: _parseTime(variables['moonset'] ?? ''),
      moonPhase: parseNumeric(variables['moonphase']) ?? 0.0,
      moonPhaseName: variables['moonphasename'] ?? '',
      condition: variables['weatherreport']?.split('-').first.trim() ?? variables['condition'] ?? variables['weather_condition'] ?? 'Unknown',
    );

    developer.log('Created WeatherData with temperature: ${weatherData.temperature}', name: 'WeatherRepository');
    return weatherData;
  }

  static DateTime _parseTime(String timeStr) {
    try {
      final now = DateTime.now();
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1].split(' ')[0]);
        final isPM = timeStr.toLowerCase().contains('pm');
        final adjustedHour = isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour);
        return DateTime(now.year, now.month, now.day, adjustedHour, minute);
      }
    } catch (e) {
      developer.log('Error parsing time: $e', name: 'WeatherRepository');
    }
    return DateTime.now();
  }

  static bool _isNightTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        return hour < 6 || hour >= 18;  // Consider night time between 6 PM and 6 AM
      }
    } catch (e) {
      developer.log('Error parsing time for night check: $e', name: 'WeatherRepository');
    }
    return false;
  }

  static String _getIconName(bool isNight, String condition) {
    // Convert condition to lowercase for case-insensitive matching
    final lowerCondition = condition.toLowerCase();
    
    // Map NWS forecast text to icon names
    if (lowerCondition.contains('snow') || lowerCondition.contains('flurries')) {
      return isNight ? 'nsn' : 'sn';
    } else if (lowerCondition.contains('rain') && lowerCondition.contains('snow')) {
      return isNight ? 'nra_sn' : 'ra_sn';
    } else if (lowerCondition.contains('freezing rain') && lowerCondition.contains('snow')) {
      return isNight ? 'nfzra_sn' : 'fzra_sn';
    } else if (lowerCondition.contains('freezing rain')) {
      return isNight ? 'nfzra' : 'fzra';
    } else if (lowerCondition.contains('rain') && lowerCondition.contains('ice')) {
      return isNight ? 'nraip' : 'raip';
    } else if (lowerCondition.contains('ice')) {
      return isNight ? 'nip' : 'ip';
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('shower')) {
      return isNight ? 'nshra' : 'shra';
    } else if (lowerCondition.contains('thunder') || lowerCondition.contains('tstorm')) {
      return isNight ? 'ntsra' : 'tsra';
    } else if (lowerCondition.contains('overcast') || lowerCondition.contains('cloudy')) {
      return isNight ? 'novc' : 'ovc';
    } else if (lowerCondition.contains('broken')) {
      return isNight ? 'nbkn' : 'bkn';
    } else if (lowerCondition.contains('scattered') || lowerCondition.contains('partly')) {
      return isNight ? 'nsct' : 'sct';
    } else if (lowerCondition.contains('few') || lowerCondition.contains('fair') || 
               lowerCondition.contains('mostly clear')) {
      return isNight ? 'nfew' : 'few';
    } else if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) {
      return isNight ? 'nfew' : 'few';
    } else if (lowerCondition.contains('fog') || lowerCondition.contains('mist')) {
      return isNight ? 'nfg' : 'fg';
    } else if (lowerCondition.contains('haze') || lowerCondition.contains('smoke')) {
      return 'hz';
    } else if (lowerCondition.contains('hot')) {
      return 'hot';
    } else if (lowerCondition.contains('cold')) {
      return isNight ? 'ncold' : 'cold';
    } else if (lowerCondition.contains('blizzard')) {
      return isNight ? 'nblizzard' : 'blizzard';
    } else {
      // Default to few clouds instead of clear sky
      return isNight ? 'nfew' : 'few';
    }
  }

  static Duration _parseDuration(String durationStr) {
    try {
      final parts = durationStr.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    } catch (e) {
      developer.log('Error parsing duration: $e', name: 'WeatherRepository');
    }
    return Duration.zero;
  }

  static double _parseDaylightHours(String hoursStr) {
    try {
      final parts = hoursStr.split(':');
      if (parts.length == 2) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return hours + (minutes / 60.0);
      }
    } catch (e) {
      developer.log('Error parsing daylight hours: $e', name: 'WeatherRepository');
    }
    return 0.0;
  }
} 