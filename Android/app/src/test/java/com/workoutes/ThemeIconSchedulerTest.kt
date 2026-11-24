package com.workoutes

import com.workoutes.data.AppTheme
import org.junit.Assert.assertEquals
import org.junit.Test

class ThemeIconSchedulerTest {
    private val applied = mutableListOf<AppTheme>()
    private var externalOnTop = false
    private val scheduler = ThemeIconScheduler({ externalOnTop }) { applied += it }

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

    @Test fun waitsForEveryActivity() {
        scheduler.activityStarted()
        scheduler.activityStarted()
        scheduler.request(AppTheme.CherryIce)
        scheduler.activityStopped(changingConfigurations = false)
        assertEquals(emptyList<AppTheme>(), applied)
        scheduler.activityStopped(changingConfigurations = false)
        assertEquals(listOf(AppTheme.CherryIce), applied)
    }

    @Test fun requestDuringRecreationWaitsForReplacementActivity() {
        scheduler.activityStarted()
        scheduler.activityStopped(changingConfigurations = true)
        scheduler.request(AppTheme.CherryIce)
        assertEquals(emptyList<AppTheme>(), applied)
        scheduler.activityStarted()
        assertEquals(emptyList<AppTheme>(), applied)
        scheduler.activityStopped(changingConfigurations = false)
        assertEquals(listOf(AppTheme.CherryIce), applied)
    }

    @Test fun waitsWhileExternalActivityCoversTask() {
        scheduler.activityStarted()
        scheduler.request(AppTheme.Ultravolt)
        externalOnTop = true
        scheduler.activityStopped(changingConfigurations = false)
        assertEquals(emptyList<AppTheme>(), applied)
        externalOnTop = false
        scheduler.activityStarted()
        scheduler.activityStopped(changingConfigurations = false)
        assertEquals(listOf(AppTheme.Ultravolt), applied)
    }
}
