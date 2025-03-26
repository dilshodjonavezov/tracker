import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'log_manager.dart';

class ThankYouScreen extends StatefulWidget {
  const ThankYouScreen({super.key});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen> {
  final _locationService = LocationService();
  static const String _username = 'Админ';
  static const String _password = '1';

  @override
  void initState() {
    super.initState();
    _updateSettings(); // Обновляем настройки при входе
    _locationService.startLocationTracking(); // Запускаем фоновую отправку
  }

  Future<void> _updateSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      try {
        final String basicAuth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
        final request = http.Request(
          'GET',
          Uri.parse('http://192.168.1.10:8080/MR_v1/hs/data/auth'),
        );
        request.headers['Content-Type'] = 'application/json';
        request.headers['Authorization'] = basicAuth;
        request.body = jsonEncode({'user_id': userId});

        final response = await request.send().timeout(const Duration(seconds: 10));
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          if (data['result'] == true) {
            await prefs.setBool('gps', data['gps'] ?? false);
            await prefs.setInt('interval', data['interval'] ?? 600);
            await prefs.setString('from', data['from'] ?? '0001-01-01T08:00:00');
            await prefs.setString('to', data['to'] ?? '0001-01-01T18:00:00');
          }
        }
      } catch (e) {
        // Если запрос не удался, оставляем текущие настройки
      }
    }
  }

  Future<void> _sendLocation() async {
    try {
      final locationData = await _locationService.getCurrentLocation();
      await _locationService.sendLocationToServer(
        locationData.latitude!,
        locationData.longitude!,
        source: 'Ручная',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Данные успешно отправлены',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: 16,
              ),
            ),
            backgroundColor: const Color(0xFF1D2671),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка при отправке: $e',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: 16,
              ),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _locationService.stopLocationTracking();
    _locationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Спасибо!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Работа началась.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 24,
                    fontFamily: 'Montserrat',
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Удачи!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 24,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: _sendLocation,
              backgroundColor: const Color(0xFFEB1555),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}