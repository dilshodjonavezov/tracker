package com.example.alarm

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import io.flutter.plugins.GeneratedPluginRegistrant // Добавляем для регистрации плагинов

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "alarm_service"
        var channel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine) // Регистрируем плагины
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "startAlarmService") {
                val intent = Intent(this, AlarmService::class.java)
                startForegroundService(intent)
                result.success("Alarm service started")
            } else {
                result.notImplemented()
            }
        }
        // Автоматический запуск сервиса
        val intent = Intent(this, AlarmService::class.java)
        startForegroundService(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        channel = null // Очищаем канал при уничтожении активности
    }
}