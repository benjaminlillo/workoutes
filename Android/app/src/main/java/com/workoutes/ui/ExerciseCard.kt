@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.workoutes.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.workoutes.data.*

@Composable internal fun ExerciseCard(
    exercise: Exercise, state: AppState, workoutId: String?, onAdvance: () -> Unit,
    onEdit: () -> Unit, onMetric: (String) -> Unit, onBump: () -> Unit,
    onRemove: () -> Unit, onDelete: () -> Unit, revealToken: Int = 0
) {
    var menu by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val playing = state.activeExerciseId == exercise.id
    val status = when { exercise.isDone -> "Completed"; playing -> "Active"; else -> "Not started" }
    val pulse = remember { Animatable(0f) }
    LaunchedEffect(revealToken) { if (revealToken > 0) { pulse.snapTo(1f); pulse.animateTo(0f, tween(1600)) } }
    val swipe = rememberSwipeToDismissBoxState(confirmValueChange = { value ->
        if (value == SwipeToDismissBoxValue.StartToEnd) { onBump(); haptics.performHapticFeedback(HapticFeedbackType.LongPress) }; false
    })
    SwipeToDismissBox(state = swipe, enableDismissFromEndToStart = false,
        modifier = Modifier.padding(horizontal = 16.dp), backgroundContent = {
            Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(18.dp)).padding(20.dp)) {
                AppIcon(AppIcons.Bump, "Bump", Modifier.align(Alignment.CenterStart))
            }
        }) {
        Card(shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
            modifier = Modifier.fillMaxWidth().testTag("exerciseCard.${exercise.id}")
                .border(2.dp, MaterialTheme.colorScheme.primary.copy(alpha = pulse.value), RoundedCornerShape(18.dp))
                .clip(RoundedCornerShape(18.dp)).combinedClickable(onClick = {}, onLongClickLabel = "Exercise Actions", onLongClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress); menu = true
                })) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                ExerciseHeader(exercise, exercise.tags.mapNotNull { ref -> state.data.tags.firstOrNull { it.id == ref.id } }) {
                    IconButton(onClick = { onAdvance(); haptics.performHapticFeedback(HapticFeedbackType.LongPress) },
                        modifier = Modifier.semantics { stateDescription = status }) {
                        if (playing && !exercise.isDone) Box(Modifier.size(32.dp).semantics { contentDescription = "Stop ${exercise.title}" }) {
                            AppIcon(AppIcons.NotStarted, null, Modifier.matchParentSize(), tint = MaterialTheme.colorScheme.primary)
                            AppIcon(AppIcons.Stop, null, Modifier.size(22.dp).align(Alignment.Center), tint = MaterialTheme.colorScheme.primary)
                        } else AppIcon(if (exercise.isDone) AppIcons.Completed else AppIcons.NotStarted,
                            if (exercise.isDone) "Unmark ${exercise.title}" else "Start ${exercise.title}",
                            Modifier.size(32.dp), tint = MaterialTheme.colorScheme.primary)
                    }
                }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("Edit Exercise") }, onClick = { menu = false; onEdit() }, leadingIcon = { AppIcon(AppIcons.Edit, null) })
                    DropdownMenuItem(text = { Text(if (exercise.increaseLoadNextTime) "Disable Bump" else "Bump Next Time") }, onClick = { menu = false; onBump() }, leadingIcon = { AppIcon(AppIcons.Bump, null) })
                    if (workoutId != null) DropdownMenuItem(text = { Text("Remove from Workout") }, onClick = { menu = false; onRemove() }, leadingIcon = { AppIcon(AppIcons.Remove, null) })
                    DropdownMenuItem(text = { Text("Delete Permanently", color = MaterialTheme.colorScheme.error) }, onClick = { menu = false; onDelete() }, leadingIcon = { AppIcon(AppIcons.Delete, null) })
                }
                HorizontalDivider()
                ExerciseMetrics(exercise, state.preferences.unit, onMetric)
            }
        }
    }
}

@Composable internal fun ExerciseHeader(exercise: Exercise, tags: List<Tag>, status: @Composable () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(exercise.title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            if (exercise.subtitle.isNotEmpty()) Text(exercise.subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (exercise.details.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                AppIcon(AppIcons.Notes, null, Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(exercise.details, maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (exercise.increaseLoadNextTime) Box(Modifier.heightIn(min = 48.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.size(26.dp).background(MaterialTheme.colorScheme.primary.copy(alpha = .14f), CircleShape), contentAlignment = Alignment.Center) {
                AppIcon(AppIcons.Bump, "Increase load next time", Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary)
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
            status()
            tags.chunked(3).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) { row.forEach { TagGlyph(it, Modifier.size(20.dp)) } }
            }
        }
    }
}

@Composable internal fun ExerciseMetrics(exercise: Exercise, unit: WeightUnit, onMetric: ((String) -> Unit)? = null) {
    val values = listOf(Triple(AppIcons.Weight, unit.format(exercise.weight), "Weight"),
        Triple(AppIcons.Sets, "${exercise.numberOfSets} sets", "Sets"), Triple(AppIcons.Repetitions, "${exercise.reps} reps", "Repetitions"))
    @Composable fun metric(value: Triple<Int, String, String>, modifier: Modifier) {
        val row: @Composable () -> Unit = {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                AppIcon(value.first, null, Modifier.size(24.dp), tint = MaterialTheme.colorScheme.onSurface)
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(value.second, color = MaterialTheme.colorScheme.onSurface, style = MaterialTheme.typography.labelLarge, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Text(value.third.uppercase(), color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.labelSmall, fontSize = 9.sp, letterSpacing = 0.sp)
                }
            }
        }
        if (onMetric == null) Box(modifier.heightIn(min = 52.dp), contentAlignment = Alignment.CenterStart) { row() }
        else TextButton(onClick = { onMetric(value.third) }, modifier = modifier.heightIn(min = 52.dp), contentPadding = PaddingValues(horizontal = 4.dp)) { row() }
    }
    if (LocalDensity.current.fontScale > 1.4f) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        values.forEachIndexed { index, value -> if (index > 0) HorizontalDivider(); metric(value, Modifier.fillMaxWidth()) }
    } else Row(verticalAlignment = Alignment.CenterVertically) {
        values.forEachIndexed { index, value -> if (index > 0) VerticalDivider(Modifier.height(42.dp)); metric(value, Modifier.weight(1f)) }
    }
}
