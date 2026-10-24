package com.workoutes.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.Alignment
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.Dp
import com.workoutes.WorkoutesViewModel
import com.workoutes.data.*

@Composable internal fun SettingsScreen(preferences: Preferences, bottomPadding: Dp, onOpen: (String) -> Unit, onImport: () -> Unit, onExport: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 20.dp).padding(bottom = bottomPadding), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Appearance", style = MaterialTheme.typography.titleSmall)
        Card(elevation = CardDefaults.cardElevation(defaultElevation = 1.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            ListItem(headlineContent = { Text("Theme") }, supportingContent = { Text(AppTheme.resolve(preferences.accent).label, color = MaterialTheme.colorScheme.primary) },
                trailingContent = { AppIcon(AppIcons.Forward, null) },
                modifier = Modifier.clickable { onOpen("theme") })
        }
        Text("Units", style = MaterialTheme.typography.titleSmall)
        Card(elevation = CardDefaults.cardElevation(defaultElevation = 1.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            ListItem(headlineContent = { Text("Weight Unit") }, supportingContent = { Text(preferences.unit.label, color = MaterialTheme.colorScheme.primary) },
                trailingContent = { AppIcon(AppIcons.Forward, null) },
                modifier = Modifier.clickable { onOpen("unit") })
        }
        Card(elevation = CardDefaults.cardElevation(1.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            ListItem(headlineContent = { Text("Exercise History") }, trailingContent = { AppIcon(AppIcons.Forward, null) }, modifier = Modifier.clickable { onOpen("history") })
        }
        Text("Data", style = MaterialTheme.typography.titleSmall)
        Card(elevation = CardDefaults.cardElevation(defaultElevation = 1.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            Column(Modifier.padding(12.dp)) {
                TextButton(onClick = onExport, modifier = Modifier.fillMaxWidth()) {
                    Text("Export Data (JSON)", Modifier.weight(1f)); AppIcon(AppIcons.Export, null)
                }
                HorizontalDivider()
                TextButton(onClick = onImport, modifier = Modifier.fillMaxWidth()) {
                    Text("Import Data (JSON)", Modifier.weight(1f)); AppIcon(AppIcons.Import, null)
                }
            }
        }
    }
}

@Composable internal fun PreferenceScreen(selection: String, preferences: Preferences, model: WorkoutesViewModel, bottomPadding: Dp) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp).padding(bottom = bottomPadding)
        .selectableGroup(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        WeightUnit.entries.forEach { unit ->
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()
                .selectable(selected = preferences.unit == unit, role = Role.RadioButton, onClick = {
                    model.update { it.copy(preferences = it.preferences.copy(unit = unit)) }
                }).padding(vertical = 4.dp)) {
                RadioButton(preferences.unit == unit, onClick = null)
                Text(unit.label, Modifier.padding(12.dp), color = MaterialTheme.colorScheme.primary)
            }
        }
    }
}

internal val aiPrompt = """
Please convert the provided workout exercises into a JSON format strictly following this structure:

{
  "workouts": [{ "id": "uuid", "name": "string" }],
  "tags": [{ "id": "uuid", "name": "string", "colorHex": "007AFF", "iconName": "chest" }],
  "exercises": [{
    "id": "uuid", "title": "string", "subtitle": "string", "details": "string",
    "numberOfSets": 3, "reps": 10, "increaseLoadNextTime": false, "isDone": false,
    "weight": 0.0, "workouts": [{ "id": "uuid" }], "tags": [{ "id": "uuid" }]
  }]
}

Ensure all objects are linked by matching IDs. Use valid UUIDs for all IDs, six-digit HEX tag colors,
non-negative targets and weights in kilograms. Optional tag iconName values: fullBody, upperBody, lowerBody, arms, core, chest, back, shoulders, biceps, triceps, forearms, trapezius, upperBack, lowerBack, abdominals, obliques, neck, glutes, quadriceps, hamstrings, calves, adductors, abductors, tibialis. Omit iconName for color-only tags. Output ONLY valid JSON without markdown wrapping.
""".trimIndent()

@Composable internal fun ImportScreen(model: WorkoutesViewModel, bottomPadding: Dp, onSuccess: () -> Unit) {
    val context = LocalContext.current
    val select = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) model.importFile(uri, onSuccess)
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 20.dp).padding(bottom = bottomPadding), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Text("JSON Format Requirements", style = MaterialTheme.typography.titleMedium)
        Surface(shape = androidx.compose.foundation.shape.RoundedCornerShape(26.dp), color = MaterialTheme.colorScheme.surface, shadowElevation = 1.dp) {
            Text("Your JSON file must link workouts, tags and exercises by unique IDs. Reimporting updates items by ID without duplicates. Exercise history is imported automatically when included.", Modifier.padding(16.dp))
        }
        Text("AI Assistant Prompt", style = MaterialTheme.typography.titleMedium)
        Text("Copy this prompt and send it to ChatGPT, Claude, or Gemini along with your text-based routines. The AI will format your routines for Workoutes.")
        OutlinedButton(onClick = {
            (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Workoutes JSON Prompt", aiPrompt))
            model.report("Prompt copied!")
        }, modifier = Modifier.fillMaxWidth()) { AppIcon(AppIcons.Copy, null); Spacer(Modifier.width(8.dp)); Text("Copy AI Prompt") }
        Button(onClick = { select.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }, modifier = Modifier.fillMaxWidth()) {
            AppIcon(AppIcons.Folder, null); Spacer(Modifier.width(8.dp)); Text("Select JSON File")
        }
    }
}
