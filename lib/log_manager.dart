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
    print('LocationService: Initializing...');
    platform.setMethodCallHandler(_handleLocationUpdate);
    _checkAndSendPendingData();
    print('LocationService: Initialized');
  }

  Future<void> _handleLocationUpdate(MethodCall call) async {
    print('LocationService: _handleLocationUpdate called with method=${call.method}');
    if (call.method == 'updateLocation') {
      final latitude = call.arguments['latitude'] as double;
      final longitude = call.arguments['longitude'] as double;
      print('LocationService: Received location from native: lat=$latitude, lon=$longitude');
      final logMessage = 'Автоматическая отправка: lat=$latitude, lon=$longitude, time=${DateTime.now()}';
      _logController.add(logMessage);
      await sendLocationToServer(latitude, longitude, source: 'Автоматическая');
    }
  }

  Future<LocationData> getCurrentLocation() async {
    print('LocationService: getCurrentLocation called');
    bool serviceEnabled = await _location.serviceEnabled();
    print('LocationService: Location service enabled=$serviceEnabled');
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      print('LocationService: Requested location service, enabled=$serviceEnabled');
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    print('LocationService: Location permission status=$permissionGranted');
    if (permissionGranted == PermissionStatus.denied) {
      throw Exception('Location permissions are denied');
    }

    final locationData = await _location.getLocation();
    print('LocationService: Current location: lat=${locationData.latitude}, lon=${locationData.longitude}, accuracy=${locationData.accuracy}');
    return locationData;
  }

  Future<bool> _isInternetAvailable() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = connectivityResult != ConnectivityResult.none;
    print('LocationService: Internet available=$isConnected, connectivityResult=$connectivityResult');
    return isConnected;
  }

  Future<bool> _canSendLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final gps = prefs.getBool('gps') ?? false;
    final from = prefs.getString('from') ?? '0001-01-01T08:00:00';
    final to = prefs.getString('to') ?? '0001-01-01T18:00:00';
    print('LocationService: _canSendLocation: gps=$gps, from=$from, to=$to');

    if (!gps) {
      print('LocationService: _canSendLocation: GPS flag is false, cannot send location');
      return false;
    }

    final now = DateTime.now();
    final fromTime = DateTime.parse(from);
    final toTime = DateTime.parse(to);

    final currentTimeInMinutes = now.hour * 60 + now.minute;
    final fromTimeInMinutes = fromTime.hour * 60 + fromTime.minute;
    final toTimeInMinutes = toTime.hour * 60 + toTime.minute;
    print('LocationService: _canSendLocation: Current time=$currentTimeInMinutes minutes, Allowed window=$fromTimeInMinutes-$toTimeInMinutes minutes');

    if (currentTimeInMinutes < fromTimeInMinutes || currentTimeInMinutes >= toTimeInMinutes) {
      print('LocationService: _canSendLocation: Outside allowed time window, cannot send location');
      return false;
    }

    print('LocationService: _canSendLocation: Can send location');
    return true;
  }

  Future<void> _savePendingData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingData = prefs.getStringList('pending_locations') ?? [];
    pendingData.add(jsonEncode(data));
    await prefs.setStringList('pending_locations', pendingData);
    print('LocationService: _savePendingData: Saved pending data: $data');
  }

  Future<void> _checkAndSendPendingData() async {
    print('LocationService: _checkAndSendPendingData called');
    if (!await _isInternetAvailable()) {
      print('LocationService: _checkAndSendPendingData: No internet, skipping');
      return;
    }

    if (!await _canSendLocation()) {
      print('LocationService: _checkAndSendPendingData: Cannot send location due to gps or time window');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> pendingData = prefs.getStringList('pending_locations') ?? [];
    print('LocationService: _checkAndSendPendingData: Found ${pendingData.length} pending locations');
    if (pendingData.isEmpty) {
      print('LocationService: _checkAndSendPendingData: No pending data to send');
      return;
    }

    String basicAuth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

    for (var dataString in pendingData.toList()) {
      final data = jsonDecode(dataString);
      print('LocationService: _checkAndSendPendingData: Processing pending data: $data');
      try {
        print('LocationService: _checkAndSendPendingData: Sending POST request to http://192.168.1.10:8080/MR_v1/hs/data/coordinates');
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

        print('LocationService: _checkAndSendPendingData: Response code=${response.statusCode}, body=${response.body}');
        if (response.statusCode == 200) {
          pendingData.remove(dataString);
          await prefs.setStringList('pending_locations', pendingData);
          print('LocationService: _checkAndSendPendingData: Successfully sent and removed pending data: $data');
          _logController.add('Отправлено из очереди: ${data['latitude']}, ${data['longitude']}, time=${DateTime.now()}');
        } else {
          print('LocationService: _checkAndSendPendingData: Failed to send pending data: status=${response.statusCode}, body=${response.body}');
          break;
        }
      } catch (e) {
        print('LocationService: _checkAndSendPendingData: Error sending pending data: $e');
        break;
      }
    }
  }

  Future<void> sendLocationToServer(double latitude, double longitude, {String source = 'Ручная'}) async {
    print('LocationService: sendLocationToServer called: lat=$latitude, lon=$longitude, source=$source');
    if (!await _canSendLocation()) {
      print('LocationService: sendLocationToServer: Cannot send location due to gps or time window');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    print('LocationService: sendLocationToServer: user_id=$userId');

    final now = DateTime.now();
    final formattedDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    print('LocationService: sendLocationToServer: Formatted date=$formattedDate');

    final data = {
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'date': formattedDate,
    };
    print('LocationService: sendLocationToServer: Prepared data: $data');

    try {
      if (!await _isInternetAvailable()) {
        print('LocationService: sendLocationToServer: No internet, saving to pending');
        await _savePendingData(data);
        return;
      }

      String basicAuth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
      print('LocationService: sendLocationToServer: Sending POST request to http://192.168.1.10:8080/MR_v1/hs/data/coordinates');
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

      print('LocationService: sendLocationToServer: Response code=${response.statusCode}, body=${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Failed to send location: ${response.statusCode} - ${response.body}');
      }

      print('LocationService: sendLocationToServer: Successfully sent location to server');
      _logController.add('$source отправка: lat=$latitude, lon=$longitude, time=$now');
      await _checkAndSendPendingData();
    } catch (e) {
      print('LocationService: sendLocationToServer: Error sending location: $e');
      await _savePendingData(data);
    }
  }

  void startLocationTracking() {
    print('LocationService: startLocationTracking called');
    _timer?.cancel();
    SharedPreferences.getInstance().then((prefs) {
      final interval = prefs.getInt('interval') ?? 600;
      print('LocationService: startLocationTracking: Starting timer with interval=$interval seconds');
      _timer = Timer.periodic(Duration(seconds: interval), (timer) async {
        try {
          print('LocationService: Timer tick: Getting current location');
          final locationData = await getCurrentLocation();
          print('LocationService: Timer tick: Sending location to server');
          await sendLocationToServer(locationData.latitude!, locationData.longitude!, source: 'Автоматическая');
        } catch (e) {
          print('LocationService: Timer tick: Error: $e');
        }
      });
    });
  }

  void stopLocationTracking() {
    print('LocationService: stopLocationTracking called');
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    print('LocationService: dispose called');
    _timer?.cancel();
    _logController.close();
  }
}