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
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        title: const Text(
          'Location Tracker',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Montserrat',
          ),
        ),
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
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _sendLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEB1555),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFFEB1555).withOpacity(0.5),
                  ),
                  child: const Text(
                    'Отправить геолокацию сейчас',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isTracking ? _stopTracking : _startTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTracking ? Colors.grey[800] : const Color(0xFF1D2671),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 8,
                    shadowColor: Colors.black45,
                  ),
                  child: Text(
                    _isTracking ? 'Остановить отслеживание' : 'Возобновить отслеживание',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D2671), Color(0xFF0A0E21)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}