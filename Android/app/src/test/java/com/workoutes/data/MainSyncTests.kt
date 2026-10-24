package com.workoutes.data

import kotlinx.serialization.encodeToString
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class MainSyncTests {
    private val now = Instant.parse("2026-10-04T12:00:00Z")
    private val exercise = Exercise("bench", "Bench Press")
    private val state = AppState(ExportData(exercises = listOf(exercise)))

    @Test fun `only attempts strictly longer than ten seconds complete`() {
        val playing = state.advance(exercise.id, now)
        for (seconds in listOf(-1L, 0L, 9L, 10L)) {
            val stopped = playing.stopActive(now.plusSeconds(seconds))
            assertFalse(stopped.data.exercises.single().isDone)
            assertTrue(stopped.data.history.orEmpty().isEmpty())
            assertNull(stopped.activeSession)
        }
        val stopped = playing.stopActive(now.plusMillis(10_001))
        assertTrue(stopped.data.exercises.single().isDone)
        assertEquals(playing.activeSession!!.id, stopped.data.history!!.single().id)
        assertEquals(stopped, stopped.stopActive(now.plusSeconds(12)))
    }
    @Test fun `switching cancels even a long attempt`() {
        val second = exercise.copy(id = "squat")
        val playing = state.copy(data = state.data.copy(exercises = listOf(exercise, second))).advance(exercise.id, now)
        val switched = playing.advance(second.id, now.plusSeconds(60))
        assertEquals(second.id, switched.activeSession!!.exerciseId)
        assertTrue(switched.data.history.orEmpty().isEmpty())
        assertFalse(switched.data.exercises.first().isDone)
    }
    @Test fun `stale notification actions cannot stop or bump a newer session`() {
        val first = state.advance(exercise.id, now)
        val second = first.stopActive(now).advance(exercise.id, now.plusSeconds(1))
        assertEquals(second, second.notificationAction(exercise.id, first.activeSession!!.id, true, now.plusSeconds(30)))
        assertEquals(second, second.notificationAction(exercise.id, null, false))
        val bumped = second.notificationAction(exercise.id, second.activeSession!!.id, false)
        assertTrue(bumped.data.exercises.single().increaseLoadNextTime)
        assertEquals(1, bumped.notificationAction(exercise.id, second.activeSession.id, true, now.plusSeconds(12)).data.history!!.size)
    }
    @Test fun `sessions survive serialization and older stores migrate without inventing history`() {
        val playing = state.advance(exercise.id, now)
        val restored = workoutesJson.decodeFromString<AppState>(workoutesJson.encodeToString(playing)).restoreSession(now.plusSeconds(60))
        assertEquals(playing, restored)
        assertTrue(restored.stopActive(now.plusSeconds(60)).data.exercises.single().isDone)
        val migrated = state.copy(activeExerciseId = exercise.id).restoreSession(now)
        assertEquals(now.toString(), migrated.activeSession!!.startedAt)
        assertTrue(migrated.data.history.orEmpty().isEmpty())
        assertNull(state.copy(activeExerciseId = "missing").restoreSession(now).activeSession)
    }
    @Test fun `resetting and deleting exercises preserve completions`() {
        val completed = state.advance(exercise.id, now).stopActive(now.plusSeconds(11))
        val reset = completed.advance(exercise.id)
        assertEquals(completed.data.history, reset.data.history)
        val deleted = reset.deleteExercise(exercise.id)
        assertEquals(1, deleted.data.history!!.size)
        assertNull(deleted.data.history.single().exerciseID)
        deleted.data.validate()
    }
    @Test fun `history import is idempotent immutable and compatible with catalog only files`() {
        val completed = state.advance(exercise.id, now).stopActive(now.plusSeconds(11))
        val ios = workoutesJson.encodeToString(completed.data)
        val initial = AppState().importData(decodeImport(ios))
        val changed = completed.data.copy(exercises = listOf(exercise.copy(title = "Updated", weight = 40.0)),
            history = completed.data.history!!.map { it.copy(completedAt = now.minusSeconds(60).toString()) })
        val updated = initial.importData(changed).importData(changed.copy(history = null))
        assertEquals(1, updated.data.exercises.size)
        assertEquals("Updated", updated.data.exercises.single().title)
        assertEquals(completed.data.history, updated.data.history)
        assertFalse(workoutesJson.encodeToString(updated.data).contains("activeSession"))
    }
    @Test fun `import can link existing records but rejects invalid history and duplicate relations`() {
        val workout = Workout("workout", "Push")
        val initial = state.copy(data = state.data.copy(workouts = listOf(workout)))
        val imported = ExportData(exercises = listOf(exercise.copy(workouts = listOf(EntityRef(workout.id)))))
        assertEquals(workout.id, initial.importData(imported).data.exercises.single().workouts.single().id)
        for (bad in listOf(
            imported.copy(history = listOf(ExerciseCompletion("h", "oops", exercise.id))),
            imported.copy(history = listOf(ExerciseCompletion("h", now.toString(), "missing"))),
            imported.copy(exercises = listOf(exercise.copy(workouts = listOf(EntityRef(workout.id), EntityRef(workout.id)))))
        )) assertThrows(IllegalArgumentException::class.java) { initial.importData(bad) }
        assertEquals("Bench Press", initial.data.exercises.single().title)
    }
    @Test fun `weekly chart uses Monday boundaries local time and stable ordering`() {
        val zone = ZoneId.of("America/Santiago")
        val monday = java.time.LocalDate.parse("2026-09-28").atStartOfDay(zone).toInstant()
        val history = listOf(
            ExerciseCompletion("before", monday.minusMillis(1).toString()),
            ExerciseCompletion("b", monday.toString()), ExerciseCompletion("a", monday.toString()),
            ExerciseCompletion("sunday", monday.plusSeconds(6 * 86400L).toString()),
            ExerciseCompletion("after", monday.plusSeconds(7 * 86400L).toString()))
        val summary = WeeklySummary.containing(history, now, zone)
        assertEquals(3, summary.total); assertEquals(2, summary.activeDays)
        assertEquals(listOf("a", "b"), summary.days.first().completions.map { it.id })
        assertEquals("2026-09-28", summary.start.toString())
    }
    @Test fun `DST transition and zone changes do not lose or duplicate records`() {
        val zone = ZoneId.of("America/Santiago")
        val date = java.time.LocalDate.parse("2026-09-06")
        val completion = ExerciseCompletion("dst", date.atStartOfDay(zone).toInstant().toString())
        val summary = WeeklySummary.containing(listOf(completion), Instant.parse(completion.completedAt), zone)
        assertEquals(1, summary.days.last().completions.size)
        assertEquals(1, summary.total)
        val boundary = ExerciseCompletion("zone", "2026-10-05T01:00:00Z")
        assertEquals(0, WeeklySummary.containing(listOf(boundary), now, ZoneId.of("UTC")).total)
        assertEquals(1, WeeklySummary.containing(listOf(boundary), now, zone).total)
    }
    @Test fun `retired themes migrate and all current palettes contain three colors`() {
        listOf("Primary", "Mint", "Purple", "Orange", "Blue", "Green", "Red", "unknown", null).forEach { assertEquals(AppTheme.Indigo, AppTheme.resolve(it)) }
        assertEquals(7, AppTheme.entries.size)
        AppTheme.entries.forEach {
            assertEquals(it, AppTheme.resolve(it.name)); assertEquals(3, it.gradient(false).size)
            assertEquals(it.secondaryHex, it.hex(true)); assertEquals(it.hex, it.hex(false))
        }
    }
}
