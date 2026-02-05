package com.easystreet.notification

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.time.Duration
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit

object NotificationScheduler {

    private const val WORK_NAME = "sweeping_alert"

    fun schedule(context: Context, sweepingTime: LocalDateTime, streetName: String) {
        val now = LocalDateTime.now()
        val notifyTime = sweepingTime.minusHours(1)

        if (notifyTime.isBefore(now)) return

        val delay = Duration.between(now, notifyTime)

        val workRequest = OneTimeWorkRequestBuilder<SweepingNotificationWorker>()
            .setInitialDelay(delay.toMillis(), TimeUnit.MILLISECONDS)
            .addTag("sweeping_notification")
            .setInputData(
                workDataOf(
                    SweepingNotificationWorker.KEY_STREET_NAME to streetName,
                    SweepingNotificationWorker.KEY_SWEEP_TIME to sweepingTime.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(),
                )
            )
            .build()

        WorkManager.getInstance(context)
            .enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.REPLACE, workRequest)
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
}
