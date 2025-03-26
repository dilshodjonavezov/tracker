import 'package:alarm/log_manager.dart';
import 'package:flutter/material.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final _locationService = LocationService();
  String _status = 'Ожидание...';
  bool _isTracking = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _startTracking();
    _locationService.logStream.listen((log) {
      setState(() {
        _logs.add(log);
        if (_logs.length > 20) _logs.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _locationService.stopLocationTracking();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _sendLocation() async {
    try {
      setState(() => _status = 'Отправка вручную...');
      final locationData = await _locationService.getCurrentLocation();
      await _locationService.sendLocationToServer(locationData.latitude!, locationData.longitude!, source: 'Ручная');
      setState(() => _status = 'Координаты отправлены вручную');
    } catch (e) {
      setState(() => _status = 'Ошибка при ручной отправке: $e');
    }
  }

  void _startTracking() {
    setState(() => _isTracking = true);
    _locationService.startLocationTracking();
    setState(() => _status = 'Автоматическая отправка запущена');
  }

  void _stopTracking() {
    setState(() => _isTracking = false);
    _locationService.stopLocationTracking();
    setState(() => _status = 'Автоматическая отправка остановлена');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Приложение автоматически отправляет координаты каждые 10 секунд\n'
                  'или нажмите кнопку для немедленной отправки',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _sendLocation,
                  child: const Text('Отправить геолокацию сейчас'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isTracking ? _stopTracking : _startTracking,
                  child: Text(_isTracking ? 'Остановить отслеживание' : 'Возобновить отслеживание'),
                ),
                const SizedBox(height: 20),
                Text(_status),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                child: Text(_logs[index], style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}