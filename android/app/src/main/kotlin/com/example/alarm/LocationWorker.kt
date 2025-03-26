package com.example.alarm

import android.content.Context
import android.content.Intent
import androidx.work.Worker
import androidx.work.WorkerParameters

class LocationWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val intent = Intent(applicationContext, AlarmService::class.java)
        applicationContext.startForegroundService(intent)
        return Result.success()
    }
}