package com.workoutes

import com.workoutes.data.AppTheme

// Switching the launcher alias closes any task launched from the old alias, so it only happens once the user has left that task.
internal class ThemeIconScheduler(
    private val externalActivityOnTop: () -> Boolean = { false },
    private val apply: (AppTheme) -> Unit,
) {
    private var startedActivities = 0
    private var recreatingActivities = 0
    private var pending: AppTheme? = null

    @Synchronized fun request(theme: AppTheme) {
        pending = theme
        flush()
    }

    @Synchronized fun activityStarted() {
        if (recreatingActivities > 0) recreatingActivities-- else startedActivities++
    }

    @Synchronized fun activityStopped(changingConfigurations: Boolean) {
        if (changingConfigurations) { recreatingActivities++; return }
        startedActivities = maxOf(0, startedActivities - 1)
        flush()
    }

    private fun flush() {
        if (startedActivities > 0 || externalActivityOnTop()) return
        val theme = pending ?: return
        pending = null
        apply(theme)
    }
}
