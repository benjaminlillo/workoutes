package com.workoutes.ui

import android.content.ActivityNotFoundException
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.core.net.toUri
import com.workoutes.WorkoutesViewModel
import com.workoutes.data.*
import java.io.File

@Composable internal fun BackgroundEditor(key: String, background: Background, tagColors: List<String>, model: WorkoutesViewModel, close: () -> Unit) {
    val context = LocalContext.current
    val displayedColors = if (background.colors == defaultGradient) LocalAppTheme.current.gradient(isSystemInDarkTheme()) else background.colors
    var photoUri by rememberSaveable { mutableStateOf<String?>(null) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) model.saveWallpaper(key, uri)
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        photoUri?.let { if (success) model.saveWallpaper(key, it.toUri()) }
        photoUri = null
    }
    fun save(value: Background) { model.update { it.copy(backgrounds = it.backgrounds + (key to value)) } }
    SheetForm(if (key == "exercises") "Exercises Background" else "Workout Background", close) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            BackgroundMode.entries.forEach { mode ->
                FilterChip(selected = background.mode == mode, onClick = {
                    if (mode == BackgroundMode.Wallpaper && background.imageFile == null) picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    else save(background.copy(mode = mode))
                }, label = { Text(mode.name) })
            }
        }
        Surface(shape = RoundedCornerShape(12.dp), shadowElevation = 1.dp) {
            BackgroundView(background, tagColors, Modifier.fillMaxWidth().height(140.dp))
        }
        when (background.mode) {
            BackgroundMode.Wallpaper -> Text("The photo applies only to this screen.", style = MaterialTheme.typography.bodySmall)
            BackgroundMode.Automatic -> Text("The gradient follows the colors of the selected tags. Without tags, it uses the default gradient.")
            BackgroundMode.Gradient -> {
                Text("Soft Gradient", style = MaterialTheme.typography.titleSmall)
                displayedColors.forEachIndexed { index, color ->
                    // Keep incomplete HEX edits local; only commit valid colors.
                    var hex by remember(color) { mutableStateOf(color) }
                    ColorInput(hex) { next ->
                        hex = next
                        if (validHex(next)) save(background.copy(colors = displayedColors.toMutableList().apply { this[index] = next.removePrefix("#") }))
                    }
                    if (displayedColors.size > 1) TextButton(onClick = { save(background.copy(colors = displayedColors.filterIndexed { i, _ -> i != index })) }) {
                        Text("Remove color ${index + 1}")
                    }
                }
                if (displayedColors.size < 3) TextButton(onClick = { save(background.copy(colors = displayedColors + "F4D8BD")) }) { Text("Add Color") }
                if (background.colors == defaultGradient) Text("The default gradient follows your theme. Editing these colors customizes only this screen.", style = MaterialTheme.typography.bodySmall)
            }
        }
        OutlinedButton(onClick = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }, modifier = Modifier.fillMaxWidth()) {
            AppIcon(AppIcons.Photos, null); Spacer(Modifier.width(8.dp)); Text("Choose from Photos")
        }
        OutlinedButton(onClick = {
            try {
                val directory = File(context.cacheDir, "shared").apply { mkdirs() }
                val file = File(directory, "camera-${newId()}.jpg")
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
                photoUri = uri.toString()
                camera.launch(uri)
            } catch (_: ActivityNotFoundException) { model.report("Camera capture is unavailable on this device. Choose a photo instead.") }
        }, modifier = Modifier.fillMaxWidth()) { AppIcon(AppIcons.Camera, null); Spacer(Modifier.width(8.dp)); Text("Take Photo") }
        TextButton(onClick = { save(Background()) }, modifier = Modifier.fillMaxWidth()) { Text("Reset Background", color = MaterialTheme.colorScheme.error) }
    }
}
