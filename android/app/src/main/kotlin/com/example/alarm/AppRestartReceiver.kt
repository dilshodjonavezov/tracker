package com.example.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AppRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.example.alarm.APP_RESTART") {
            Log.d("AppRestartReceiver", "onReceive: App restart broadcast received")
            // Запускаем приложение
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(launchIntent)
                Log.d("AppRestartReceiver", "onReceive: App relaunched")
            } else {
                Log.e("AppRestartReceiver", "onReceive: Failed to get launch intent")
            }
        }
    }
}