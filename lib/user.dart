import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'tracker_screen.dart';

class UserIdScreen extends StatefulWidget {
  const UserIdScreen({super.key});

  @override
  State<UserIdScreen> createState() => _UserIdScreenState();
}

class _UserIdScreenState extends State<UserIdScreen> {
  final _controller = TextEditingController();
  static const platform = MethodChannel('alarm_service');
  String _errorMessage = '';

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.notification,
    ].request();
  }

  Future<void> _saveUserIdAndStartService() async {
    if (_controller.text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _controller.text);

      try {
        final result = await platform.invokeMethod('startAlarmService');
        if (result == true) {
          print("UserIdScreen: AlarmService started successfully");
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TrackerScreen()),
            );
          }
        } else {
          setState(() {
            _errorMessage = "Не удалось запустить сервис отслеживания";
          });
        }
      } on PlatformException catch (e) {
        print("UserIdScreen: Failed to start service: $e");
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
          'Setup',
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