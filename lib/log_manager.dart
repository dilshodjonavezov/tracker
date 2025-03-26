import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';

class LocationService {
  static const String _username = 'Админ';
  static const String _password = '1';
  static const platform = MethodChannel('alarm_service');
  final Location _location = Location();
  Timer? _timer;
  final _logController = StreamController<String>.broadcast();

  Stream<String> get logStream => _logController.stream;

  LocationService() {
    platform.setMethodCallHandler(_handleLocationUpdate);
  }

  Future<void> _handleLocationUpdate(MethodCall call) async {
    if (call.method == 'updateLocation') {
      final latitude = call.arguments['latitude'] as double;
      final longitude = call.arguments['longitude'] as double;
      await sendLocationToServer(latitude, longitude, source: 'Автоматическая');
    }
  }

  Future<LocationData> getCurrentLocation() async {
    _logController.add('Получение текущей геолокации');
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      _logController.add('Запрос включения службы геолокации');
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      _logController.add('Запрос разрешения на геолокацию');
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw Exception('Location permissions are denied');
      }
    }

    final locationData = await _location.getLocation();
    _logController.add('Получены координаты: lat=${locationData.latitude}, lon=${locationData.longitude}');
    return locationData;
  }

  Future<void> sendLocationToServer(double latitude, double longitude, {String source = 'Ручная'}) async {
    _logController.add('$source отправка координат на сервер');
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      _logController.add('user_id из SharedPreferences: $userId');

      // Форматируем дату в требуемый формат: ГГГГММДДЧЧММСС
      final now = DateTime.now();
      final formattedDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      final data = {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'date': formattedDate, // Отправляем дату в формате 20130110125905
      };
      _logController.add('Данные для отправки: $data');

      String basicAuth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

      final response = await http.post(
        Uri.parse('http://192.168.1.10:8080/MR_v1/hs/data/coordinates'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
        },
        body: jsonEncode(data),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Превышено время ожидания ответа от сервера'),
      );

      _logController.add('Ответ сервера: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to send location: ${response.statusCode} - ${response.body}');
      }
      _logController.add('Координаты успешно отправлены ($source)');
    } catch (e) {
      _logController.add('Ошибка при отправке ($source): $e');
      rethrow;
    }
  }

  void startLocationTracking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        // Здесь можно добавить дополнительную логику, если нужно
      } catch (e) {
        _logController.add('Ошибка в периодической отправке: $e');
      }
    });
    _logController.add('Запущена периодическая отправка каждые 10 секунд');
  }

  void stopLocationTracking() {
    _timer?.cancel();
    _timer = null;
    _logController.add('Периодическая отправка остановлена');
  }

  void dispose() {
    _logController.close();
  }
}