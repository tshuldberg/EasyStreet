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

    private const val WORK_TAG = "sweeping_notification"

    fun schedule(
        context: Context,
        sweepingTime: LocalDateTime,
        streetName: String,
        leadMinutes: Int = 60,
    ) {
        val now = LocalDateTime.now()
        val notifyTime = sweepingTime.minusMinutes(leadMinutes.toLong())

        if (notifyTime.isBefore(now)) return

        val delay = Duration.between(now, notifyTime)
        val sweepEpochMillis = sweepingTime.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val workName = "sweeping_alert_$sweepEpochMillis"

        val workRequest = OneTimeWorkRequestBuilder<SweepingNotificationWorker>()
            .setInitialDelay(delay.toMillis(), TimeUnit.MILLISECONDS)
            .addTag(WORK_TAG)
            .setInputData(
                workDataOf(
                    SweepingNotificationWorker.KEY_STREET_NAME to streetName,
                    SweepingNotificationWorker.KEY_SWEEP_TIME to sweepEpochMillis,
                )
            )
            .build()

        WorkManager.getInstance(context)
            .enqueueUniqueWork(workName, ExistingWorkPolicy.REPLACE, workRequest)
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelAllWorkByTag(WORK_TAG)
    }
}
