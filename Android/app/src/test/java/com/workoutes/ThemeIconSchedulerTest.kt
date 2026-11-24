package com.workoutes

import com.workoutes.data.AppTheme
import org.junit.Assert.assertEquals
import org.junit.Test

class ThemeIconSchedulerTest {
    private val applied = mutableListOf<AppTheme>()
    private val scheduler = ThemeIconScheduler { applied += it }

    @Test fun appliesImmediatelyInBackground() {
        scheduler.request(AppTheme.ElectricRush)
        assertEquals(listOf(AppTheme.ElectricRush), applied)
    }

    @Test fun defersWhileVisibleAndAppliesLatestWhenBackgrounded() {
        scheduler.activityStarted()
        scheduler.request(AppTheme.ElectricRush)
        scheduler.request(AppTheme.SunsetPop)
        assertEquals(emptyList<AppTheme>(), applied)
        scheduler.activityStopped(changingConfigurations = false)
        assertEquals(listOf(AppTheme.SunsetPop), applied)
    }

    @Test fun waitsForEveryActivityAndIgnoresConfigurationChanges() {
        scheduler.activityStarted()
        scheduler.request(AppTheme.CherryIce)
        scheduler.activityStopped(changingConfigurations = true)
        assertEquals(emptyList<AppTheme>(), applied)
        scheduler.activityStarted()
        scheduler.activityStarted()
        scheduler.activityStopped(changingConfigurations = false)
        assertEquals(emptyList<AppTheme>(), applied)
        scheduler.activityStopped(changingConfigurations = false)
        assertEquals(listOf(AppTheme.CherryIce), applied)
    }
}
