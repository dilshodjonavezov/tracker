package com.example.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class AppMonitorService : Service() {
    private val CHANNEL_ID = "app_monitor_service_channel"
    private val NOTIFICATION_ID = 2
    private val handler = Handler(Looper.getMainLooper())
    private var isAppRunning = true

    override fun onCreate() {
        super.onCreate()
        Log.d("AppMonitorService", "onCreate: Service created")
        createNotificationChannel()
        startForegroundNotification()
        startMonitoring()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AppMonitorService", "onStartCommand: Service started with flags=$flags, startId=$startId")
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("AppMonitorService", "onDestroy: Service destroyed")
        handler.removeCallbacksAndMessages(null)
        // Отправляем broadcast, чтобы перезапустить приложение
        val intent = Intent("com.example.alarm.APP_RESTART")
        sendBroadcast(intent)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Monitor Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d("AppMonitorService", "createNotificationChannel: Channel created")
        }
    }

    private fun startForegroundNotification() {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App Monitor")
            .setContentText("Monitoring app state")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        Log.d("AppMonitorService", "startForegroundNotification: Foreground notification started")
    }

    private fun startMonitoring() {
        // Периодически проверяем, работает ли процесс приложения
        handler.postDelayed(object : Runnable {
            override fun run() {
                if (!isAppRunning()) {
                    Log.d("AppMonitorService", "startMonitoring: App process is not running, stopping service")
                    isAppRunning = false
                    stopSelf()
                } else {
                    Log.d("AppMonitorService", "startMonitoring: App is still running")
                    handler.postDelayed(this, 1000) // Проверяем каждую секунду
                }
            }
        }, 1000)
    }

    private fun isAppRunning(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val runningProcesses = activityManager.runningAppProcesses ?: return false
        val packageName = applicationContext.packageName
        for (processInfo in runningProcesses) {
            if (processInfo.processName == packageName && processInfo.importance == android.app.ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
                return true
            }
        }
        return false
    }
}