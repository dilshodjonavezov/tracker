import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
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
    print('LocationService: Constructor called');
    platform.setMethodCallHandler(_handleLocationUpdate);
    _checkAndSendPendingData();
    print('LocationService: Constructor finished');
  }

  Future<void> _handleLocationUpdate(MethodCall call) async {
    print('LocationService: _handleLocationUpdate called with method=${call.method}');
    if (call.method == 'updateLocation') {
      final latitude = call.arguments['latitude'] as double;
      final longitude = call.arguments['longitude'] as double;
      print('LocationService: Received location from AlarmService: lat=$latitude, lon=$longitude');
      _logController.add('LocationService: Received location: lat=$latitude, lon=$longitude');
      await sendLocationToServer(latitude, longitude, source: 'Автоматическая');
    } else {
      print('LocationService: Unknown method: ${call.method}');
      _logController.add('LocationService: Unknown method: ${call.method}');
    }
  }

  Future<LocationData> getCurrentLocation() async {
    print('LocationService: getCurrentLocation called');
    _logController.add('Получение текущей геолокации');
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      print('LocationService: Location service disabled, requesting enable');
      _logController.add('Запрос включения службы геолокации');
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        print('LocationService: Location service still disabled');
        throw Exception('Location services are disabled');
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      print('LocationService: Permission denied, requesting permission');
      _logController.add('Запрос разрешения на геолокацию');
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        print('LocationService: Permission not granted');
        throw Exception('Location permissions are denied');
      }
    }

    final locationData = await _location.getLocation();
    print('LocationService: Location received: lat=${locationData.latitude}, lon=${locationData.longitude}');
    _logController.add('Получены координаты: lat=${locationData.latitude}, lon=${locationData.longitude}');
    return locationData;
  }

  Future<bool> _isInternetAvailable() async {
    print('LocationService: _isInternetAvailable called');
    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = connectivityResult != ConnectivityResult.none;
    print('LocationService: Internet check result: $isConnected');
    _logController.add('Проверка интернета: ${isConnected ? "Доступен" : "Недоступен"}');
    return isConnected;
  }

  Future<void> _savePendingData(Map<String, dynamic> data) async {
    print('LocationService: _savePendingData called with data=$data');
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingData = prefs.getStringList('pending_locations') ?? [];
    pendingData.add(jsonEncode(data));
    await prefs.setStringList('pending_locations', pendingData);
    print('LocationService: Data saved to SharedPreferences: $data');
    _logController.add('Данные сохранены локально: $data');
  }

  Future<void> _checkAndSendPendingData() async {
    print('LocationService: _checkAndSendPendingData called');
    if (!await _isInternetAvailable()) {
      print('LocationService: No internet, skipping pending data send');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> pendingData = prefs.getStringList('pending_locations') ?? [];
    if (pendingData.isEmpty) {
      print('LocationService: No pending data to send');
      return;
    }

    print('LocationService: Found ${pendingData.length} pending records');
    _logController.add('Обнаружено ${pendingData.length} накопленных записей, отправка...');
    String basicAuth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

    for (var dataString in pendingData.toList()) {
      final data = jsonDecode(dataString);
      print('LocationService: Sending pending data: $data');
      try {
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

        print('LocationService: Server response for pending data: status=${response.statusCode}, body=${response.body}');
        _logController.add('Ответ сервера для накопленных данных: status=${response.statusCode}, body=${response.body}');
        if (response.statusCode == 200) {
          pendingData.remove(dataString);
          await prefs.setStringList('pending_locations', pendingData);
          print('LocationService: Pending data sent successfully: $data');
          _logController.add('Накопленные данные успешно отправлены: $data');
        }
      } catch (e) {
        print('LocationService: Error sending pending data: $e');
        _logController.add('Ошибка при отправке накопленных данных: $e');
        break;
      }
    }
  }

  Future<void> sendLocationToServer(double latitude, double longitude, {String source = 'Ручная'}) async {
    print('LocationService: sendLocationToServer called with lat=$latitude, lon=$longitude, source=$source');
    _logController.add('$source отправка координат на сервер');
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    print('LocationService: user_id from SharedPreferences: $userId');
    _logController.add('user_id из SharedPreferences: $userId');

    final now = DateTime.now();
    final formattedDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final data = {
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'date': formattedDate,
    };
    print('LocationService: Data to send: $data');
    _logController.add('Данные для отправки: $data');

    try {
      if (!await _isInternetAvailable()) {
        print('LocationService: No internet, saving data locally');
        await _savePendingData(data);
        return;
      }

      String basicAuth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
      print('LocationService: Sending HTTP request to server');
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

      print('LocationService: Server response: status=${response.statusCode}, body=${response.body}');
      _logController.add('Ответ сервера: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode != 200) {
        print('LocationService: Failed to send location: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to send location: ${response.statusCode} - ${response.body}');
      }
      print('LocationService: Location sent successfully ($source)');
      _logController.add('Координаты успешно отправлены ($source)');

      await _checkAndSendPendingData();
    } catch (e) {
      print('LocationService: Error sending location ($source): $e');
      _logController.add('Ошибка при отправке ($source): $e');
      await _savePendingData(data);
    }
  }

  void startLocationTracking() {
    print('LocationService: startLocationTracking called');
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      print('LocationService: Timer tick');
      try {
        // Здесь можно добавить дополнительную логику, если нужно
      } catch (e) {
        print('LocationService: Error in periodic tracking: $e');
        _logController.add('Ошибка в периодической отправке: $e');
      }
    });
    print('LocationService: Periodic tracking started');
    _logController.add('Запущена периодическая отправка каждые 10 секунд');
  }

  void stopLocationTracking() {
    print('LocationService: stopLocationTracking called');
    _timer?.cancel();
    _timer = null;
    print('LocationService: Periodic tracking stopped');
    _logController.add('Периодическая отправка остановлена');
  }

  void dispose() {
    print('LocationService: dispose called');
    _logController.close();
  }
}