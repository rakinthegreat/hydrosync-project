import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<Map<String, dynamic>?> fetchWeather() async {
    try {
      // 1. Get current position
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      Position position = await Geolocator.getCurrentPosition();

      // 2. Fetch Forecast AND History from Open-Meteo (No API Key required!)
      final url = '$_baseUrl?latitude=${position.latitude}&longitude=${position.longitude}&daily=temperature_2m_max,temperature_2m_min,relative_humidity_2m_max,relative_humidity_2m_min&timezone=auto&past_days=7';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final daily = data['daily'];

      final List<dynamic> maxTemps = daily['temperature_2m_max'];
      final List<dynamic> minTemps = daily['temperature_2m_min'];
      final List<dynamic> maxHums = daily['relative_humidity_2m_max'];
      final List<dynamic> minHums = daily['relative_humidity_2m_min'];

      // Open-Meteo with past_days=7 returns 15 items: 7 past, 1 today, 7 future
      final List<Map<String, dynamic>> fullTrend = [];
      for (int i = 0; i < maxTemps.length; i++) {
        fullTrend.add({
          'day': _getRelativeDayName(i - 7),
          'temp': (maxTemps[i] + minTemps[i]) / 2,
          'humidity': (maxHums[i] + minHums[i]) / 2,
        });
      }

      // Split into history (indices 0-6) and forecast (indices 7-14)
      final trend = fullTrend.length > 7 ? fullTrend.sublist(7) : fullTrend;
      final history =
          fullTrend.length >= 7 ? fullTrend.sublist(0, 7) : <Map<String, dynamic>>[];

      return {
        'temperature': trend.isNotEmpty ? trend[0]['temp'] : 25.0, // Today's avg
        'humidity': trend[0]['humidity'],
        'city': 'Current Location',
        'trend': trend,
        'history': history,
      };
    } catch (e) {
      print('Weather Error: $e');
      return null;
    }
  }

  String _getRelativeDayName(int dayOffset) {
    if (dayOffset == 0) return 'Today';
    final date = DateTime.now().add(Duration(days: dayOffset));
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}
