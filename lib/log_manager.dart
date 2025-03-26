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
    platform.setMethodCallHandler(_handleLocationUpdate);
    _checkAndSendPendingData();
  }

  Future<void> _handleLocationUpdate(MethodCall call) async {
    if (call.method == 'updateLocation') {
      final latitude = call.arguments['latitude'] as double;
      final longitude = call.arguments['longitude'] as double;
      await sendLocationToServer(latitude, longitude, source: 'Автоматическая');
    }
  }

  Future<LocationData> getCurrentLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      throw Exception('Location permissions are denied');
    }

    final locationData = await _location.getLocation();
    return locationData;
  }

  Future<bool> _isInternetAvailable() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<bool> _canSendLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final gps = prefs.getBool('gps') ?? false;
    final from = prefs.getString('from') ?? '0001-01-01T08:00:00';
    final to = prefs.getString('to') ?? '0001-01-01T18:00:00';

    if (!gps) {
      return false;
    }

    final now = DateTime.now();
    final fromTime = DateTime.parse(from);
    final toTime = DateTime.parse(to);

    final currentTimeInMinutes = now.hour * 60 + now.minute;
    final fromTimeInMinutes = fromTime.hour * 60 + fromTime.minute;
    final toTimeInMinutes = toTime.hour * 60 + toTime.minute;

    if (currentTimeInMinutes < fromTimeInMinutes || currentTimeInMinutes >= toTimeInMinutes) {
      return false;
    }

    return true;
  }

  Future<void> _savePendingData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingData = prefs.getStringList('pending_locations') ?? [];
    pendingData.add(jsonEncode(data));
    await prefs.setStringList('pending_locations', pendingData);
  }

  Future<void> _checkAndSendPendingData() async {
    if (!await _isInternetAvailable()) {
      return;
    }

    if (!await _canSendLocation()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> pendingData = prefs.getStringList('pending_locations') ?? [];
    if (pendingData.isEmpty) {
      return;
    }

    String basicAuth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

    for (var dataString in pendingData.toList()) {
      final data = jsonDecode(dataString);
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

        if (response.statusCode == 200) {
          pendingData.remove(dataString);
          await prefs.setStringList('pending_locations', pendingData);
        }
      } catch (e) {
        break;
      }
    }
  }

  Future<void> sendLocationToServer(double latitude, double longitude, {String source = 'Ручная'}) async {
    if (!await _canSendLocation()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    final now = DateTime.now();
    final formattedDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final data = {
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'date': formattedDate,
    };

    try {
      if (!await _isInternetAvailable()) {
        await _savePendingData(data);
        return;
      }

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

      if (response.statusCode != 200) {
        throw Exception('Failed to send location: ${response.statusCode} - ${response.body}');
      }

      await _checkAndSendPendingData();
    } catch (e) {
      await _savePendingData(data);
    }
  }

  void startLocationTracking() {
    _timer?.cancel();
    SharedPreferences.getInstance().then((prefs) {
      final interval = prefs.getInt('interval') ?? 600;
      _timer = Timer.periodic(Duration(seconds: interval), (timer) async {
        try {
          final locationData = await getCurrentLocation();
          await sendLocationToServer(locationData.latitude!, locationData.longitude!, source: 'Автоматическая');
        } catch (e) {
          // Игнорируем ошибки, чтобы таймер продолжил работать
        }
      });
    });
  }

  void stopLocationTracking() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _timer?.cancel();
    _logController.close();
  }
}