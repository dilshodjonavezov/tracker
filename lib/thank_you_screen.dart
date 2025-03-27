import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'log_manager.dart';
import 'tracker_screen.dart'; // Импортируем TrackerScreen

class ThankYouScreen extends StatefulWidget {
  const ThankYouScreen({super.key});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen> {
  final _locationService = LocationService();
  static const String _username = 'Админ';
  static const String _password = '1';
  static const platform = MethodChannel('alarm_service');

  @override
  void initState() {
    super.initState();
    print('ThankYouScreen: initState called');
    _updateSettings();
    _restartAlarmService();
    _locationService.startLocationTracking();
  }

  Future<void> _restartAlarmService() async {
    print('ThankYouScreen: _restartAlarmService called');
    try {
      final result = await platform.invokeMethod('startAlarmService');
      if (result == true) {
        print('ThankYouScreen: AlarmService restarted successfully');
      } else {
        print('ThankYouScreen: Failed to restart AlarmService');
      }
    } on PlatformException catch (e) {
      print('ThankYouScreen: Error restarting AlarmService: ${e.message}');
    }
  }

  Future<void> _updateSettings() async {
    print('ThankYouScreen: _updateSettings called');
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    print('ThankYouScreen: _updateSettings: user_id=$userId');
    if (userId != null) {
      try {
        final String basicAuth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
        print('ThankYouScreen: _updateSettings: Sending GET request to http://192.168.1.10:8080/MR_v1/hs/data/auth?user_id=$userId');
        final response = await http.get(
          Uri.parse('http://192.168.1.10:8080/MR_v1/hs/data/auth?user_id=$userId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': basicAuth,
          },
        ).timeout(const Duration(seconds: 10));

        print('ThankYouScreen: _updateSettings: Response code=${response.statusCode}, body=${response.body}');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['result'] == true) {
            await prefs.setBool('gps', data['gps'] ?? false);
            await prefs.setInt('interval', data['interval'] ?? 600);
            await prefs.setString('from', data['from'] ?? '0001-01-01T08:00:00');
            await prefs.setString('to', data['to'] ?? '0001-01-01T18:00:00');
            print('ThankYouScreen: _updateSettings: Settings updated: gps=${data['gps']}, interval=${data['interval']}, from=${data['from']}, to=${data['to']}');
          } else {
            print('ThankYouScreen: _updateSettings: Server returned result: false');
          }
        }
      } catch (e) {
        print('ThankYouScreen: _updateSettings: Error: $e');
      }
    }
  }

  Future<void> _sendLocation() async {
    print('ThankYouScreen: _sendLocation called');
    try {
      print('ThankYouScreen: _sendLocation: Getting current location');
      final locationData = await _locationService.getCurrentLocation();
      print('ThankYouScreen: _sendLocation: Current location: lat=${locationData.latitude}, lon=${locationData.longitude}');
      print('ThankYouScreen: _sendLocation: Sending location to server');
      await _locationService.sendLocationToServer(
        locationData.latitude!,
        locationData.longitude!,
        source: 'Ручная',
      );
      print('ThankYouScreen: _sendLocation: Location sent successfully');
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
      print('ThankYouScreen: _sendLocation: Error: $e');
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
    print('ThankYouScreen: dispose called');
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
              children: [
                const Text(
                  'Спасибо!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Работа началась.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 24,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Удачи!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 24,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    print('ThankYouScreen: Navigating to TrackerScreen');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrackerScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEB1555),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Посмотреть логи',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Montserrat',
                    ),
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