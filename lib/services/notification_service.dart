import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../models/weather_alert.dart';

class NotificationService {
  static const String _channelId = 'weather_alerts';
  static const String _channelName = 'Weather Alerts';
  static const String _channelDescription = 'Notifications for weather alerts and warnings';
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Set<String> _shownAlertIds = {};
  final GlobalKey<NavigatorState> _navigatorKey;

  NotificationService(this._navigatorKey);

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('ic_stat_weather_bell');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create the notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped with action: ${response.actionId}');
    debugPrint('Notification payload: ${response.payload}');
    
    // Handle both notification tap and action button tap
    if (response.actionId == 'view' || response.payload == '/alerts') {
      debugPrint('Navigating to alerts screen');
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/alerts',
        (route) => false, // Remove all previous routes
      );
    }
  }

  Future<void> showAlertNotification(WeatherAlert alert) async {
    // Skip if we've already shown this alert
    if (_shownAlertIds.contains(alert.id)) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      color: Color(int.parse(alert.backgroundColor.replaceAll('#', '0xFF'))),
      styleInformation: BigTextStyleInformation(alert.description),
      fullScreenIntent: true, // Make notification more prominent
      category: AndroidNotificationCategory.alarm, // Treat as high priority
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive, // Make notification more prominent
      categoryIdentifier: 'weather_alerts',
      threadIdentifier: 'weather_alerts',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Create a unique notification ID based on the alert ID
    final notificationId = alert.id.hashCode;

    try {
      await _notifications.show(
        notificationId,
        '${alert.severity.toUpperCase()}: ${alert.event}',
        alert.area,
        details,
        payload: '/alerts',
      );
      
      // Add to shown alerts
      _shownAlertIds.add(alert.id);
      
      // Clean up old alerts after 24 hours
      Future.delayed(const Duration(hours: 24), () {
        _shownAlertIds.remove(alert.id);
      });
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    _shownAlertIds.clear();
  }
} 