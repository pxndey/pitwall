package com.pitwall.app.util

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.pitwall.app.R
import com.pitwall.app.data.remote.model.JolpicaRace
import java.time.Duration
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.concurrent.TimeUnit

object NotificationHelper {

    private const val CHANNEL_ID = "pitwall_races"
    private const val CHANNEL_NAME = "Race Reminders"

    fun createChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Notifications for upcoming F1 sessions"
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    fun hasPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    fun scheduleRaceNotifications(context: Context, race: JolpicaRace) {
        val raceDate = parseDateFlexible(race.date) ?: return
        val round = race.roundInt

        data class Session(val name: String, val dayOffset: Long, val time: LocalTime)
        val sessions = listOf(
            Session("FP1", -2, LocalTime.of(11, 30)),
            Session("FP2", -2, LocalTime.of(15, 0)),
            Session("FP3", -1, LocalTime.of(11, 30)),
            Session("Qualifying", -1, LocalTime.of(15, 0)),
            Session("Race", 0, parseDateTime(race.date, race.time)?.toLocalTime() ?: LocalTime.of(14, 0)),
        )

        val workManager = WorkManager.getInstance(context)

        for (session in sessions) {
            val sessionDateTime = raceDate.plusDays(session.dayOffset).atTime(session.time).minusMinutes(30)
            val delay = Duration.between(LocalDateTime.now(), sessionDateTime)
            if (delay.isNegative) continue

            val data = Data.Builder()
                .putString("race_name", race.raceName ?: "Race")
                .putString("session_name", session.name)
                .putInt("round", round)
                .build()

            val tag = "pitwall-$round-${session.name}"
            workManager.cancelAllWorkByTag(tag)

            val request = OneTimeWorkRequestBuilder<RaceNotificationWorker>()
                .setInitialDelay(delay.toMillis(), TimeUnit.MILLISECONDS)
                .setInputData(data)
                .addTag(tag)
                .addTag("pitwall-notification")
                .build()

            workManager.enqueue(request)
        }
    }

    fun scheduleAllUpcoming(context: Context, races: List<JolpicaRace>) {
        for (race in races) {
            if (!isPast(race.date)) {
                scheduleRaceNotifications(context, race)
            }
        }
    }

    fun cancelAll(context: Context) {
        WorkManager.getInstance(context).cancelAllWorkByTag("pitwall-notification")
    }
}

class RaceNotificationWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        val raceName = inputData.getString("race_name") ?: "Race"
        val sessionName = inputData.getString("session_name") ?: "Session"

        NotificationHelper.createChannel(applicationContext)

        if (!NotificationHelper.hasPermission(applicationContext)) return Result.success()

        val notification = NotificationCompat.Builder(applicationContext, "pitwall_races")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("$sessionName starting soon")
            .setContentText("$raceName — $sessionName begins in 30 minutes")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val id = "$raceName-$sessionName".hashCode()
        NotificationManagerCompat.from(applicationContext).notify(id, notification)

        return Result.success()
    }
}
