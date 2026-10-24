package com.workoutes

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import androidx.core.graphics.toColorInt
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.core.graphics.createBitmap
import androidx.core.graphics.drawable.DrawableCompat
import com.workoutes.ui.muscleSymbols
import com.workoutes.ui.hexColor
import androidx.compose.ui.graphics.toArgb
import com.workoutes.data.AppTheme
import com.workoutes.data.AppState
import kotlinx.coroutines.launch

internal object ExerciseNotification {
    private const val channel = "active-exercise"
    private const val notificationId = 1
    fun sync(context: Context, state: AppState) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(channel, "Active Exercise", NotificationManager.IMPORTANCE_LOW))
        val active = state.data.exercises.firstOrNull { it.id == state.activeExerciseId && !it.isDone }
        if (active == null) { manager.cancel(notificationId); return }
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java).putExtra("revealExerciseId", active.id)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        fun action(name: String, request: Int): PendingIntent = PendingIntent.getBroadcast(context, request,
            Intent(context, ExerciseActionReceiver::class.java).setAction(name)
                .setData("workoutes://session/${state.activeSession?.id}/$name".toUri())
                .putExtra("exerciseId", active.id).putExtra("sessionId", state.activeSession?.id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val targets = "${state.preferences.unit.format(active.weight)} · ${active.numberOfSets} sets · ${active.reps} reps"
        val tags = active.tags.mapNotNull { ref -> state.data.tags.firstOrNull { it.id == ref.id } }
        val text = listOf(active.subtitle, targets, active.details, tags.joinToString(" · ") { it.name }, if (active.increaseLoadNextTime) "Increase load next time" else "").filter { it.isNotBlank() }.joinToString("\n")
        val dark = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        val muscleTag = tags.firstOrNull { tag -> muscleSymbols.any { it.name == tag.iconName } }
        val thumbnail = muscleTag?.let { tag ->
            val symbol = muscleSymbols.first { it.name == tag.iconName }
            createBitmap(128,128).also { bitmap ->
                val canvas = Canvas(bitmap)
                for ((resource,color) in listOf(symbol.base to if (dark) 0xFF5C5C5C.toInt() else 0xFFC7C7C7.toInt(), symbol.highlight to hexColor(tag.colorHex).toArgb())) {
                    ContextCompat.getDrawable(context,resource)?.mutate()?.let { drawable ->
                        DrawableCompat.setTint(drawable,color); drawable.setBounds(0,0,128,128); drawable.draw(canvas)
                    }
                }
            }
        }
        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_notification).setContentTitle(active.title).setContentText(targets)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text)).setLargeIcon(thumbnail)
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .setWhen(state.activeSession?.let { java.time.Instant.parse(it.startedAt).toEpochMilli() } ?: System.currentTimeMillis())
            .setUsesChronometer(true)
            .setColor("#${AppTheme.resolve(state.preferences.accent).hex(dark)}".toColorInt())
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .addAction(R.drawable.ic_notification, "Stop", action("stop", 1))
            .addAction(R.drawable.ic_notification, if (active.increaseLoadNextTime) "Undo Bump" else "Bump", action("bump", 2))
            .build()
        manager.notify(notificationId, notification)
    }
}

class ExerciseActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("exerciseId") ?: return
        if (intent.action !in listOf("stop", "bump")) return
        val sessionId = intent.getStringExtra("sessionId") ?: return
        val pending = goAsync()
        val app = context.applicationContext as WorkoutesApplication
        app.scope.launch {
            try {
                app.repository.load()
                app.repository.update { current ->
                    current.notificationAction(id, sessionId, stop = intent.action == "stop")
                }
                ExerciseNotification.sync(app, app.repository.state.value)
            } catch (error: Exception) { android.util.Log.e("Workoutes", "Could not save notification action", error) }
            finally { pending.finish() }
        }
    }
}
