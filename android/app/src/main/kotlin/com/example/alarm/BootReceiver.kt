package com.example.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Intent.ACTION_BOOT_COMPLETED == intent.action) {
            val workRequest = OneTimeWorkRequestBuilder<LocationWorker>().build()
            WorkManager.getInstance(context).enqueue(workRequest)
        }
    }
}