package com.workoutes

import com.workoutes.data.AppTheme

// Switching the launcher alias closes any task launched from the old alias, so it only happens while no activity is visible.
internal class ThemeIconScheduler(private val apply: (AppTheme) -> Unit) {
    private var startedActivities = 0
    private var pending: AppTheme? = null

    fun request(theme: AppTheme) {
        synchronized(this) { pending = theme }
        flush()
    }

    fun activityStarted() = synchronized(this) { startedActivities++ }

    fun activityStopped(changingConfigurations: Boolean) {
        synchronized(this) { startedActivities = maxOf(0, startedActivities - 1) }
        if (!changingConfigurations) flush()
    }

    private fun flush() {
        val theme = synchronized(this) {
            if (startedActivities > 0) return
            pending.also { pending = null }
        } ?: return
        apply(theme)
    }
}
