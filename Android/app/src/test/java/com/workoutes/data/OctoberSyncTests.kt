package com.workoutes.data

import kotlinx.serialization.encodeToString
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import kotlin.math.PI

class OctoberSyncTests {
    private val now = Instant.parse("2026-10-23T15:00:00Z")
    private val tag = Tag("chest", "Chest", "FF8800", "chest")
    private val exercise = Exercise("bench", "Bench Press", subtitle = "Barbell", details = "Slow descent", weight = 60.0,
        increaseLoadNextTime = true, tags = listOf(EntityRef(tag.id)))
    private val initial = AppState(ExportData(exercises = listOf(exercise), tags = listOf(tag)))
    private fun completed() = initial.advance(exercise.id,now).stopActive(now.plusSeconds(11))

    @Test fun `completion captures immutable details and colored muscle icons`() {
        val saved = completed()
        val record = saved.data.history!!.single()
        assertEquals("chest",record.snapshot!!.tags.single().iconName)
        assertEquals(60.0,record.snapshot.weight,0.0)
        val edited = saved.updateExercise(exercise.copy(title="Changed", weight=999.0)).deleteTag(tag.id).deleteExercise(exercise.id)
        assertEquals(record.snapshot,edited.data.history!!.single().snapshot)
        assertNull(edited.data.history.single().exerciseID)
        assertEquals(60.0,edited.data.history.single().snapshot!!.weight,0.0)
    }
    @Test fun `history deletion removes only selected entries without touching catalog or playing session`() {
        val saved = completed()
        val again = saved.advance(exercise.id).advance(exercise.id,now.plusSeconds(30))
        val deleted = again.deleteHistory(setOf(saved.data.history!!.single().id))
        assertTrue(deleted.data.history!!.isEmpty())
        assertEquals(again.activeSession,deleted.activeSession)
        assertEquals(again.data.exercises,deleted.data.exercises)
        assertEquals(saved.data.history,saved.deleteHistory(setOf("missing")).data.history)
    }
    @Test fun `new backups retain muscle icons and immutable snapshots across repeated imports`() {
        val saved = completed()
        val imported = AppState().importData(decodeImport(workoutesJson.encodeToString(saved.data)))
        assertEquals(saved.data,imported.data)
        val changedRecord = saved.data.history!!.single().copy(snapshot = saved.data.history.single().snapshot!!.copy(title="Replacement"))
        assertEquals(saved.data.history,imported.importData(saved.data.copy(history=listOf(changedRecord))).data.history)
    }
    @Test fun `legacy backups have no invented icon or historical snapshot`() {
        val legacy = """{"workouts":[],"tags":[{"id":"t","name":"Old","colorHex":"FF8800"}],"exercises":[],"history":[{"id":"h","completedAt":"2026-10-01T12:00:00Z"}]}"""
        val parsed = decodeImport(legacy)
        assertNull(parsed.tags.single().iconName); assertNull(parsed.history!!.single().snapshot)
        val unknown = tag.copy(iconName="future-muscle")
        assertEquals("future-muscle",AppState().importData(ExportData(tags=listOf(unknown))).data.tags.single().iconName)
    }
    @Test fun `invalid snapshot import is rejected before changing data`() {
        val saved=completed()
        val record=saved.data.history!!.single()
        for (snapshot in listOf(record.snapshot!!.copy(weight=-1.0),record.snapshot.copy(reps=-1),record.snapshot.copy(numberOfSets=-1))) {
            assertThrows(IllegalArgumentException::class.java) { saved.importData(saved.data.copy(history=listOf(record.copy(snapshot=snapshot)))) }
        }
        assertEquals("Bench Press",saved.data.exercises.single().title)
    }
    @Test fun `active shortcut clears incompatible filters and retains matching filters`() {
        assertEquals(emptySet<String>(),initial.revealSelection(exercise.id,setOf("legs")))
        assertEquals(setOf(tag.id),initial.revealSelection(exercise.id,setOf(tag.id)))
        assertEquals(setOf("legs"),initial.revealSelection("deleted",setOf("legs")))
    }
    @Test fun `wheel crosses atan2 seam continuously and menu selection takes shortest turn`() {
        val wheel=TagWheelPosition()
        wheel.drag(PI-.05,8); wheel.drag(-PI+.05,8)
        assertEquals(.1/TagWheelPosition.spacing(8),wheel.position,.00001)
        wheel.position=7.8;wheel.select(0,8);assertEquals(8.0,wheel.position,0.0)
        wheel.position=-1.0;assertEquals(7,wheel.selectedIndex(8))
        wheel.snap();wheel.drag(1.0,8);assertEquals(-1.0,wheel.position,0.0)
        assertEquals(0,TagWheelPosition.wrap(-9,0))
    }
    @Test fun `docking clamps coordinates uses nearest edge and survives resized bounds`() {
        val bounds=WheelBounds(34f,34f,366f,700f)
        val dock=bounds.nearest(-100f,350f,"trailing")
        assertEquals("leading",dock.edge);assertTrue(dock.fraction in 0f..1f)
        assertEquals(34f,bounds.center(dock).first,0f)
        val larger=WheelBounds(34f,34f,700f,900f)
        assertEquals(34f,larger.center(dock).first,0f)
        assertTrue(larger.center(dock).second > bounds.center(dock).second)
        assertEquals(34f,bounds.center(WheelDock("leading",Float.NaN)).first,0f)
    }
}
