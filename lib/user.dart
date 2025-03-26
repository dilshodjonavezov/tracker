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

      // Запускаем сервис
      try {
        await platform.invokeMethod('startAlarmService');
      } on PlatformException catch (e) {
        print("Failed to start service: $e");
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TrackerScreen()),
        );
      }
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
      appBar: AppBar(title: const Text('Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Введите ваш User ID'),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveUserIdAndStartService,
              child: const Text('Сохранить и начать отслеживание'),
            ),
          ],
        ),
      ),
    );
  }
}