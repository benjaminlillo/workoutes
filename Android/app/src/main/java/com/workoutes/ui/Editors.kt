package com.workoutes.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.workoutes.WorkoutesViewModel
import com.workoutes.data.*
import java.text.NumberFormat

@Composable internal fun SheetForm(title: String, close: () -> Unit, closeLabel: String = "Done", content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().imePadding().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(title, Modifier.weight(1f), style = MaterialTheme.typography.titleLarge)
            TextButton(onClick = close) { Text(closeLabel) }
        }
        Surface(shape = androidx.compose.foundation.shape.RoundedCornerShape(26.dp), color = MaterialTheme.colorScheme.surface, shadowElevation = 1.dp) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
        }
    }
}
@Composable internal fun WorkoutEditor(state: AppState, model: WorkoutesViewModel, close: () -> Unit) {
    var name by rememberSaveable { mutableStateOf("") }
    var tags by rememberSaveable { mutableStateOf<List<String>>(emptyList()) }
    SheetForm("New Workout", close, "Cancel") {
        OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        if (state.data.tags.isNotEmpty()) {
            Text("Auto-Populate with Tags", style = MaterialTheme.typography.titleSmall)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(state.data.tags.sortedBy { it.name.lowercase() }, key = { it.id }) { tag ->
                    FilterChip(selected = tag.id in tags, onClick = { tags = if (tag.id in tags) tags - tag.id else tags + tag.id }, label = { Text(tag.name) }, leadingIcon = { TagGlyph(tag) })
                }
            }
            Text("All exercises containing these tags will be automatically added to your workout.", style = MaterialTheme.typography.bodySmall)
        }
        Button(onClick = { model.update { it.createWorkout(name.trim(), tags.toSet()) }; close() },
            enabled = name.isNotBlank(), modifier = Modifier.fillMaxWidth()) { Text("Create Workout") }
    }
}
@Composable internal fun ExerciseEditor(exercise: Exercise?, workoutId: String?, state: AppState, model: WorkoutesViewModel, close: () -> Unit) {
    var title by rememberSaveable { mutableStateOf(exercise?.title ?: "") }
    var subtitle by rememberSaveable { mutableStateOf(exercise?.subtitle ?: "") }
    var details by rememberSaveable { mutableStateOf(exercise?.details ?: "") }
    var sets by rememberSaveable { mutableIntStateOf(exercise?.numberOfSets ?: 3) }
    var reps by rememberSaveable { mutableIntStateOf(exercise?.reps ?: 10) }
    val unit = state.preferences.unit
    var weight by rememberSaveable { mutableStateOf(unit.display(exercise?.weight ?: 0.0).toString()) }
    var tags by rememberSaveable { mutableStateOf<List<String>>(exercise?.tags?.map { it.id } ?: emptyList()) }
    var bump by rememberSaveable { mutableStateOf(exercise?.increaseLoadNextTime ?: false) }
    val numericWeight = weight.replace(',', '.').toDoubleOrNull()
    val validWeight = numericWeight != null && numericWeight.isFinite() && numericWeight >= 0
    SheetForm(if (exercise != null) "Edit Exercise" else if (workoutId != null) "Add Exercise" else "New Exercise", close, "Cancel") {
        if (exercise == null && workoutId != null) {
            val existing = state.data.exercises.filterNot { it.workouts.any { ref -> ref.id == workoutId } }.sortedBy { it.title.lowercase() }
            if (existing.isNotEmpty()) {
                Text("Add Existing Exercise", style = MaterialTheme.typography.titleSmall)
                existing.forEach { candidate ->
                    TextButton(onClick = {
                        model.update { current -> current.data.exercises.firstOrNull { it.id == candidate.id }?.let {
                            current.updateExercise(it.copy(workouts = (it.workouts + EntityRef(workoutId)).distinct()))
                        } ?: current }; close()
                    }, modifier = Modifier.fillMaxWidth()) {
                        Text(candidate.title, Modifier.weight(1f)); AppIcon(AppIcons.AddCircle, null)
                    }
                }
                HorizontalDivider()
            }
        }
        Text("Basic Info", style = MaterialTheme.typography.titleSmall)
        OutlinedTextField(title, { title = it }, label = { Text("Title") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(subtitle, { subtitle = it }, label = { Text("Subtitle (Optional)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(details, { details = it }, label = { Text("Details (Optional)") }, minLines = 2, modifier = Modifier.fillMaxWidth())
        Text("Targets", style = MaterialTheme.typography.titleSmall)
        Stepper("Sets", sets, 1, maxOf(20, exercise?.numberOfSets ?: 20)) { sets = it }
        Stepper("Repetitions", reps, 1, maxOf(100, exercise?.reps ?: 100)) { reps = it }
        OutlinedTextField(weight, { weight = it }, label = { Text("Weight (${unit.symbol})") }, isError = !validWeight,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), singleLine = true, modifier = Modifier.fillMaxWidth())
        if (state.data.tags.isNotEmpty()) {
            Text("Tags", style = MaterialTheme.typography.titleSmall)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(state.data.tags.sortedBy { it.name.lowercase() }, key = { it.id }) { tag ->
                    FilterChip(selected = tag.id in tags, onClick = { tags = if (tag.id in tags) tags - tag.id else tags + tag.id },
                        label = { Text(tag.name) }, leadingIcon = { TagGlyph(tag) })
                }
            }
        }
        if (exercise != null) Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Increase load next time", Modifier.weight(1f)); Switch(bump, { bump = it })
        }
        Button(onClick = {
            model.update { current ->
                val original = current.data.exercises.firstOrNull { it.id == exercise?.id } ?: Exercise(title = title)
                current.updateExercise(original.copy(title = title.trim(), subtitle = subtitle.trim(), details = details.trim(),
                    numberOfSets = sets, reps = reps, weight = unit.kilograms(numericWeight ?: 0.0), increaseLoadNextTime = bump,
                    tags = tags.filter { id -> current.data.tags.any { it.id == id } }.map(::EntityRef),
                    workouts = if (workoutId != null) (original.workouts + EntityRef(workoutId)).distinct() else original.workouts))
            }; close()
        }, enabled = title.isNotBlank() && validWeight, modifier = Modifier.fillMaxWidth()) { Text(if (workoutId != null) "Create and Add" else "Save") }
    }
}
@Composable internal fun Stepper(label: String, value: Int, minimum: Int, maximum: Int, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("$label: $value", Modifier.weight(1f))
        IconButton(onClick = { onChange(value - 1) }, enabled = value > minimum) { AppIcon(AppIcons.Remove, "Decrease $label") }
        IconButton(onClick = { onChange(value + 1) }, enabled = value < maximum) { AppIcon(AppIcons.AddCircle, "Increase $label") }
    }
}
@Composable internal fun MetricEditor(exercise: Exercise, metric: String, unit: WeightUnit, model: WorkoutesViewModel, close: () -> Unit) {
    var raw by rememberSaveable { mutableStateOf(when (metric) {
        "Weight" -> unit.display(exercise.weight).toString()
        "Sets" -> exercise.numberOfSets.toString()
        else -> exercise.reps.toString()
    }) }
    val value = raw.replace(',', '.').toDoubleOrNull()
    val valid = value != null && value.isFinite() && value >= (if (metric == "Weight") 0 else 1) &&
        (metric == "Weight" || (value % 1.0 == 0.0 && value <= Int.MAX_VALUE))
    fun applyValue(number: Double) {
        model.update { current -> current.data.exercises.firstOrNull { it.id == exercise.id }?.let {
            current.updateExercise(when (metric) {
                "Weight" -> it.copy(weight = unit.kilograms(number))
                "Sets" -> it.copy(numberOfSets = number.toInt())
                else -> it.copy(reps = number.toInt())
            })
        } ?: current }
    }
    SheetForm(metric, close) {
        Text(exercise.title, style = MaterialTheme.typography.bodyMedium)
        OutlinedTextField(raw, { raw = it; it.replace(',', '.').toDoubleOrNull()?.let { number ->
            if (number.isFinite() && number >= (if (metric == "Weight") 0 else 1) &&
                (metric == "Weight" || (number % 1.0 == 0.0 && number <= Int.MAX_VALUE))) applyValue(number)
        } }, label = { Text(if (metric == "Weight") "Weight (${unit.symbol})" else metric) }, isError = !valid,
            keyboardOptions = KeyboardOptions(keyboardType = if (metric == "Weight") KeyboardType.Decimal else KeyboardType.Number),
            singleLine = true, modifier = Modifier.fillMaxWidth())
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            val step = if (metric == "Weight") unit.step else 1.0
            val minimum = if (metric == "Weight") 0.0 else 1.0
            val maximum = when (metric) {
                "Weight" -> maxOf(unit.display(500.0), unit.display(exercise.weight))
                "Sets" -> maxOf(20, exercise.numberOfSets).toDouble()
                else -> maxOf(100, exercise.reps).toDouble()
            }
            OutlinedButton(onClick = { val next = maxOf(minimum, (value ?: minimum) - step); raw = next.toString(); applyValue(next) }, enabled = valid && value!! > minimum) { Text("−") }
            Text(NumberFormat.getNumberInstance().apply { maximumFractionDigits = 2 }.format(value ?: 0), Modifier.padding(20.dp), style = MaterialTheme.typography.headlineSmall)
            OutlinedButton(onClick = { val next = minOf(maximum, (value ?: minimum) + step); raw = next.toString(); applyValue(next) }, enabled = valid && value!! < maximum) { Text("+") }
        }
        Text("Changes are saved as you adjust the value.", style = MaterialTheme.typography.bodySmall)
    }
}
@Composable internal fun TagEditor(tag: Tag?, model: WorkoutesViewModel, close: () -> Unit) {
    var name by rememberSaveable { mutableStateOf(tag?.name ?: "") }
    var hex by rememberSaveable { mutableStateOf(tag?.colorHex ?: "007AFF") }
    var icon by rememberSaveable { mutableStateOf(tag?.iconName) }
    var choosingIcon by remember { mutableStateOf(false) }
    SheetForm(if (tag == null) "New Tag" else "Edit Tag", close, "Cancel") {
        OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        ColorInput(hex) { hex = it }
        TextButton(onClick = { choosingIcon = true }, modifier = Modifier.fillMaxWidth()) {
            MuscleGlyph(icon, hexColor(hex), Modifier.size(32.dp)); Spacer(Modifier.width(12.dp))
            Text("Muscle Icon: ${muscleSymbols.firstOrNull { it.name == icon }?.label ?: "None"}")
        }
        Button(onClick = {
            model.update { current ->
                val saved = Tag(tag?.id ?: newId(), name.trim(), hex.removePrefix("#"), icon)
                current.copy(data = current.data.copy(tags = if (current.data.tags.any { it.id == saved.id })
                    current.data.tags.map { if (it.id == saved.id) saved else it } else current.data.tags + saved))
            }; close()
        }, enabled = name.isNotBlank() && validHex(hex), modifier = Modifier.fillMaxWidth()) { Text("Save") }
    }
    if (choosingIcon) MuscleIconPicker(icon, hexColor(hex), onChoose = { icon = it; choosingIcon = false }, onDismiss = { choosingIcon = false })
}
@Composable internal fun ColorInput(hex: String, onChange: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(hex, onChange, label = { Text("Color (HEX)") }, singleLine = true, isError = !validHex(hex),
            leadingIcon = { Box(Modifier.size(24.dp).background(hexColor(hex), CircleShape)) }, modifier = Modifier.fillMaxWidth())
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items((AppTheme.entries.map { it.hex } + defaultGradient + listOf("F4D8BD", "FFFFFF", "000000")).toList()) { color ->
                IconButton(onClick = { onChange(color) }) { AppIcon(AppIcons.Dot, "Color #$color", tint = hexColor(color), modifier = Modifier.size(28.dp)) }
            }
        }
    }
}
