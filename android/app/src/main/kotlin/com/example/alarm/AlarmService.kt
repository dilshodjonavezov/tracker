package com.example.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.location.LocationManager
import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.Timer
import java.util.TimerTask

class AlarmService : Service() {
    private val CHANNEL_ID = "alarm_service_channel"
    private val NOTIFICATION_ID = 1
    private lateinit var locationManager: LocationManager
    private lateinit var timer: Timer
    private lateinit var handler: Handler
    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            Log.d("AlarmService", "onLocationChanged: Received location: lat=${location.latitude}, lon=${location.longitude}")
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
        startForeground(NOTIFICATION_ID, createNotification())
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        timer = Timer()
        handler = Handler(Looper.getMainLooper())
        Log.d("AlarmService", "onCreate: Initialization complete")
        startLocationUpdates()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AlarmService", "onStartCommand: Service started with flags=$flags, startId=$startId")
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
        }, 0, 10000) // Каждые 10 секунд
        Log.d("AlarmService", "onStartCommand: Timer scheduled")
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("AlarmService", "onDestroy: Service destroyed")
        timer.cancel()
        locationManager.removeUpdates(locationListener)
        stopForeground(true)
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.d("AlarmService", "onBind: Called")
        return null
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

    private fun createNotification(): Notification {
        Log.d("AlarmService", "createNotification: Building notification")
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Tracker")
            .setContentText("Отслеживание местоположения активно")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startLocationUpdates() {
        try {
            if (!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                Log.e("AlarmService", "startLocationUpdates: GPS is disabled")
                return
            }
            Log.d("AlarmService", "startLocationUpdates: Requesting location updates")
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                10000L, // Минимальное время между обновлениями (10 секунд)
                0f,     // Минимальное расстояние между обновлениями (0 метров)
                locationListener,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            Log.e("AlarmService", "startLocationUpdates: Permission error: $e")
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
        Log.d("AlarmService", "sendLocationToFlutter: Method invoked")
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
                Log.d("AlarmService", "sendPendingLocations: Sending pending location: lat=$latitude, lon=$longitude")
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