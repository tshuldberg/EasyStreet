package com.easystreet.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class SweepingNotificationWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        val streetName = inputData.getString(KEY_STREET_NAME) ?: "your street"
        val sweepTimeMillis = inputData.getLong(KEY_SWEEP_TIME, 0L)

        val timeStr = if (sweepTimeMillis > 0) {
            val sweepTime = LocalDateTime.ofInstant(
                Instant.ofEpochMilli(sweepTimeMillis),
                ZoneId.systemDefault(),
            )
            sweepTime.format(DateTimeFormatter.ofPattern("h:mm a"))
        } else {
            "soon"
        }

        ensureNotificationChannel()

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Street Sweeping Alert")
            .setContentText("Street sweeping at $timeStr on $streetName. Move your car!")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        // Use sweep time hash as unique notification ID so multiple alerts don't collide
        val notificationId = sweepTimeMillis.hashCode()

        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        manager.notify(notificationId, notification)

        return Result.success()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Sweeping Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alerts for upcoming street sweeping near your parked car"
            }
            val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val KEY_STREET_NAME = "street_name"
        const val KEY_SWEEP_TIME = "sweep_time"
        private const val CHANNEL_ID = "sweeping_alerts"
    }
}
