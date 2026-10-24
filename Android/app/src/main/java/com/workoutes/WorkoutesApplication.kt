package com.workoutes

import android.app.Application
import com.workoutes.data.WorkoutRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class WorkoutesApplication : Application() {
    val repository by lazy { WorkoutRepository(this) }
    internal val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    override fun onCreate() {
        super.onCreate()
        scope.launch {
            try {
                repository.load()
                repository.state.collect {
                    ExerciseNotification.sync(this@WorkoutesApplication, it)
                    try { ThemeIconController.update(this@WorkoutesApplication, com.workoutes.data.AppTheme.resolve(it.preferences.accent)) }
                    catch (error: Exception) { android.util.Log.e("Workoutes", "Could not update theme icon", error) }
                }
            } catch (error: Exception) {
                android.util.Log.e("Workoutes", "Could not restore exercise notification", error)
            }
        }
    }
}
