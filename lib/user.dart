import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'thank_you_screen.dart'; // Импортируем новую страницу

class UserIdScreen extends StatefulWidget {
  const UserIdScreen({super.key});

  @override
  State<UserIdScreen> createState() => _UserIdScreenState();
}

class _UserIdScreenState extends State<UserIdScreen> {
  final _controller = TextEditingController();
  static const platform = MethodChannel('alarm_service');
  String _errorMessage = '';
  static const String _username = 'Админ';
  static const String _password = '1';

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.notification,
    ].request();
  }

  Future<void> _fetchSettings(String userId) async {
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('gps', data['gps'] ?? false);
          await prefs.setInt('interval', data['interval'] ?? 600);
          await prefs.setString('from', data['from'] ?? '0001-01-01T08:00:00');
          await prefs.setString('to', data['to'] ?? '0001-01-01T18:00:00');
        } else {
          throw Exception('Server returned result: false');
        }
      } else {
        throw Exception('Failed to fetch settings: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при получении настроек: $e';
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gps', false);
      await prefs.setInt('interval', 600);
      await prefs.setString('from', '0001-01-01T08:00:00');
      await prefs.setString('to', '0001-01-01T18:00:00');
    }
  }

  Future<void> _saveUserIdAndStartService() async {
    if (_controller.text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final userId = _controller.text;
      await prefs.setString('user_id', userId);

      await _fetchSettings(userId);

      try {
        final result = await platform.invokeMethod('startAlarmService');
        if (result == true) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ThankYouScreen()),
            );
          }
        } else {
          setState(() {
            _errorMessage = "Не удалось запустить сервис отслеживания";
          });
        }
      } on PlatformException catch (e) {
        setState(() {
          _errorMessage = "Ошибка при запуске сервиса: ${e.message}";
        });
      }
    } else {
      setState(() {
        _errorMessage = "Пожалуйста, введите User ID";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        title: const Text(
          'Настройка',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Введите ваш User ID',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D2671), Color(0xFF0A0E21)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
                decoration: InputDecoration(
                  labelText: 'User ID',
                  labelStyle: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontFamily: 'Montserrat',
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveUserIdAndStartService,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEB1555),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
                shadowColor: const Color(0xFFEB1555).withOpacity(0.5),
              ),
              child: const Text(
                'Вход',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}