/*
 * FLauncher Custom - Weather Widget
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({Key? key}) : super(key: key);

  @override
  _WeatherWidgetState createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String? _temp;
  String? _desc;
  IconData _icon = Icons.wb_sunny_outlined;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    // Update every 30 minutes
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _fetchWeather());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(Uri.parse('https://wttr.in/?format=j1'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final data = jsonDecode(content);
        final current = data['current_condition']?[0];
        if (current != null) {
          final temp = current['temp_C']?.toString() ?? '';
          final desc = current['weatherDesc']?[0]?['value']?.toString() ?? '';
          
          if (mounted) {
            setState(() {
              _temp = '$temp°C';
              _desc = _translateDesc(desc);
              _icon = _getWeatherIcon(desc);
            });
          }
        }
      }
    } catch (_) {
      // Graceful fallback if offline
    }
  }

  String _translateDesc(String desc) {
    final lower = desc.toLowerCase();
    if (lower.contains('sun') || lower.contains('clear')) return 'Cerah';
    if (lower.contains('partly cloudy')) return 'Berawan Sebagian';
    if (lower.contains('cloud') || lower.contains('overcast')) return 'Berawan';
    if (lower.contains('thunder')) return 'Badai Petir';
    if (lower.contains('rain') || lower.contains('drizzle')) return 'Hujan';
    if (lower.contains('fog') || lower.contains('mist')) return 'Berkabut';
    return desc;
  }

  IconData _getWeatherIcon(String desc) {
    final lower = desc.toLowerCase();
    if (lower.contains('thunder')) return Icons.thunderstorm_outlined;
    if (lower.contains('rain') || lower.contains('drizzle')) return Icons.water_drop_outlined;
    if (lower.contains('partly cloudy')) return Icons.cloud_queue_outlined;
    if (lower.contains('cloud') || lower.contains('overcast')) return Icons.cloud_outlined;
    if (lower.contains('fog') || lower.contains('mist')) return Icons.blur_on_outlined;
    return Icons.wb_sunny_outlined;
  }

  @override
  Widget build(BuildContext context) {
    if (_temp == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$_temp ${_desc != null ? "• $_desc" : ""}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 1))],
            ),
          ),
        ],
      ),
    );
  }
}
