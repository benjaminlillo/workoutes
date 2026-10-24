package com.workoutes.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.jsonObject
import java.text.NumberFormat
import java.util.UUID
import java.time.Instant
import java.time.Duration

fun newId(): String = UUID.randomUUID().toString()

@Serializable data class Workout(val id: String = newId(), val name: String)
@Serializable data class Tag(val id: String = newId(), val name: String, val colorHex: String, val iconName: String? = null)
@Serializable data class EntityRef(val id: String)
@Serializable data class Exercise(
    val id: String = newId(), val title: String, val subtitle: String = "", val details: String = "",
    val numberOfSets: Int = 3, val reps: Int = 10, val increaseLoadNextTime: Boolean = false,
    val isDone: Boolean = false, val weight: Double = 0.0,
    val workouts: List<EntityRef> = emptyList(), val tags: List<EntityRef> = emptyList()
)
@Serializable data class ExportData(
    val workouts: List<Workout> = emptyList(), val exercises: List<Exercise> = emptyList(),
    val tags: List<Tag> = emptyList(), val history: List<ExerciseCompletion>? = null
) {
    fun validate(existing: ExportData = ExportData()) {
        require(workouts.map { it.id }.distinct().size == workouts.size) { "Duplicate workout IDs." }
        require(tags.map { it.id }.distinct().size == tags.size) { "Duplicate tag IDs." }
        require(exercises.map { it.id }.distinct().size == exercises.size) { "Duplicate exercise IDs." }
        require(workouts.all { it.id.isNotBlank() && it.name.isNotBlank() }) { "Every workout needs an ID and name." }
        require(tags.all { it.id.isNotBlank() && it.name.isNotBlank() && validHex(it.colorHex) }) { "Invalid tag name or color." }
        val workoutIds = (workouts + existing.workouts).map { it.id }.toSet()
        val tagIds = (tags + existing.tags).map { it.id }.toSet()
        val exerciseIds = (exercises + existing.exercises).map { it.id }.toSet()
        exercises.forEach {
            require(it.id.isNotBlank() && it.title.isNotBlank()) { "Every exercise needs an ID and title." }
            require(it.weight.isFinite() && it.weight >= 0 && it.numberOfSets >= 0 && it.reps >= 0) { "Invalid exercise targets." }
            require(it.workouts.all { ref -> ref.id in workoutIds } && it.tags.all { ref -> ref.id in tagIds }) {
                "An exercise refers to a missing workout or tag."
            }
            require(it.workouts.distinct().size == it.workouts.size && it.tags.distinct().size == it.tags.size) {
                "Duplicate workout or tag references."
            }
        }
        val records = history.orEmpty()
        require(records.map { it.id }.distinct().size == records.size) { "Duplicate history IDs." }
        records.forEach {
            require(it.id.isNotBlank() && (it.exerciseID == null || it.exerciseID in exerciseIds)) { "Invalid history reference." }
            require(it.snapshot?.isValid != false) { "Invalid historical exercise details." }
            require(runCatching { Instant.parse(it.completedAt) }.isSuccess) { "Invalid history date. Use ISO 8601." }
        }
    }
}

val workoutesJson = Json { prettyPrint = true; ignoreUnknownKeys = true; encodeDefaults = true }
fun decodeImport(text: String, existing: ExportData = ExportData()): ExportData {
    val root = workoutesJson.parseToJsonElement(text).jsonObject
    require(listOf("workouts", "exercises", "tags").all { root[it] is JsonArray }) {
        "The JSON must contain workouts, exercises and tags arrays."
    }
    return workoutesJson.decodeFromString<ExportData>(text).also { it.validate(existing) }
}
fun validHex(value: String) = value.removePrefix("#").matches(Regex("[0-9a-fA-F]{6}([0-9a-fA-F]{2})?"))

@Serializable enum class WeightUnit(val symbol: String, val label: String, val step: Double) {
    Metric("kg", "Metric (kg)", 0.5), Imperial("lb", "Imperial (lb)", 1.0);
    fun display(kilograms: Double) = if (this == Metric) kilograms else kilograms / 0.45359237
    fun kilograms(value: Double) = if (this == Metric) value else value * 0.45359237
    fun format(kilograms: Double): String = NumberFormat.getNumberInstance().apply {
        maximumFractionDigits = 2
    }.format(display(kilograms)) + " " + symbol
}

@Serializable enum class BackgroundMode { Gradient, Wallpaper, Automatic }
val defaultGradient = listOf("B8D8F8", "D8C3F0")
@Serializable data class Background(
    val mode: BackgroundMode = BackgroundMode.Gradient, val colors: List<String> = defaultGradient,
    val imageFile: String? = null
)
@Serializable data class Preferences(val accent: String = "Indigo", val unit: WeightUnit = WeightUnit.Metric)
@Serializable data class ExerciseSession(val id: String = newId(), val exerciseId: String, val startedAt: String)
@Serializable data class CompletionTag(val name: String, val colorHex: String, val iconName: String? = null)
@Serializable data class ExerciseSnapshot(
    val title: String, val subtitle: String, val details: String,
    val numberOfSets: Int, val reps: Int, val weight: Double,
    val increaseLoadNextTime: Boolean, val tags: List<CompletionTag>
) {
    val isValid get() = weight.isFinite() && weight >= 0 && numberOfSets >= 0 && reps >= 0
    fun asExercise() = Exercise(id = "historical-preview", title = title, subtitle = subtitle, details = details,
        numberOfSets = numberOfSets, reps = reps, weight = weight, increaseLoadNextTime = increaseLoadNextTime,
        isDone = true, tags = tags.indices.map { EntityRef("snapshot-tag-$it") })
    fun asTags() = tags.mapIndexed { index, tag -> Tag("snapshot-tag-$index", tag.name, tag.colorHex, tag.iconName) }
}
@Serializable data class ExerciseCompletion(val id: String, val completedAt: String, val exerciseID: String? = null,
    val snapshot: ExerciseSnapshot? = null)
@Serializable data class WheelDock(val edge: String = "trailing", val fraction: Float = .85f)
@Serializable data class AppState(
    val data: ExportData = ExportData(), val preferences: Preferences = Preferences(),
    val backgrounds: Map<String, Background> = emptyMap(), val activeExerciseId: String? = null,
    val activeSession: ExerciseSession? = null, val wheelDock: WheelDock? = null
) {
    fun createWorkout(name: String, selectedTags: Set<String>): AppState {
        val workout = Workout(name = name)
        return copy(data = data.copy(workouts = data.workouts + workout, exercises = data.exercises.map { exercise ->
            if (exercise.tags.any { it.id in selectedTags }) exercise.copy(workouts = exercise.workouts + EntityRef(workout.id))
            else exercise
        }))
    }
    fun advance(id: String, now: Instant = Instant.now()): AppState {
        val exercise = data.exercises.firstOrNull { it.id == id } ?: return this
        return when {
            activeExerciseId == id -> stopActive(now)
            exercise.isDone -> updateExercise(exercise.copy(isDone = false))
            // Switching cancels the old attempt, regardless of its duration.
            else -> copy(activeExerciseId = id, activeSession = ExerciseSession(exerciseId = id, startedAt = now.toString()))
        }
    }
    fun stopActive(now: Instant = Instant.now()): AppState {
        val session = activeSession ?: return copy(activeExerciseId = null)
        val exercise = data.exercises.firstOrNull { it.id == session.exerciseId }
            ?: return copy(activeExerciseId = null, activeSession = null)
        val completed = Duration.between(Instant.parse(session.startedAt), now) > Duration.ofSeconds(10)
        val history = data.history.orEmpty()
        val nextHistory = if (completed && history.none { it.id == session.id })
            history + ExerciseCompletion(session.id, now.toString(), exercise.id,
                ExerciseSnapshot(exercise.title, exercise.subtitle, exercise.details, exercise.numberOfSets, exercise.reps,
                    exercise.weight, exercise.increaseLoadNextTime, exercise.tags.mapNotNull { ref ->
                        data.tags.firstOrNull { it.id == ref.id }?.let { CompletionTag(it.name, it.colorHex, it.iconName) }
                    })) else history
        return copy(data = data.copy(exercises = data.exercises.map {
            if (it.id == exercise.id) it.copy(isDone = completed) else it
        }, history = nextHistory), activeExerciseId = null, activeSession = null)
    }
    fun notificationAction(id: String, sessionId: String?, stop: Boolean, now: Instant = Instant.now()): AppState {
        if (sessionId == null || activeSession?.id != sessionId || activeExerciseId != id) return this
        val exercise = data.exercises.firstOrNull { it.id == id && !it.isDone } ?: return this
        return if (stop) stopActive(now) else updateExercise(exercise.copy(increaseLoadNextTime = !exercise.increaseLoadNextTime))
    }
    fun restoreSession(now: Instant = Instant.now()): AppState {
        val id = activeSession?.exerciseId ?: activeExerciseId
        val valid = data.exercises.any { it.id == id && !it.isDone }
        if (!valid) return copy(activeExerciseId = null, activeSession = null)
        val session = activeSession?.takeIf { runCatching { Instant.parse(it.startedAt) }.isSuccess }
            ?: ExerciseSession(exerciseId = id!!, startedAt = now.toString())
        return copy(activeExerciseId = id, activeSession = session)
    }
    fun updateExercise(exercise: Exercise) = copy(data = data.copy(exercises =
        if (data.exercises.any { it.id == exercise.id }) data.exercises.map { if (it.id == exercise.id) exercise else it }
        else data.exercises + exercise
    ), activeExerciseId = if (activeExerciseId == exercise.id && exercise.isDone) null else activeExerciseId,
        activeSession = activeSession.takeUnless { it?.exerciseId == exercise.id && exercise.isDone })
    fun deleteHistory(ids: Set<String>) = copy(data = data.copy(history = data.history.orEmpty().filterNot { it.id in ids }))
    fun revealSelection(id: String, selected: Set<String>): Set<String> {
        val exercise = data.exercises.firstOrNull { it.id == id } ?: return selected
        return if (selected.isEmpty() || exercise.tags.any { it.id in selected }) selected else emptySet()
    }
    fun deleteExercise(id: String) = copy(data = data.copy(exercises = data.exercises.filterNot { it.id == id },
        history = data.history?.map { if (it.exerciseID == id) it.copy(exerciseID = null) else it }),
        activeExerciseId = activeExerciseId.takeUnless { it == id }, activeSession = activeSession.takeUnless { it?.exerciseId == id })
    fun deleteWorkout(id: String) = copy(data = data.copy(
        workouts = data.workouts.filterNot { it.id == id },
        exercises = data.exercises.map { it.copy(workouts = it.workouts.filterNot { ref -> ref.id == id }) }
    ), backgrounds = backgrounds - id)
    fun deleteTag(id: String) = copy(data = data.copy(tags = data.tags.filterNot { it.id == id },
        exercises = data.exercises.map { it.copy(tags = it.tags.filterNot { ref -> ref.id == id }) }))
    fun importData(imported: ExportData): AppState {
        imported.validate(data)
        fun <T> upsert(existing: List<T>, incoming: List<T>, id: (T) -> String): List<T> {
            val values = existing.associateBy(id).toMutableMap()
            incoming.forEach { values[id(it)] = it }
            return values.values.toList()
        }
        val next = copy(data = ExportData(
            upsert(data.workouts, imported.workouts) { it.id },
            upsert(data.exercises, imported.exercises) { it.id },
            upsert(data.tags, imported.tags) { it.id },
            data.history.orEmpty() + imported.history.orEmpty().filter { record -> data.history.orEmpty().none { it.id == record.id } }
        ))
        return next.restoreSession()
    }
}
