package com.workoutes

import android.Manifest
import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import com.workoutes.data.*
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.Assert.*
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.LocalDate
import kotlinx.serialization.encodeToString

class WorkoutesFlowTest {
    @get:Rule val permission: GrantPermissionRule = if (android.os.Build.VERSION.SDK_INT >= 33)
        GrantPermissionRule.grant(Manifest.permission.POST_NOTIFICATIONS) else GrantPermissionRule.grant()
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private val repository get() = (compose.activity.application as WorkoutesApplication).repository
    @Before fun clear() {
        runBlocking { repository.load(); repository.update { AppState() } }
        compose.onNodeWithContentDescription("Workouts").performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithContentDescription("Add Workout").fetchSemanticsNodes().isNotEmpty() }
    }
    private fun ageActive() { runBlocking { repository.update { current -> current.copy(activeSession = current.activeSession!!.copy(startedAt = Instant.now().minusSeconds(11).toString())) } } }
    private fun waitForText(text: String) { compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() } }
    private fun screenshot(name: String) {
        compose.waitForIdle()
        InstrumentationRegistry.getInstrumentation().uiAutomation.waitForIdle(500, 5_000)
        val bitmap = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        File(compose.activity.filesDir, "evidence").mkdirs()
        File(compose.activity.filesDir, "evidence/$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
    @Test fun createWorkoutExerciseAndAdjustWeight() {
        compose.onNodeWithContentDescription("Add Workout").performClick()
        compose.onNodeWithText("Name").performTextInput("Push Day")
        compose.onNodeWithText("Create Workout").performClick()
        waitForText("Push Day")
        screenshot("workouts")
        compose.onNodeWithText("Push Day").performClick()
        compose.onNodeWithContentDescription("Add Exercise").performClick()
        compose.onNodeWithText("Title").performTextInput("Bench Press")
        compose.onNodeWithText("Subtitle (Optional)").performTextInput("Barbell")
        compose.onNodeWithText("Weight (kg)").performScrollTo().performTextReplacement("60")
        compose.activityRule.scenario.onActivity { activity ->
            activity.getSystemService(android.view.inputmethod.InputMethodManager::class.java).hideSoftInputFromWindow(activity.window.decorView.windowToken, 0)
        }
        compose.onNodeWithText("Create and Add").performScrollTo().performClick()
        waitForText("60 kg")
        compose.onNodeWithText("60 kg").performClick()
        compose.onNodeWithText("Weight (kg)").performTextReplacement("65.5")
        compose.onNodeWithText("Done").performClick()
        waitForText("65.5 kg")
        compose.onNodeWithContentDescription("Start Bench Press").performClick()
        compose.waitUntil(10_000) { repository.state.value.activeExerciseId != null }
        compose.waitUntil(10_000) { compose.onAllNodesWithContentDescription("Stop Bench Press").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription("Complete Exercise").assertDoesNotExist()
        screenshot("workout-active")
        ageActive()
        compose.onNodeWithContentDescription("Stop Bench Press").performClick()
        compose.waitUntil(10_000) { repository.state.value.data.exercises.single().isDone }
        compose.onNodeWithContentDescription("Reset Completed Exercises").performClick()
        compose.waitUntil(10_000) { !repository.state.value.data.exercises.single().isDone }
        compose.onNodeWithContentDescription("Start Bench Press").performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithContentDescription("Stop Bench Press").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription("Stop Bench Press").performClick()
        compose.waitUntil(10_000) { repository.state.value.activeExerciseId == null }
        assertFalse(repository.state.value.data.exercises.single().isDone)
        assertEquals(65.5, repository.state.value.data.exercises.single().weight, 0.0)
        runBlocking { repository.load() }
        assertEquals("Push Day", repository.state.value.data.workouts.single().name)
        compose.onNodeWithContentDescription("Exercises").performClick()
        waitForText("All Exercises")
        compose.onNodeWithContentDescription("Back").assertDoesNotExist()
        compose.onNodeWithContentDescription("Add Exercise").performClick()
        compose.onNodeWithText("New Exercise").assertExists()
        compose.onNodeWithText("Cancel").performClick()
        compose.onNodeWithContentDescription("Workouts").performClick()
        compose.onNodeWithContentDescription("Back").assertExists()
        compose.onNodeWithContentDescription("Add Exercise").performClick()
        compose.onNodeWithText("Title").performTextInput("Incline Press")
        compose.activityRule.scenario.recreate()
        compose.onNodeWithText("Incline Press").assertExists()
        compose.onNodeWithText("Cancel").performClick()
    }
    @Test fun filtersPreferencesAndNotificationActions() {
        val push = Tag("push", "Push", "007AFF")
        val legs = Tag("legs", "Legs", "AF52DE")
        val bench = Exercise("bench", "Bench Press", subtitle = "Barbell", details = "Control the descent", weight = 60.0, tags = listOf(EntityRef(push.id)))
        val squat = Exercise("squat", "Squat", weight = 80.0, tags = listOf(EntityRef(legs.id)))
        runBlocking { repository.update { AppState(data = ExportData(exercises = listOf(bench, squat), tags = listOf(push, legs))) } }
        compose.onNodeWithContentDescription("Exercises").performClick()
        waitForText("Bench Press")
        screenshot("exercises")
        compose.onNodeWithContentDescription("Manage Tags").performClick()
        compose.onNodeWithText("Push").performClick()
        compose.onNodeWithText("Squat").assertDoesNotExist()
        compose.onNodeWithContentDescription("Start Bench Press").performClick()
        compose.waitUntil(10_000) { repository.state.value.activeExerciseId == bench.id }
        val session = repository.state.value.activeSession!!.id
        compose.activity.sendBroadcast(Intent(compose.activity, ExerciseActionReceiver::class.java).setAction("bump").putExtra("exerciseId", bench.id).putExtra("sessionId", session))
        compose.waitUntil(10_000) { repository.state.value.data.exercises.first().increaseLoadNextTime }
        ageActive()
        compose.activity.sendBroadcast(Intent(compose.activity, ExerciseActionReceiver::class.java).setAction("stop").putExtra("exerciseId", bench.id).putExtra("sessionId", session))
        compose.waitUntil(10_000) { repository.state.value.data.exercises.first().isDone }
        assertNull(repository.state.value.activeExerciseId)
        compose.onNodeWithContentDescription("Settings").performClick()
        compose.onNodeWithText("Weight Unit").performClick()
        compose.onNodeWithText("Imperial (lb)").performClick()
        compose.waitUntil(10_000) { repository.state.value.preferences.unit == WeightUnit.Imperial }
        screenshot("weight-unit-submenu")
        compose.onNodeWithContentDescription("Back").performClick()
        compose.onNodeWithText("Theme").performClick()
        compose.onNodeWithTag("themeCarousel").performScrollToIndex(AppTheme.CherryIce.ordinal)
        compose.onNodeWithTag("themeOption.CherryIce").performClick()
        compose.waitUntil(10_000) { repository.state.value.preferences.accent == "CherryIce" }
        compose.onNodeWithTag("themeOption.CherryIce").assertIsSelected()
        screenshot("theme-submenu")
        compose.onNodeWithContentDescription("Back").performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithText("Cancel").fetchSemanticsNodes().isEmpty() }
        screenshot("settings")
        compose.onNodeWithContentDescription("Exercises").performClick()
        waitForText("132.28 lb")
        screenshot("exercises-imperial")
        val restored = WorkoutRepository(compose.activity)
        runBlocking { restored.load() }
        assertEquals(WeightUnit.Imperial, restored.state.value.preferences.unit)
        assertEquals(60.0, restored.state.value.data.exercises.first().weight, 0.0)
        assertTrue(restored.state.value.data.exercises.first().isDone)
    }
    @Test fun navigationKeepsTabGeometryAndAnimatesWorkoutEntry() {
        val workout = Workout("upper", "Upper Body")
        val bench = Exercise("bench", "Bench Press", weight = 60.0, workouts = listOf(EntityRef(workout.id)))
        runBlocking { repository.update { AppState(ExportData(workouts = listOf(workout), exercises = listOf(bench))) } }
        waitForText("Upper Body")
        val exercisesTab = compose.onNodeWithContentDescription("Exercises")
        val before = exercisesTab.fetchSemanticsNode().boundsInRoot
        exercisesTab.performClick()
        exercisesTab.assertIsSelected()
        assertEquals(before, exercisesTab.fetchSemanticsNode().boundsInRoot)
        compose.onNodeWithContentDescription("Workouts").performClick()
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false
        try {
            compose.onNodeWithText("Upper Body").performClick()
            compose.mainClock.advanceTimeBy(128)
            val enteringLeft = compose.onNodeWithText("Bench Press").fetchSemanticsNode().boundsInRoot.left
            compose.mainClock.advanceTimeBy(400)
            val settledLeft = compose.onNodeWithText("Bench Press").fetchSemanticsNode().boundsInRoot.left
            assertTrue("The workout enters from the right", enteringLeft > settledLeft)
            compose.onNodeWithContentDescription("Back").performClick()
            compose.mainClock.advanceTimeBy(128)
            val exitingLeft = compose.onNodeWithText("Bench Press").fetchSemanticsNode().boundsInRoot.left
            assertTrue("The workout leaves to the right", exitingLeft > settledLeft)
            compose.mainClock.advanceTimeBy(400)
            compose.onNodeWithText("Bench Press").assertDoesNotExist()
        } finally {
            compose.mainClock.autoAdvance = true
        }
    }
    @Test fun backgroundSelectionAndSafeRemoval() {
        val workout = Workout("upper", "Upper Body")
        val bench = Exercise("bench", "Bench Press", weight = 60.0, workouts = listOf(EntityRef(workout.id)))
        runBlocking { repository.update { AppState(ExportData(workouts = listOf(workout), exercises = listOf(bench))) } }
        waitForText("Upper Body")
        compose.onNodeWithText("Upper Body").performClick()
        compose.onNodeWithContentDescription("Customize Background").performClick()
        compose.onNodeWithText("Automatic").performClick()
        compose.waitUntil(10_000) { repository.state.value.backgrounds[workout.id]?.mode == BackgroundMode.Automatic }
        compose.onNodeWithText("Done").performClick()
        compose.onNodeWithContentDescription("Exercise Actions").assertDoesNotExist()
        compose.onNodeWithText("Bench Press").performTouchInput { longClick() }
        screenshot("exercise-menu")
        compose.onNodeWithText("Remove from Workout").performClick()
        waitForText("No exercises yet")
        assertEquals(1, repository.state.value.data.exercises.size)
        assertTrue(repository.state.value.data.exercises.single().workouts.isEmpty())
    }
    @Test fun summaryHistorySessionRestorationAndExport() {
        val bench = Exercise("bench", "Bench Press", weight = 60.0, tags = listOf(EntityRef("chest"), EntityRef("strength")))
        val tags = listOf(Tag("chest", "Chest", "FF8800"), Tag("strength", "Strength", "5599FF"))
        val monday = LocalDate.now().minusDays((LocalDate.now().dayOfWeek.value - 1).toLong()).atStartOfDay(ZoneId.systemDefault()).toInstant()
        val records = (0..4).map { ExerciseCompletion("record$it", monday.plusSeconds((it % 3) * 86400L + 3600).toString(), if (it == 4) null else bench.id) }
        runBlocking { repository.update { AppState(ExportData(exercises = listOf(bench), tags = tags, history = records)) } }
        compose.onNodeWithContentDescription("Summary").performClick()
        compose.onNodeWithTag("weeklyExerciseChart").assertExists()
        screenshot("summary-populated")
        compose.onNodeWithContentDescription("Exercises").performClick()
        compose.onNodeWithContentDescription("Start Bench Press").performClick()
        compose.waitUntil(10_000) { repository.state.value.activeSession != null }
        ageActive()
        val restored = WorkoutRepository(compose.activity)
        runBlocking { restored.load() }
        assertEquals(repository.state.value.activeSession, restored.state.value.activeSession)
        compose.activityRule.scenario.recreate()
        compose.onNodeWithContentDescription("Stop Bench Press").assertExists()
        compose.onNodeWithContentDescription("Stop Bench Press").performClick()
        compose.waitUntil(10_000) { repository.state.value.data.history!!.size == 6 }
        compose.onNodeWithContentDescription("Summary").performClick()
        screenshot("summary-completed")
        val export = runBlocking { repository.exportFile(true) }
        val payload = compose.activity.contentResolver.openInputStream(export)!!.bufferedReader().use { it.readText() }
        assertEquals(6, decodeImport(payload).history!!.size)
        assertFalse(payload.contains("activeSession"))
        runBlocking { repository.importFile(export); repository.importFile(export) }
        assertEquals(1, repository.state.value.data.exercises.size)
        assertEquals(6, repository.state.value.data.history!!.size)
        val catalog = runBlocking { repository.exportFile(false) }
        assertNull(decodeImport(compose.activity.contentResolver.openInputStream(catalog)!!.bufferedReader().use { it.readText() }).history)
        compose.onNodeWithContentDescription("Settings").performClick()
        compose.onNodeWithText("Export Data (JSON)").performClick()
        compose.onNodeWithText("Include exercise history?").assertExists()
        compose.onNodeWithText("Cancel").performClick()
    }
    @Test fun motivationalPullAndLauncherThemes() {
        compose.onNodeWithContentDescription("Summary").performClick()
        screenshot("summary-empty")
        compose.mainClock.autoAdvance = false
        try {
            compose.onNodeWithTag("summaryScroll").performTouchInput { swipeDown(startY = 40f, endY = height * .9f, durationMillis = 800) }
            compose.mainClock.advanceTimeBy(32)
            compose.onNodeWithTag("motivationalCelebration").assertExists()
            val header = compose.onNodeWithTag("screenHeader").fetchSemanticsNode().boundsInRoot
            val viewport = compose.onNodeWithTag("summaryViewport").fetchSemanticsNode().boundsInRoot
            val banner = compose.onNodeWithTag("motivationalPullBanner").fetchSemanticsNode().boundsInRoot
            val phrase = compose.onNodeWithTag("motivationalPullPhrase").fetchSemanticsNode().boundsInRoot
            val emoji = compose.onNodeWithTag("motivationalPullEmoji").fetchSemanticsNode().boundsInRoot
            val chart = compose.onNodeWithTag("weeklyExerciseChart").fetchSemanticsNode().boundsInRoot
            val celebration = compose.onNodeWithTag("motivationalCelebration").fetchSemanticsNode().boundsInRoot
            assertEquals("Summary content starts below the header", header.bottom, viewport.top, 1f)
            assertTrue("Pull banner stays below the header", banner.top >= header.bottom)
            assertTrue("Emoji stays inside the banner", emoji.top >= banner.top && emoji.bottom <= banner.bottom)
            assertTrue("Phrase stays inside the banner", phrase.top >= banner.top && phrase.bottom <= banner.bottom)
            assertTrue("Pull reserves space before the chart", chart.top >= banner.bottom)
            assertTrue("Celebration is contained in Summary", celebration.top >= header.bottom && celebration.bottom <= viewport.bottom)
            screenshot("motivational-pull")
            compose.mainClock.advanceTimeBy(650)
            screenshot("motivational-burst")
            compose.mainClock.advanceTimeBy(3_000)
            compose.onNodeWithTag("motivationalPullBanner").assertDoesNotExist()
            compose.onNodeWithTag("motivationalCelebration").assertDoesNotExist()
        } finally { compose.mainClock.autoAdvance = true }
        compose.onNodeWithContentDescription("Settings").performClick()
        compose.onNodeWithText("Theme").performClick()
        compose.onNodeWithTag("themeCarousel").performScrollToIndex(AppTheme.ElectricRush.ordinal)
        compose.onNodeWithTag("themeOption.ElectricRush").performClick()
        compose.waitUntil(10_000) { repository.state.value.preferences.accent == "ElectricRush" }
        compose.waitUntil(10_000) {
            compose.activity.packageManager.getComponentEnabledSetting(android.content.ComponentName(compose.activity, "com.workoutes.LauncherElectricRush")) == android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        }
        screenshot("theme-frozen-water")
        val entries = compose.activity.packageManager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setPackage("com.workoutes"), 0)
        assertEquals(listOf("com.workoutes.LauncherElectricRush"), entries.map { it.activityInfo.name })
    }
    @Test fun historicalPreviewsWeekNavigationAndDeletion() {
        val original = ExerciseSnapshot("Original Bench", "Barbell", "Historical notes", 4, 8, 60.0, true,
            listOf(CompletionTag("Chest", "FF8800", "chest")))
        val now = Instant.now()
        val monday = WeeklySummary.containing(emptyList(),now).start
        val zone = ZoneId.systemDefault()
        val recent = ExerciseCompletion("recent", now.toString(), "bench", original)
        val previous = ExerciseCompletion("previous", monday.minusWeeks(1).atStartOfDay(zone).toInstant().toString(), "bench", original)
        val legacy = ExerciseCompletion("legacy", monday.atStartOfDay(zone).toInstant().toString(), "bench")
        runBlocking { repository.update { AppState(ExportData(exercises=listOf(Exercise("bench","Edited Bench",weight=999.0)),history=listOf(recent,previous,legacy))) } }
        compose.onNodeWithContentDescription("Summary").performClick()
        compose.onNodeWithContentDescription("Next Week").assertIsNotEnabled()
        compose.onNodeWithTag("weeklyExerciseBlock.recent").performClick()
        compose.onNodeWithText("Original Bench").assertExists()
        compose.onNodeWithText("60 kg").assertExists()
        compose.onNodeWithContentDescription("Start Original Bench").assertDoesNotExist()
        screenshot("historical-preview")
        compose.onNodeWithText("Done").performClick()
        compose.onNodeWithTag("weeklyExerciseBlock.legacy").performClick()
        compose.onNodeWithText("No Historical Snapshot").assertExists()
        compose.onNodeWithText("Done").performClick()
        compose.onNodeWithContentDescription("Previous Week").performClick()
        compose.onNodeWithTag("weeklyExerciseBlock.previous").assertExists()
        screenshot("previous-week")
        compose.onNodeWithContentDescription("Next Week").performClick()
        compose.onNodeWithContentDescription("Next Week").assertIsNotEnabled()
        compose.onNodeWithContentDescription("Settings").performClick()
        compose.onNodeWithText("Exercise History").performClick()
        compose.onNodeWithTag("historyEntry.recent").assertExists()
        screenshot("exercise-history")
        compose.onNodeWithContentDescription("Delete history entry recent").performClick()
        compose.onNodeWithText("Delete",useUnmergedTree=true).performClick()
        compose.waitUntil(10_000) { repository.state.value.data.history!!.size == 2 }
        assertEquals(999.0,repository.state.value.data.exercises.single().weight,0.0)
        compose.onNodeWithText("Edit").performClick()
        compose.onNodeWithTag("selectHistory.previous").performClick()
        compose.onNodeWithTag("selectHistory.legacy").performClick()
        compose.onNodeWithText("Delete Selected (2)").performClick()
        compose.onNodeWithText("Delete",useUnmergedTree=true).performClick()
        compose.waitUntil(10_000) { repository.state.value.data.history!!.isEmpty() }
        compose.onNodeWithText("No Exercise History").assertExists()
        screenshot("history-empty-after-delete")
        compose.onNodeWithContentDescription("Back").performClick()
        compose.onNodeWithContentDescription("Summary").performClick()
        compose.onNodeWithTag("weeklyExerciseBlock.recent").assertDoesNotExist()
    }
    @Test fun muscleIconsTagMenusAndPersistentDocking() {
        val chest = Tag("chest","Chest","FF8800","chest")
        val legs = Tag("legs","Legs","55AA88","quadriceps")
        val bench = Exercise("bench","Bench Press",tags=listOf(EntityRef(chest.id)))
        val squat = Exercise("squat","Squat",tags=listOf(EntityRef(legs.id)))
        runBlocking { repository.update { AppState(ExportData(exercises=listOf(bench,squat),tags=listOf(chest,legs))) } }
        compose.onNodeWithContentDescription("Exercises").performClick()
        compose.onNodeWithContentDescription("Manage Tags").performClick()
        compose.onNodeWithText("Chest").performClick()
        compose.onNodeWithText("Squat").assertDoesNotExist()
        screenshot("tag-wheel-filter")
        compose.onNodeWithContentDescription("Manage Tags").performClick()
        compose.onNodeWithText("Edit Tag").performClick()
        compose.onNodeWithText("Chest").performClick()
        compose.onNodeWithText("Muscle Icon: Chest").performScrollTo().performClick()
        compose.onNodeWithContentDescription("Muscle: Shoulders").performScrollTo().performClick()
        compose.onNodeWithText("Save").performScrollTo().performClick()
        compose.waitUntil(10_000) { repository.state.value.data.tags.first().iconName == "shoulders" }
        val actions = compose.onNodeWithTag("tag-wheel").fetchSemanticsNode().config[androidx.compose.ui.semantics.SemanticsActions.CustomActions]
        compose.runOnIdle { actions.first { it.label == "Move Wheel to Left Edge" }.action() }
        compose.waitUntil(10_000) { repository.state.value.wheelDock?.edge == "leading" }
        compose.activityRule.scenario.recreate()
        assertEquals("leading",repository.state.value.wheelDock!!.edge)
        screenshot("tag-wheel-docked-left")
        compose.onNodeWithContentDescription("Manage Tags").performClick()
        compose.onNodeWithText("Deselect All Tags").performClick()
        compose.onNodeWithText("Squat").assertExists()
        compose.onNodeWithContentDescription("Start Bench Press").performClick()
        val manager=compose.activity.getSystemService(android.app.NotificationManager::class.java)
        compose.waitUntil(10_000) { manager.activeNotifications.any { it.id==1 } }
        val notification=manager.activeNotifications.first { it.id==1 }.notification
        assertNotNull(notification.getLargeIcon())
        assertTrue(notification.extras.getCharSequence(android.app.Notification.EXTRA_BIG_TEXT).toString().contains("Chest"))
    }
    @Test fun persistentActiveShortcutRevealsAndUnfiltersExercise() {
        val push=Tag("push","Push","FF8800","chest")
        val legs=Tag("legs","Legs","55AA88","quadriceps")
        val exercises=(0..24).map { Exercise("ex$it","Exercise %02d".format(it),tags=listOf(EntityRef(legs.id))) } + Exercise("active","Z Active Press",tags=listOf(EntityRef(push.id)))
        runBlocking { repository.update { AppState(ExportData(exercises=exercises,tags=listOf(push,legs))) } }
        compose.onNodeWithTag("activeExerciseShortcut").assertIsNotEnabled()
        runBlocking { repository.update { it.advance("active") } }
        compose.onNodeWithContentDescription("Exercises").performClick()
        compose.onNodeWithContentDescription("Manage Tags").performClick()
        compose.onNodeWithText("Legs").performClick()
        compose.onNodeWithContentDescription("Reveal Z Active Press").performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("exerciseCard.active").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("exerciseCard.active").assertIsDisplayed()
        compose.onNodeWithContentDescription("Stop Z Active Press").assertExists()
        screenshot("active-exercise-shortcut")
        compose.onNodeWithContentDescription("Reveal Z Active Press").performClick()
        ageActive()
        compose.onNodeWithContentDescription("Stop Z Active Press").performClick()
        compose.waitUntil(10_000) { repository.state.value.activeSession == null }
        compose.onNodeWithTag("activeExerciseShortcut").assertIsNotEnabled()
    }

    @Test fun wheelRotationAndHubDragging() {
        val tags=listOf("Chest","Back","Legs","Arms").mapIndexed { i,name -> Tag("tag$i",name,"FF8800",listOf("chest","back","quadriceps","arms")[i]) }
        val exercises=tags.mapIndexed { i,tag -> Exercise("ex$i","Exercise $i",tags=listOf(EntityRef(tag.id))) }
        runBlocking { repository.update { AppState(ExportData(exercises=exercises,tags=tags)) } }
        compose.onNodeWithContentDescription("Exercises").performClick()
        val wheel = compose.onNodeWithTag("tag-wheel").fetchSemanticsNode()
        val wheelCenter = wheel.positionInRoot + androidx.compose.ui.geometry.Offset(wheel.size.width/2f,wheel.size.height/2f)
        val radius = wheel.size.width * .40f
        compose.onRoot().performTouchInput {
            fun point(degrees: Double): androidx.compose.ui.geometry.Offset {
                val angle = degrees*Math.PI/180
                return wheelCenter + androidx.compose.ui.geometry.Offset((kotlin.math.cos(angle)*radius).toFloat(),(kotlin.math.sin(angle)*radius).toFloat())
            }
            down(point(-160.0))
            for (degrees in -150..-80 step 10) moveTo(point(degrees.toDouble()),delayMillis=60)
            up()
        }
        compose.waitForIdle()
        compose.onNodeWithTag("tag-wheel").assert(androidx.compose.ui.test.SemanticsMatcher("A rotation selects a tag") {
            it.config[androidx.compose.ui.semantics.SemanticsProperties.StateDescription] != "No Tag Selected"
        })
        val hub = compose.onNodeWithTag("tag-wheel-hub").fetchSemanticsNode().boundsInRoot.center
        compose.onNodeWithTag("tag-wheel-hub").performTouchInput {
            down(center)
            for (step in 1..8) moveTo(androidx.compose.ui.geometry.Offset(center.x+(60f-hub.x)*step/8,center.y),delayMillis=60)
            up()
        }
        compose.waitUntil(10_000) { repository.state.value.wheelDock != null }
        assertEquals("leading", repository.state.value.wheelDock!!.edge)
        screenshot("wheel-rotated-and-dragged")
    }

    @Test fun allMuscleMasksRenderInTheAndroidFramework() {
        for (symbol in com.workoutes.ui.muscleSymbols) for (resource in listOf(symbol.base,symbol.highlight)) {
            val bitmap=Bitmap.createBitmap(64,64,Bitmap.Config.ARGB_8888)
            val drawable=androidx.core.content.ContextCompat.getDrawable(compose.activity,resource)!!
            drawable.setBounds(0,0,64,64);drawable.draw(android.graphics.Canvas(bitmap))
            val pixels=IntArray(64*64);bitmap.getPixels(pixels,0,64,0,0,64,64)
            assertTrue("${symbol.name} must draw a nonempty mask",pixels.any { it ushr 24 != 0 })
            bitmap.recycle()
        }
    }

}
