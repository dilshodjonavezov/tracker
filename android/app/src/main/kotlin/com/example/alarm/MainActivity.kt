package com.example.alarm

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    companion object {
        var channel: MethodChannel? = null
        private const val REQUEST_LOCATION_PERMISSIONS = 100
        private const val REQUEST_BACKGROUND_LOCATION = 101
        private const val REQUEST_OVERLAY_PERMISSION = 102
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "onCreate: MainActivity created")

        val plugin = AlarmServicePlugin()
        flutterEngine?.plugins?.add(plugin)

        requestLocationPermissions()
        requestOverlayPermission() // Запрашиваем разрешение SYSTEM_ALERT_WINDOW
        LocationWorker.schedule(this) // Запускаем WorkManager

        // Запускаем AppMonitorService
        startAppMonitorService()
    }

    private fun startAppMonitorService() {
        val intent = Intent(this, AppMonitorService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d("MainActivity", "startAppMonitorService: AppMonitorService started")
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                Log.d("MainActivity", "requestOverlayPermission: Requesting SYSTEM_ALERT_WINDOW")
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
            } else {
                Log.d("MainActivity", "requestOverlayPermission: SYSTEM_ALERT_WINDOW already granted")
            }
        }
    }

    private fun requestLocationPermissions() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            Log.d("MainActivity", "requestLocationPermissions: Requesting ACCESS_FINE_LOCATION")
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                REQUEST_LOCATION_PERMISSIONS
            )
        } else {
            Log.d("MainActivity", "requestLocationPermissions: ACCESS_FINE_LOCATION already granted")
            requestBackgroundLocationPermission()
        }
    }

    private fun requestBackgroundLocationPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            Log.d("MainActivity", "requestBackgroundLocationPermission: Requesting ACCESS_BACKGROUND_LOCATION")
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                REQUEST_BACKGROUND_LOCATION
            )
        } else {
            Log.d("MainActivity", "requestBackgroundLocationPermission: ACCESS_BACKGROUND_LOCATION already granted")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_OVERLAY_PERMISSION) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    Log.d("MainActivity", "onActivityResult: SYSTEM_ALERT_WINDOW granted")
                } else {
                    Log.e("MainActivity", "onActivityResult: SYSTEM_ALERT_WINDOW denied")
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            REQUEST_LOCATION_PERMISSIONS -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d("MainActivity", "onRequestPermissionsResult: ACCESS_FINE_LOCATION granted")
                    requestBackgroundLocationPermission()
                } else {
                    Log.e("MainActivity", "onRequestPermissionsResult: ACCESS_FINE_LOCATION denied")
                }
            }
            REQUEST_BACKGROUND_LOCATION -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d("MainActivity", "onRequestPermissionsResult: ACCESS_BACKGROUND_LOCATION granted")
                } else {
                    Log.e("MainActivity", "onRequestPermissionsResult: ACCESS_BACKGROUND_LOCATION denied")
                }
            }
        }
    }
}

class AlarmServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: android.content.Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MainActivity.channel = MethodChannel(binding.binaryMessenger, "alarm_service")
        MainActivity.channel?.setMethodCallHandler(this)
        context = binding.applicationContext
        Log.d("AlarmServicePlugin", "onAttachedToEngine: MethodChannel initialized")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MainActivity.channel?.setMethodCallHandler(null)
        MainActivity.channel = null
        context = null
        Log.d("AlarmServicePlugin", "onDetachedFromEngine: MethodChannel detached")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d("AlarmServicePlugin", "onMethodCall: Method=${call.method}")
        when (call.method) {
            "startAlarmService" -> {
                try {
                    val sharedPreferences = context?.getSharedPreferences("AlarmServicePrefs", android.content.Context.MODE_PRIVATE)
                    val editor = sharedPreferences?.edit()
                    val userId = sharedPreferences?.getString("user_id", null)
                    if (userId == null) {
                        val flutterPrefs = context?.getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
                        val flutterUserId = flutterPrefs?.getString("flutter.user_id", null)
                        if (flutterUserId != null) {
                            editor?.putString("user_id", flutterUserId)
                            editor?.apply()
                            Log.d("AlarmServicePlugin", "onMethodCall: user_id saved: $flutterUserId")
                        }
                    }

                    val intent = Intent(context, AlarmService::class.java)
                    context?.startForegroundService(intent)
                    Log.d("AlarmServicePlugin", "onMethodCall: AlarmService started")
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("AlarmServicePlugin", "onMethodCall: Failed to start AlarmService: $e")
                    result.error("START_SERVICE_ERROR", "Failed to start AlarmService", e.message)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}