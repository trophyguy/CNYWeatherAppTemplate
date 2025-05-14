import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/weather_service.dart';
import '../models/weather_alert.dart';
import 'package:intl/intl.dart';

class WeatherAlertsScreen extends StatefulWidget {
  final WeatherService weatherService;
  
  const WeatherAlertsScreen({
    super.key,
    required this.weatherService,
  });

  @override
  State<WeatherAlertsScreen> createState() => _WeatherAlertsScreenState();
}

class _WeatherAlertsScreenState extends State<WeatherAlertsScreen> {
  @override
  void initState() {
    super.initState();
    // Force a refresh when the screen is opened
    widget.weatherService.refreshWeatherData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              widget.weatherService.refreshWeatherData();
            },
          ),
        ],
      ),
      body: Consumer<WeatherService>(
        builder: (context, weatherService, child) {
          final alerts = weatherService.weatherData?.alerts ?? [];
          
          if (alerts.isEmpty) {
            return const Center(
              child: Text(
                'No active weather alerts',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Color(int.parse(alert.backgroundColor.replaceAll('#', '0xFF'))),
                child: ExpansionTile(
                  title: Text(
                    alert.event,
                    style: TextStyle(
                      color: Color(int.parse(alert.textColor.replaceAll('#', '0xFF'))),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${alert.area}\nSeverity: ${alert.severity}',
                    style: TextStyle(
                      color: Color(int.parse(alert.textColor.replaceAll('#', '0xFF'))),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(int.parse(alert.textColor.replaceAll('#', '0xFF'))),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            alert.description,
                            style: TextStyle(
                              color: Color(int.parse(alert.textColor.replaceAll('#', '0xFF'))),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Instructions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(int.parse(alert.textColor.replaceAll('#', '0xFF'))),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            alert.instruction,
                            style: TextStyle(
                              color: Color(int.parse(alert.textColor.replaceAll('#', '0xFF'))),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Effective: ${_formatDate(alert.effective)}',
                            style: TextStyle(
                              color: Color(int.parse(alert.textColor.replaceAll('#', '0xFF'))),
                            ),
                          ),
                          if (alert.expires != null)
                            Text(
                              'Expires: ${_formatDate(alert.expires!)}',
                              style: TextStyle(
                                color: Color(int.parse(alert.textColor.replaceAll('#', '0xFF'))),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, y h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }
} 