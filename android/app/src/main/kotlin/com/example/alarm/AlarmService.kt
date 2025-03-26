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

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        timer = Timer()
        handler = Handler(Looper.getMainLooper())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        timer.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                handler.post {
                    try {
                        if (!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                            Log.e("AlarmService", "GPS is disabled")
                            return@post
                        }
                        locationManager.requestSingleUpdate(LocationManager.GPS_PROVIDER, object : LocationListener {
                            override fun onLocationChanged(location: Location) {
                                Log.d("AlarmService", "Sending location: lat=${location.latitude}, lon=${location.longitude}")
                                sendLocationToFlutter(location.latitude, location.longitude)
                            }
                            override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                            override fun onProviderEnabled(provider: String) {}
                            override fun onProviderDisabled(provider: String) {}
                        }, null)
                    } catch (e: SecurityException) {
                        Log.e("AlarmService", "Permission error: $e")
                    }
                }
            }
        }, 0, 10000) // Каждые 10 секунд
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        timer.cancel()
        stopForeground(true)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Tracker Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Tracker")
            .setContentText("Отслеживание местоположения активно")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun sendLocationToFlutter(latitude: Double, longitude: Double) {
        MainActivity.channel?.invokeMethod("updateLocation", mapOf("latitude" to latitude, "longitude" to longitude))
    }
}