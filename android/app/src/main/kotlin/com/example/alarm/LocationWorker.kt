package com.example.alarm

import android.content.Context
import android.content.Intent
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class LocationWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val intent = Intent(applicationContext, AlarmService::class.java)
        applicationContext.startForegroundService(intent)
        return Result.success()
    }

    companion object {
        fun schedule(context: Context) {
            val workRequest = PeriodicWorkRequestBuilder<LocationWorker>(15, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "LocationWorker",
                androidx.work.ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
        }
    }
}