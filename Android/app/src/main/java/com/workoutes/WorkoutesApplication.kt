package com.workoutes

import android.app.Activity
import android.app.ActivityManager
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
    private val themeIcon = ThemeIconScheduler(::externalActivityOnTop) { theme ->
        try { ThemeIconController.update(this, theme) }
        catch (error: Exception) { android.util.Log.e("Workoutes", "Could not update theme icon", error) }
    }
    // Pickers, camera and share sheets run on top of the app's task; switching the alias then would drop their result.
    private fun externalActivityOnTop() = getSystemService(ActivityManager::class.java).appTasks.any { task ->
        runCatching { task.taskInfo.topActivity?.packageName.let { it != null && it != packageName } }.getOrDefault(false)
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
