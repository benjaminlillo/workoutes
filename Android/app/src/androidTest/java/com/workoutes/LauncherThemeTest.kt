package com.workoutes

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.SystemClock
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import com.workoutes.data.AppState
import com.workoutes.data.AppTheme
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test

class LauncherThemeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val repository get() = (context.applicationContext as WorkoutesApplication).repository

    private fun launcherEntries() = context.packageManager.queryIntentActivities(
        Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setPackage(context.packageName), 0
    ).map { it.activityInfo.name }
    private fun enabled(theme: AppTheme) = context.packageManager.getComponentEnabledSetting(
        ComponentName(context, "${context.packageName}.Launcher${theme.name}")
    ) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
    private fun goHome() = instrumentation.uiAutomation.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
    private fun waitFor(condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 10_000
        while (!condition()) {
            check(SystemClock.uptimeMillis() < deadline) { "Timed out" }
            SystemClock.sleep(100)
        }
    }

    @Before fun reset() {
        runBlocking { repository.load(); repository.update { AppState() } }
        ThemeIconController.update(context, AppTheme.Indigo)
        waitFor { launcherEntries() == listOf("com.workoutes.LauncherIndigo") }
    }

    @After fun restore() {
        runBlocking { repository.update { AppState() } }
    }

    @Test fun themeChangeKeepsLauncherTaskOpen() {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)!!
        assertEquals("com.workoutes.LauncherIndigo", launch.component!!.className)
        ActivityScenario.launch<MainActivity>(launch).use { scenario ->
            runBlocking { repository.update { it.copy(preferences = it.preferences.copy(accent = AppTheme.ElectricRush.name)) } }
            SystemClock.sleep(2_000)
            assertEquals(Lifecycle.State.RESUMED, scenario.state)
            assertFalse(enabled(AppTheme.ElectricRush))
            goHome()
            waitFor { launcherEntries() == listOf("com.workoutes.LauncherElectricRush") }
        }
        val relaunch = context.packageManager.getLaunchIntentForPackage(context.packageName)!!
        assertEquals("com.workoutes.LauncherElectricRush", relaunch.component!!.className)
        ActivityScenario.launch<MainActivity>(relaunch).use { scenario ->
            assertEquals(Lifecycle.State.RESUMED, scenario.state)
            assertEquals(AppTheme.ElectricRush.name, repository.state.value.preferences.accent)
        }
    }

    @Test fun themeChangeKeepsTaskWhilePickerIsOpen() {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)!!
        ActivityScenario.launch<MainActivity>(launch).use { scenario ->
            runBlocking { repository.update { it.copy(preferences = it.preferences.copy(accent = AppTheme.ElectricRush.name)) } }
            scenario.onActivity { it.startActivity(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")) }
            waitFor { scenario.state == Lifecycle.State.CREATED }
            SystemClock.sleep(1_000)
            assertFalse(enabled(AppTheme.ElectricRush))
            instrumentation.uiAutomation.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
            waitFor { scenario.state == Lifecycle.State.RESUMED }
            goHome()
            waitFor { launcherEntries() == listOf("com.workoutes.LauncherElectricRush") }
        }
    }
}
