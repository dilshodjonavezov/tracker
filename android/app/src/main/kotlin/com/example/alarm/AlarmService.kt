package com.example.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Base64
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.net.HttpURLConnection
import java.net.URL
import java.util.Timer
import java.util.TimerTask

class AlarmService : Service() {
    private val CHANNEL_ID = "alarm_service_channel"
    private val NOTIFICATION_ID = 1
    private lateinit var locationManager: LocationManager
    private lateinit var timer: Timer
    private lateinit var handler: Handler
    private var interval: Long = 600000 // По умолчанию 10 минут (600 секунд * 1000)
    private var isServiceRunning = false

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            Log.d("AlarmService", "onLocationChanged: Received location: lat=${location.latitude}, lon=${location.longitude}, accuracy=${location.accuracy}")
            sendLocationToFlutter(location.latitude, location.longitude)
        }
        override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {
            Log.d("AlarmService", "onStatusChanged: provider=$provider, status=$status")
        }
        override fun onProviderEnabled(provider: String) {
            Log.d("AlarmService", "onProviderEnabled: provider=$provider")
        }
        override fun onProviderDisabled(provider: String) {
            Log.d("AlarmService", "onProviderDisabled: provider=$provider")
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d("AlarmService", "onCreate: Service created")
        createNotificationChannel()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        timer = Timer()
        handler = Handler(Looper.getMainLooper())
        Log.d("AlarmService", "onCreate: Initialization complete")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AlarmService", "onStartCommand: Service started with flags=$flags, startId=$startId")

        if (isServiceRunning) {
            Log.d("AlarmService", "onStartCommand: Service is already running")
            return START_STICKY
        }

        if (!checkLocationPermissions()) {
            Log.e("AlarmService", "onStartCommand: Missing location permissions, stopping service")
            stopSelf()
            return START_NOT_STICKY
        }

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Tracker")
            .setContentText("Отслеживание местоположения активно")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        isServiceRunning = true

        Log.d("AlarmService", "onStartCommand: Starting fetchSettings")
        fetchSettings()
        Log.d("AlarmService", "onStartCommand: Starting location updates")
        startLocationUpdates()
        Log.d("AlarmService", "onStartCommand: Sending pending locations")
        sendPendingLocations()

        timer.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                handler.post {
                    Log.d("AlarmService", "TimerTask: Checking location updates")
                    if (!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                        Log.e("AlarmService", "TimerTask: GPS is disabled")
                    }
                }
            }
        }, 0, interval)

        Log.d("AlarmService", "onStartCommand: Timer scheduled with interval $interval ms")
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("AlarmService", "onDestroy: Service destroyed")
        timer.cancel()
        locationManager.removeUpdates(locationListener)
        stopForeground(true)
        isServiceRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.d("AlarmService", "onBind: Called")
        return null
    }

    private fun checkLocationPermissions(): Boolean {
        val hasFineLocation = ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED
        val hasCoarseLocation = ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED
        val hasBackgroundLocation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        Log.d("AlarmService", "checkLocationPermissions: FineLocation=$hasFineLocation, CoarseLocation=$hasCoarseLocation, BackgroundLocation=$hasBackgroundLocation")
        return hasFineLocation && hasCoarseLocation && hasBackgroundLocation
    }

    private fun createNotificationChannel() {
        Log.d("AlarmService", "createNotificationChannel: Creating channel")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Tracker Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d("AlarmService", "createNotificationChannel: Channel created")
        }
    }

    private fun fetchSettings() {
        val sharedPreferences = getSharedPreferences("AlarmServicePrefs", Context.MODE_PRIVATE)
        val userId = sharedPreferences.getString("user_id", null)
        if (userId == null) {
            Log.e("AlarmService", "fetchSettings: user_id not found in SharedPreferences")
            return
        }
        Log.d("AlarmService", "fetchSettings: user_id=$userId")

        Thread {
            try {
                val url = URL("http://192.168.1.10:8080/MR_v1/hs/data/auth?user_id=$userId")
                Log.d("AlarmService", "fetchSettings: Sending GET request to $url")
                val connection = url.openConnection() as HttpURLConnection
                val auth = Base64.encodeToString("Админ:1".toByteArray(), Base64.NO_WRAP)
                connection.setRequestProperty("Authorization", "Basic $auth")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.requestMethod = "GET"
                connection.connectTimeout = 10000
                connection.readTimeout = 10000

                Log.d("AlarmService", "fetchSettings: Connecting to server")
                connection.connect()

                val responseCode = connection.responseCode
                Log.d("AlarmService", "fetchSettings: Response code: $responseCode")

                if (responseCode == 200) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    Log.d("AlarmService", "fetchSettings: Response received: $response")
                    val json = org.json.JSONObject(response)
                    if (json.getBoolean("result")) {
                        val editor = sharedPreferences.edit()
                        val gps = json.optBoolean("gps", false)
                        val intervalSeconds = json.optLong("interval", 600)
                        val from = json.optString("from", "0001-01-01T08:00:00")
                        val to = json.optString("to", "0001-01-01T18:00:00")
                        editor.putBoolean("gps", gps)
                        editor.putLong("interval", intervalSeconds * 1000)
                        interval = intervalSeconds * 1000
                        editor.putString("from", from)
                        editor.putString("to", to)
                        editor.apply()
                        Log.d("AlarmService", "fetchSettings: Settings updated: gps=$gps, interval=$intervalSeconds, from=$from, to=$to")
                    } else {
                        Log.e("AlarmService", "fetchSettings: Server returned result: false")
                    }
                } else {
                    Log.e("AlarmService", "fetchSettings: Failed with status: $responseCode")
                }
            } catch (e: Exception) {
                Log.e("AlarmService", "fetchSettings: Error: $e")
            }
        }.start()
    }

    private fun startLocationUpdates() {
        try {
            if (!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                Log.e("AlarmService", "startLocationUpdates: GPS is disabled")
                return
            }
            val sharedPreferences = getSharedPreferences("AlarmServicePrefs", Context.MODE_PRIVATE)
            val gps = sharedPreferences.getBoolean("gps", false)
            Log.d("AlarmService", "startLocationUpdates: gps flag=$gps")
            if (!gps) {
                Log.d("AlarmService", "startLocationUpdates: Location updates disabled by gps flag")
                return
            }

            val from = sharedPreferences.getString("from", "0001-01-01T08:00:00") ?: "0001-01-01T08:00:00"
            val to = sharedPreferences.getString("to", "0001-01-01T18:00:00") ?: "0001-01-01T18:00:00"
            Log.d("AlarmService", "startLocationUpdates: Time window: from=$from, to=$to")

            val fromParts = from.split("T")[1].split(":")
            val toParts = to.split("T")[1].split(":")
            val fromHour = fromParts[0].toInt()
            val fromMinute = fromParts[1].toInt()
            val toHour = toParts[0].toInt()
            val toMinute = toParts[1].toInt()

            val calendar = java.util.Calendar.getInstance()
            val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
            val currentMinute = calendar.get(java.util.Calendar.MINUTE)
            val currentTimeInMinutes = currentHour * 60 + currentMinute
            val fromTimeInMinutes = fromHour * 60 + fromMinute
            val toTimeInMinutes = toHour * 60 + toMinute
            Log.d("AlarmService", "startLocationUpdates: Current time=$currentTimeInMinutes minutes, Allowed window=$fromTimeInMinutes-$toTimeInMinutes minutes")

            if (currentTimeInMinutes < fromTimeInMinutes || currentTimeInMinutes >= toTimeInMinutes) {
                Log.d("AlarmService", "startLocationUpdates: Outside allowed time window ($from-$to)")
                return
            }

            Log.d("AlarmService", "startLocationUpdates: Requesting location updates with interval=$interval ms")
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                interval,
                0f,
                locationListener,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            Log.e("AlarmService", "startLocationUpdates: Permission error: $e")
            stopSelf()
        } catch (e: Exception) {
            Log.e("AlarmService", "startLocationUpdates: Unexpected error: $e")
        }
    }

    private fun sendLocationToFlutter(latitude: Double, longitude: Double) {
        Log.d("AlarmService", "sendLocationToFlutter: Sending lat=$latitude, lon=$longitude")
        if (MainActivity.channel == null) {
            Log.e("AlarmService", "sendLocationToFlutter: MainActivity.channel is null, saving locally")
            saveLocationLocally(latitude, longitude)
            return
        }
        MainActivity.channel?.invokeMethod("updateLocation", mapOf("latitude" to latitude, "longitude" to longitude))
        Log.d("AlarmService", "sendLocationToFlutter: Method invoked successfully")
    }

    private fun saveLocationLocally(latitude: Double, longitude: Double) {
        val sharedPreferences = getSharedPreferences("AlarmServicePrefs", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()
        val pendingLocations = sharedPreferences.getStringSet("pending_locations", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        val locationData = "{\"latitude\":$latitude,\"longitude\":$longitude,\"timestamp\":${System.currentTimeMillis()}}"
        pendingLocations.add(locationData)
        editor.putStringSet("pending_locations", pendingLocations)
        editor.apply()
        Log.d("AlarmService", "saveLocationLocally: Saved location: $locationData")
    }

    private fun sendPendingLocations() {
        if (MainActivity.channel == null) {
            Log.e("AlarmService", "sendPendingLocations: MainActivity.channel is null, cannot send pending locations")
            return
        }
        val sharedPreferences = getSharedPreferences("AlarmServicePrefs", Context.MODE_PRIVATE)
        val pendingLocations = sharedPreferences.getStringSet("pending_locations", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        if (pendingLocations.isEmpty()) {
            Log.d("AlarmService", "sendPendingLocations: No pending locations to send")
            return
        }
        Log.d("AlarmService", "sendPendingLocations: Found ${pendingLocations.size} pending locations")
        for (locationData in pendingLocations.toList()) {
            try {
                val json = org.json.JSONObject(locationData)
                val latitude = json.getDouble("latitude")
                val longitude = json.getDouble("longitude")
                val timestamp = json.getLong("timestamp")
                Log.d("AlarmService", "sendPendingLocations: Sending pending location: lat=$latitude, lon=$longitude, timestamp=$timestamp")
                MainActivity.channel?.invokeMethod("updateLocation", mapOf("latitude" to latitude, "longitude" to longitude))
                pendingLocations.remove(locationData)
                sharedPreferences.edit().putStringSet("pending_locations", pendingLocations).apply()
                Log.d("AlarmService", "sendPendingLocations: Removed sent location: $locationData")
            } catch (e: Exception) {
                Log.e("AlarmService", "sendPendingLocations: Error sending pending location: $e")
            }
        }
    }
}