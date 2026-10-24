@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.workoutes.ui

import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.Alignment
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.workoutes.WorkoutesViewModel
import com.workoutes.data.*
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

internal fun completionDate(record: ExerciseCompletion): String = Instant.parse(record.completedAt).atZone(ZoneId.systemDefault())
    .format(DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT))

@Composable internal fun HistoryScreen(state: AppState, model: WorkoutesViewModel, bottomPadding: Dp) {
    var editing by rememberSaveable { mutableStateOf(false) }
    var selected by rememberSaveable { mutableStateOf(emptyList<String>()) }
    var confirm by remember { mutableStateOf(false) }
    val history = state.data.history.orEmpty().sortedWith(compareByDescending<ExerciseCompletion> { Instant.parse(it.completedAt) }.thenBy { it.id })
    Column(Modifier.fillMaxSize()) {
        if (history.isNotEmpty()) Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.End) {
            if (editing && selected.isNotEmpty()) TextButton(onClick = { confirm = true }) { Text("Delete Selected (${selected.size})", color = MaterialTheme.colorScheme.error) }
            TextButton(onClick = { editing = !editing; selected = emptyList() }) { Text(if (editing) "Done" else "Edit") }
        }
        LazyColumn(contentPadding = PaddingValues(16.dp, 8.dp, 16.dp, bottomPadding), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (history.isEmpty()) item {
                Text("No Exercise History", style = MaterialTheme.typography.titleLarge)
                Text("Completed exercises will appear here.")
            }
            items(history, key = { it.id }) { record ->
                Card(shape = RoundedCornerShape(26.dp), elevation = CardDefaults.cardElevation(1.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    ListItem(headlineContent = { Text(state.data.exercises.firstOrNull { it.id == record.exerciseID }?.title ?: "Exercise deleted") },
                        supportingContent = { Text(completionDate(record)) }, leadingContent = {
                            if (editing) Checkbox(record.id in selected, { checked -> selected = if (checked) selected + record.id else selected - record.id }, modifier = Modifier.testTag("selectHistory.${record.id}"))
                        }, trailingContent = { IconButton(onClick = { selected = listOf(record.id); confirm = true }) { AppIcon(AppIcons.Delete, "Delete history entry ${record.id}") } },
                        modifier = Modifier.testTag("historyEntry.${record.id}"))
                }
            }
        }
    }
    if (confirm) AlertDialog(onDismissRequest = { confirm = false }, title = { Text("Delete History?") },
        text = { Text("Delete ${selected.size} entries? Your exercises and their completed state will be kept.") },
        confirmButton = { TextButton(onClick = { val ids = selected.toSet(); model.update { it.deleteHistory(ids) }; selected = emptyList(); confirm = false }) { Text("Delete") } },
        dismissButton = { TextButton(onClick = { confirm = false }) { Text("Cancel") } })
}

@Composable internal fun CompletionPreview(record: ExerciseCompletion, unit: WeightUnit, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Exercise History", Modifier.weight(1f), style = MaterialTheme.typography.titleLarge)
                TextButton(onClick = onDismiss) { Text("Done") }
            }
            Text(completionDate(record), color = MaterialTheme.colorScheme.onSurfaceVariant)
            val snapshot = record.snapshot
            if (snapshot == null) {
                Text("No Historical Snapshot", style = MaterialTheme.typography.titleMedium)
                Text("Exercise details weren't saved for this entry.")
            } else Card(Modifier.testTag("exerciseCompletionPreview"), shape = RoundedCornerShape(18.dp),
                elevation = CardDefaults.cardElevation(1.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    ExerciseHeader(snapshot.asExercise(), snapshot.asTags()) {
                        AppIcon(AppIcons.Completed, "Exercise completed", Modifier.padding(8.dp).size(32.dp), tint = MaterialTheme.colorScheme.primary)
                    }
                    HorizontalDivider()
                    ExerciseMetrics(snapshot.asExercise(), unit)
                }
            }
        }
    }
}
