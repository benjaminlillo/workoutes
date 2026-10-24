package com.workoutes.data

import kotlinx.serialization.encodeToString
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant

class ParityTests {
    private val workout = Workout("workout", "Upper Body")
    private val tag = Tag("tag", "Push", "007AFF")
    private val exercise = Exercise("exercise", "Bench Press", weight = 60.0,
        workouts = listOf(EntityRef(workout.id)), tags = listOf(EntityRef(tag.id)))
    private val data = ExportData(listOf(workout), listOf(exercise), listOf(tag))

    @Test fun `unit changes never change stored kilograms`() {
        assertEquals(132.277357, WeightUnit.Imperial.display(60.0), 0.00001)
        assertEquals(60.0, WeightUnit.Imperial.kilograms(WeightUnit.Imperial.display(60.0)), 0.0000001)
        assertEquals(60.0, WeightUnit.Metric.display(60.0), 0.0)
    }
    @Test fun `exercise cycles through active completed and not started`() {
        val initial = AppState(data)
        val now = Instant.parse("2026-10-04T12:00:00Z")
        val playing = initial.advance(exercise.id, now)
        assertEquals(exercise.id, playing.activeExerciseId)
        assertFalse(playing.data.exercises.single().isDone)
        val completed = playing.advance(exercise.id, now.plusSeconds(11))
        assertNull(completed.activeExerciseId)
        assertTrue(completed.data.exercises.single().isDone)
        val reset = completed.advance(exercise.id)
        assertNull(reset.activeExerciseId)
        assertFalse(reset.data.exercises.single().isDone)
    }
    @Test fun `switching active exercises does not complete the previous exercise`() {
        val second = exercise.copy(id = "second")
        val state = AppState(data.copy(exercises = listOf(exercise, second))).advance(exercise.id).advance(second.id)
        assertEquals(second.id, state.activeExerciseId)
        assertTrue(state.data.exercises.none { it.isDone })
    }
    @Test fun `deleting a workout or tag keeps shared exercises`() {
        val withoutWorkout = AppState(data).deleteWorkout(workout.id)
        assertTrue(withoutWorkout.data.workouts.isEmpty())
        assertEquals(exercise.id, withoutWorkout.data.exercises.single().id)
        assertTrue(withoutWorkout.data.exercises.single().workouts.isEmpty())
        val withoutTag = AppState(data).deleteTag(tag.id)
        assertTrue(withoutTag.data.tags.isEmpty())
        assertTrue(withoutTag.data.exercises.single().tags.isEmpty())
        withoutWorkout.data.validate(); withoutTag.data.validate()
    }
    @Test fun `deleting the active exercise clears the active bar`() {
        val deleted = AppState(data).advance(exercise.id).deleteExercise(exercise.id)
        assertNull(deleted.activeExerciseId)
        assertTrue(deleted.data.exercises.isEmpty())
    }
    @Test fun `iOS relational JSON can be imported and exported without losing data`() {
        val ios = """{
          "workouts":[{"id":"workout","name":"Upper Body"}],
          "tags":[{"id":"tag","name":"Push","colorHex":"007AFF"}],
          "exercises":[{"id":"exercise","title":"Bench Press","subtitle":"Barbell","details":"Control descent",
          "numberOfSets":3,"reps":10,"increaseLoadNextTime":true,"isDone":false,"weight":60.0,
          "workouts":[{"id":"workout"}],"tags":[{"id":"tag"}]}]
        }"""
        val decoded = decodeImport(ios)
        decoded.validate()
        val imported = AppState().importData(decoded).data
        assertEquals("Barbell", imported.exercises.single().subtitle)
        assertTrue(imported.exercises.single().increaseLoadNextTime)
        assertEquals(imported.workouts.single().id, imported.exercises.single().workouts.single().id)
        assertEquals(imported.tags.single().id, imported.exercises.single().tags.single().id)
        assertEquals(imported, workoutesJson.decodeFromString<ExportData>(workoutesJson.encodeToString(imported)))
    }
    @Test fun `repeated imports update by stable ID without duplicating relationships`() {
        val imported = AppState().importData(data).importData(data).data
        assertEquals(1, imported.exercises.size)
        assertEquals(1, imported.workouts.size)
        assertEquals(exercise.workouts, imported.exercises.single().workouts)
        imported.validate()
    }
    @Test fun `broken references and invalid targets reject the whole import`() {
        listOf(data.copy(exercises = listOf(exercise.copy(workouts = listOf(EntityRef("missing"))))),
            data.copy(exercises = listOf(exercise.copy(weight = -1.0))),
            data.copy(exercises = listOf(exercise.copy(weight = Double.NaN))),
            data.copy(tags = listOf(tag.copy(colorHex = "oops"))),
            data.copy(workouts = listOf(workout, workout))).forEach { invalid ->
            assertThrows(IllegalArgumentException::class.java) { AppState(data).importData(invalid) }
        }
    }
    @Test fun `background and preference state survives serialization`() {
        val state = AppState(data, Preferences("Purple", WeightUnit.Imperial),
            mapOf("exercises" to Background(BackgroundMode.Automatic)), exercise.id)
        assertEquals(state, workoutesJson.decodeFromString<AppState>(workoutesJson.encodeToString(state)))
    }
    @Test fun `workout auto population uses any selected tag without duplicate exercises`() {
        val secondTag = tag.copy(id = "second-tag", name = "Chest")
        val initial = AppState(data.copy(tags = listOf(tag, secondTag), exercises = listOf(
            exercise.copy(tags = listOf(EntityRef(tag.id), EntityRef(secondTag.id))), Exercise(title = "Squat"))))
        val created = initial.createWorkout("Push Day", setOf(tag.id, secondTag.id))
        val newWorkout = created.data.workouts.last()
        assertEquals(1, created.data.exercises.count { it.workouts.any { ref -> ref.id == newWorkout.id } })
        created.data.validate()
    }
    @Test fun `import requires all relational arrays`() {
        assertThrows(IllegalArgumentException::class.java) { decodeImport("{}") }
        assertThrows(IllegalArgumentException::class.java) { decodeImport("{\"exercises\":[]}") }
        assertEquals(ExportData(), decodeImport("{\"workouts\":[],\"exercises\":[],\"tags\":[]}"))
    }
}
