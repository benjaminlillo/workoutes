package com.workoutes

import android.app.Activity
import android.app.Application
import android.os.Bundle
import com.workoutes.data.WorkoutRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class WorkoutesApplication : Application() {
    val repository by lazy { WorkoutRepository(this) }
    internal val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val themeIcon = ThemeIconScheduler { theme ->
        try { ThemeIconController.update(this, theme) }
        catch (error: Exception) { android.util.Log.e("Workoutes", "Could not update theme icon", error) }
    }
    override fun onCreate() {
        super.onCreate()
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityStarted(activity: Activity) { themeIcon.activityStarted() }
            override fun onActivityStopped(activity: Activity) { themeIcon.activityStopped(activity.isChangingConfigurations) }
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
        scope.launch {
            try {
                repository.load()
                repository.state.collect {
                    ExerciseNotification.sync(this@WorkoutesApplication, it)
                    themeIcon.request(com.workoutes.data.AppTheme.resolve(it.preferences.accent))
                }
            } catch (error: Exception) {
                android.util.Log.e("Workoutes", "Could not restore exercise notification", error)
            }
        }
    }
}
