@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.workoutes.ui

import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.foundation.background
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.saveable.Saver
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.workoutes.WorkoutesViewModel
import com.workoutes.ExerciseNotification
import com.workoutes.data.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString

@Serializable internal sealed interface Sheet {
    @Serializable data object NewWorkout : Sheet
    @Serializable data class EditExercise(val exercise: Exercise?, val workoutId: String?) : Sheet
    @Serializable data class EditTag(val tag: Tag?) : Sheet
    @Serializable data class Metric(val id: String, val metric: String) : Sheet
    @Serializable data class Customize(val key: String, val tagColors: List<String>) : Sheet
}
private val sheetSaver = Saver<Sheet?, String>(save = { it?.let { sheet -> workoutesJson.encodeToString(sheet) } },
    restore = { workoutesJson.decodeFromString<Sheet>(it) })
private data class Destination(val tab: Int, val workoutId: String?, val settingsPage: String?) {
    val depth: Int get() = if (workoutId != null || settingsPage != null) 1 else 0
}
internal data class Confirmation(val title: String, val message: String, val action: () -> Unit)

@Composable fun WorkoutesApp(model: WorkoutesViewModel, externalReveal: Pair<String, Int>? = null) {
    val state by model.state.collectAsStateWithLifecycle()
    val loaded by model.loaded.collectAsStateWithLifecycle()
    val message by model.message.collectAsStateWithLifecycle()
    WorkoutesTheme(state.preferences.accent) {
        var tab by rememberSaveable { mutableIntStateOf(0) }
        var workoutId by rememberSaveable { mutableStateOf<String?>(null) }
        var settingsPage by rememberSaveable { mutableStateOf<String?>(null) }
        val importing = tab == 3 && settingsPage == "import"
        var selectedTags by rememberSaveable { mutableStateOf(listOf<String>()) }
        var sheet by rememberSaveable(stateSaver = sheetSaver) { mutableStateOf<Sheet?>(null) }
        var confirmation by remember { mutableStateOf<Confirmation?>(null) }
        var showExportOptions by rememberSaveable { mutableStateOf(false) }
        val pull = remember { MotivationalPull() }
        LaunchedEffect(tab) { if (tab != 0) pull.reset() }
        val workout = if (tab == 1) state.data.workouts.firstOrNull { it.id == workoutId } else null
        var revealId by rememberSaveable { mutableStateOf<String?>(null) }
        var revealNonce by rememberSaveable { mutableIntStateOf(0) }
        fun revealActive() {
            val exercise = state.data.exercises.firstOrNull { it.id == state.activeExerciseId && !it.isDone } ?: return
            selectedTags = state.revealSelection(exercise.id, selectedTags.toSet()).toList()
            revealId = exercise.id; revealNonce++; settingsPage = null; tab = 2
        }
        LaunchedEffect(loaded, externalReveal) { if (loaded && externalReveal?.first == state.activeExerciseId) revealActive() }
        val context = LocalContext.current
        val currentState by rememberUpdatedState(state)
        val notificationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) ExerciseNotification.sync(context, currentState)
        }
        val active = state.data.exercises.firstOrNull { it.id == state.activeExerciseId && !it.isDone }
        val exercises = if (tab == 1 && workout != null) state.data.exercises.filter {
            it.workouts.any { ref -> ref.id == workout.id }
        } else state.data.exercises.sortedBy { it.title.lowercase() }.filter { exercise ->
            selectedTags.isEmpty() || exercise.tags.any { it.id in selectedTags }
        }
        val backgroundKey = workout?.id ?: "exercises"
        val backgroundTags = if (workout != null) state.data.tags.filter { tag -> exercises.any { ex -> ex.tags.any { it.id == tag.id } } }
            else state.data.tags.filter { it.id in selectedTags }
        LaunchedEffect(state.data.tags) { selectedTags = selectedTags.filter { id -> state.data.tags.any { it.id == id } } }
        val showNavigationLabels = LocalDensity.current.fontScale <= 1.3f
        val screenStateHolder = rememberSaveableStateHolder()
        val destination = Destination(tab, workout?.id, if (tab == 3) settingsPage else null)
        val goBack = { if (tab == 3) settingsPage = null else workoutId = null }
        BackHandler(destination.depth > 0, onBack = goBack)
        Box(Modifier.fillMaxSize()) {
            val hasBackground = loaded && !importing && (tab == 2 || (tab == 1 && workout != null))
            BackgroundView(if (hasBackground) state.backgrounds[backgroundKey] ?: Background() else null,
                backgroundTags.map { it.colorHex }, Modifier.matchParentSize())
            Scaffold(containerColor = Color.Transparent,
                bottomBar = {
                    Column(
                        modifier = Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.navigationBars)
                            .padding(horizontal = 20.dp).padding(bottom = 12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Row(Modifier.widthIn(max = 520.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Surface(
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(percent = 50),
                            color = MaterialTheme.colorScheme.surfaceContainer,
                            shadowElevation = 6.dp
                        ) {
                            Row(Modifier.fillMaxWidth().padding(6.dp).selectableGroup(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                listOf("Summary" to AppIcons.Home, "Workouts" to AppIcons.Workouts, "Exercises" to AppIcons.Weight,
                                    "Settings" to AppIcons.Settings).forEachIndexed { index, (label, icon) ->
                                    val selected = tab == index
                                    val indicator by animateColorAsState(if (selected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
                                        animationSpec = tween(200), label = "Tab indicator")
                                    val tint by animateColorAsState(if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                        animationSpec = tween(200), label = "Tab color")
                                    Column(Modifier.weight(1f).height(56.dp).clip(RoundedCornerShape(28.dp))
                                        .background(indicator).semantics { contentDescription = label }.selectable(selected = selected, role = Role.Tab,
                                            onClick = { tab = index; settingsPage = null }),
                                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                                        AppIcon(icon, null, Modifier.size(22.dp), tint = tint)
                                        if (showNavigationLabels) {
                                            Spacer(Modifier.height(3.dp))
                                            Text(label, color = tint, style = MaterialTheme.typography.labelSmall, fontSize = 10.sp, maxLines = 1)
                                        }
                                    }
                                }
                            }
                        }
                        Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainer, shadowElevation = 6.dp) {
                            IconButton(onClick = ::revealActive, enabled = active != null, modifier = Modifier.size(60.dp).testTag("activeExerciseShortcut")) {
                                AppIcon(AppIcons.Weight, active?.let { "Reveal ${it.title}" } ?: "No Active Exercise", Modifier.size(26.dp))
                            }
                        }
                        }
                    }
                }
            ) { outerPadding ->
                Box(Modifier.fillMaxSize()) {
                AnimatedContent(targetState = destination, modifier = Modifier.fillMaxSize(),
                    transitionSpec = {
                        val timing = tween<IntOffset>(320, easing = FastOutSlowInEasing)
                        if (initialState.tab != targetState.tab) {
                            fadeIn(tween(180)) togetherWith fadeOut(tween(120))
                        } else if (targetState.depth > initialState.depth) {
                            slideInHorizontally(timing) { it } togetherWith
                                (slideOutHorizontally(timing) { -it / 3 } + fadeOut(tween(220)))
                        } else {
                            (slideInHorizontally(timing) { -it / 3 } + fadeIn(tween(220))) togetherWith
                                slideOutHorizontally(timing) { it }
                        }.using(SizeTransform(clip = false))
                    }, label = "Screen navigation") { screen ->
                    screenStateHolder.SaveableStateProvider("${screen.tab}/${screen.workoutId}/${screen.settingsPage}") {
                        val screenTab = screen.tab
                        val screenWorkout = state.data.workouts.firstOrNull { it.id == screen.workoutId }
                        val screenExercises = if (screenWorkout != null) state.data.exercises.filter { exercise ->
                            exercise.workouts.any { it.id == screenWorkout.id }
                        } else state.data.exercises.sortedBy { it.title.lowercase() }.filter { exercise ->
                            selectedTags.isEmpty() || exercise.tags.any { it.id in selectedTags }
                        }
                        val screenBackgroundKey = screenWorkout?.id ?: "exercises"
                        val screenBackgroundTags = if (screenWorkout != null) state.data.tags.filter { tag ->
                            screenExercises.any { exercise -> exercise.tags.any { it.id == tag.id } }
                        } else state.data.tags.filter { it.id in selectedTags }
                        val title = when {
                            screen.settingsPage == "import" -> "Import Data"
                            screen.settingsPage == "theme" -> "Theme"
                            screen.settingsPage == "unit" -> "Weight Unit"
                            screen.settingsPage == "history" -> "Exercise History"
                            screenTab == 0 -> "Summary"
                            screenTab == 1 -> screenWorkout?.name ?: "Workouts"
                            screenTab == 2 -> "All Exercises"
                            else -> "Settings"
                        }
                        val scroll = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
                        Scaffold(modifier = Modifier.nestedScroll(scroll.nestedScrollConnection), containerColor = Color.Transparent,
                            topBar = {
                                LargeTopAppBar(modifier = Modifier.testTag("screenHeader"), title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                                    navigationIcon = {
                                        if (screen.depth > 0) IconButton(onClick = goBack) {
                                            AppIcon(AppIcons.Back, "Back")
                                        }
                                    }, actions = {
                                        if (loaded && screenTab in 1..2) {
                                            if (screenTab == 2 || screenWorkout != null) {
                                                IconButton(onClick = { sheet = Sheet.Customize(screenBackgroundKey, screenBackgroundTags.map { it.colorHex }) }) {
                                                    AppIcon(AppIcons.Palette, "Customize Background")
                                                }
                                                IconButton(onClick = {
                                                    val ids = if (screenWorkout != null) screenExercises.map { it.id }.toSet() else state.data.exercises.map { it.id }.toSet()
                                                    model.update { current -> current.copy(data = current.data.copy(exercises = current.data.exercises.map {
                                                        if (it.id in ids) it.copy(isDone = false) else it
                                                    })) }
                                                }) { AppIcon(AppIcons.Reset, "Reset Completed Exercises") }
                                            }
                                            IconButton(onClick = { sheet = if (screenTab == 1 && screenWorkout == null) Sheet.NewWorkout
                                                else Sheet.EditExercise(null, screenWorkout?.id) }) { AppIcon(AppIcons.Add, if (screenTab == 1 && screenWorkout == null) "Add Workout" else "Add Exercise") }
                                            if (screenTab == 2) TagToolbar(state.data.tags.sortedBy { it.name.lowercase() }, selectedTags.firstOrNull(),
                                                onSelect = { selectedTags = listOfNotNull(it) }, onAdd = { sheet = Sheet.EditTag(null) },
                                                onEdit = { sheet = Sheet.EditTag(it) }, onDelete = { tag -> confirmation = Confirmation("Delete Tag?", "Delete \"${tag.name}\"? Your exercises will be kept.") { model.update { it.deleteTag(tag.id) } } })
                                        }
                                    }, scrollBehavior = scroll,
                                    colors = TopAppBarDefaults.largeTopAppBarColors(containerColor = Color.Transparent,
                                        scrolledContainerColor = MaterialTheme.colorScheme.surface))
                            }
                        ) { padding ->
                            // Content scrolls behind the floating controls; list end padding keeps the last item reachable.
                            val bottomPadding = outerPadding.calculateBottomPadding() + 20.dp
                            Box(Modifier.fillMaxSize().padding(top = padding.calculateTopPadding())) {
                                when {
                                    !loaded -> Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                                        if (message == null) CircularProgressIndicator() else Text("Saved data is unavailable. Reopen the app to retry.")
                                    }
                                    screen.settingsPage == "import" -> ImportScreen(model, bottomPadding, onSuccess = { settingsPage = null })
                                    screen.settingsPage == "theme" -> ThemeSelectionScreen(state.preferences, model, bottomPadding)
                                    screen.settingsPage == "history" -> HistoryScreen(state, model, bottomPadding)
                                    screen.settingsPage != null -> PreferenceScreen(screen.settingsPage, state.preferences, model, bottomPadding)
                                    screenTab == 0 -> SummaryScreen(state.data, bottomPadding, pull, state.preferences.unit)
                                    screenTab == 3 -> SettingsScreen(state.preferences, onOpen = { settingsPage = it },
                                        bottomPadding = bottomPadding,
                                        onImport = { settingsPage = "import" }, onExport = { showExportOptions = true })
                                    screenTab == 1 && screenWorkout == null -> WorkoutScreen(state.data.workouts, bottomPadding, onOpen = { workoutId = it },
                                        onDelete = { w -> confirmation = Confirmation("Delete Workout?", "Delete \"${w.name}\"? Your exercises will be kept.") {
                                            model.update { it.deleteWorkout(w.id) }
                                        } })
                                    else -> {
                                        Crossfade(targetState = if (screenTab == 2) selectedTags else emptyList(), animationSpec = tween(200), label = "Exercise filter") { filter ->
                                        val visibleExercises = if (screenTab == 2) state.data.exercises.sortedBy { it.title.lowercase() }.filter { ex -> filter.isEmpty() || ex.tags.any { it.id in filter } } else screenExercises
                                        val exerciseList = rememberLazyListState()
                                        LaunchedEffect(revealNonce, screenTab) {
                                            if (screenTab == 2 && revealNonce > 0) {
                                                val index = visibleExercises.indexOfFirst { it.id == revealId }
                                                if (index >= 0) exerciseList.animateScrollToItem(index, -120)
                                            }
                                        }
                                        LazyColumn(state = exerciseList, contentPadding = PaddingValues(top = 12.dp, bottom = bottomPadding + if (screenTab == 2) 140.dp else 0.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                                            if (visibleExercises.isEmpty()) item {
                                                EmptyState(if (selectedTags.isNotEmpty() && screenTab == 2) "No matching exercises" else "No exercises yet", "Use + to add an exercise.")
                                            }
                                            items(visibleExercises, key = { it.id }) { exercise ->
                                                ExerciseCard(exercise, state, screenWorkout?.id, revealToken = if (exercise.id == revealId && screenTab == 2) revealNonce else 0, onAdvance = {
                                                    model.update { it.advance(exercise.id) }
                                                    if (!exercise.isDone && state.activeExerciseId != exercise.id && Build.VERSION.SDK_INT >= 33 &&
                                                        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                                        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                                                    }
                                                },
                                                    onEdit = { sheet = Sheet.EditExercise(exercise, null) },
                                                    onMetric = { sheet = Sheet.Metric(exercise.id, it) },
                                                    onBump = { model.update { current -> current.data.exercises.firstOrNull { it.id == exercise.id }?.let {
                                                        current.updateExercise(it.copy(increaseLoadNextTime = !it.increaseLoadNextTime))
                                                    } ?: current } },
                                                    onRemove = { model.update { current -> current.data.exercises.firstOrNull { it.id == exercise.id }?.let {
                                                        current.updateExercise(it.copy(workouts = it.workouts.filterNot { ref -> ref.id == screenWorkout?.id }))
                                                    } ?: current } },
                                                    onDelete = { confirmation = Confirmation("Delete Permanently?", "This exercise will be removed from all workouts.") {
                                                        model.update { it.deleteExercise(exercise.id) }
                                                    } })
                                            }
                                        }
                                        }
                                    }
                                }

                            }
                        }
                    }
                }
                if (loaded && tab == 2) TagWheel(state.data.tags.sortedBy { it.name.lowercase() }, selectedTags.firstOrNull(), state.wheelDock, outerPadding.calculateBottomPadding()+20.dp,
                    onSelect = { selectedTags = listOfNotNull(it) }, onDock = { dock -> model.update { it.copy(wheelDock = dock) } },
                    onAdd = { sheet = Sheet.EditTag(null) }, onEdit = { sheet = Sheet.EditTag(it) },
                    onDelete = { tag -> confirmation = Confirmation("Delete Tag?", "Your exercises will be kept.") { model.update { it.deleteTag(tag.id) } } })
                }
            }
        }

        if (showExportOptions) {
            fun export(includeHistory: Boolean) {
                showExportOptions = false
                model.exportFile(includeHistory) { uri ->
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/json"; putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    context.startActivity(Intent.createChooser(intent, "Export Workoutes"))
                }
            }
            AlertDialog(onDismissRequest = { showExportOptions = false }, title = { Text("Include exercise history?") },
                text = { Text("Active exercise sessions are never exported.") },
                confirmButton = { TextButton(onClick = { export(true) }) { Text("Include History") } },
                dismissButton = { Column { TextButton(onClick = { export(false) }) { Text("Catalog Only") }; TextButton(onClick = { showExportOptions = false }) { Text("Cancel") } } })
        }

        sheet?.let { selected ->
            ModalBottomSheet(onDismissRequest = { sheet = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
                when (selected) {
                    Sheet.NewWorkout -> WorkoutEditor(state, model) { sheet = null }
                    is Sheet.EditExercise -> ExerciseEditor(selected.exercise, selected.workoutId, state, model) { sheet = null }
                    is Sheet.EditTag -> TagEditor(selected.tag, model) { sheet = null }
                    is Sheet.Metric -> state.data.exercises.firstOrNull { it.id == selected.id }?.let {
                        MetricEditor(it, selected.metric, state.preferences.unit, model) { sheet = null }
                    }
                    is Sheet.Customize -> BackgroundEditor(selected.key, state.backgrounds[selected.key] ?: Background(), selected.tagColors, model) { sheet = null }
                }
            }
        }
        confirmation?.let { pending -> AlertDialog(onDismissRequest = { confirmation = null },
            title = { Text(pending.title) }, text = { Text(pending.message) },
            confirmButton = { TextButton(onClick = { pending.action(); confirmation = null }) { Text("Delete", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { confirmation = null }) { Text("Cancel") } }) }
        message?.let { AlertDialog(onDismissRequest = model::dismissMessage, title = { Text("Workoutes") },
            text = { Text(it) }, confirmButton = { TextButton(onClick = model::dismissMessage) { Text("OK") } }) }
    }
}

@Composable private fun WorkoutScreen(workouts: List<Workout>, bottomPadding: Dp, onOpen: (String) -> Unit, onDelete: (Workout) -> Unit) {
    LazyColumn(contentPadding = PaddingValues(start = 16.dp, top = 16.dp, end = 16.dp, bottom = bottomPadding), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        if (workouts.isEmpty()) item { EmptyState("No workouts yet", "Use + to create your first workout.") }
        items(workouts, key = { it.id }) { workout ->
            Card(onClick = { onOpen(workout.id) }, shape = RoundedCornerShape(18.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Row(Modifier.fillMaxWidth().padding(start = 16.dp, top = 12.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(workout.name, Modifier.weight(1f), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    IconButton(onClick = { onDelete(workout) }) { AppIcon(AppIcons.Delete, "Delete ${workout.name}") }
                    AppIcon(AppIcons.Forward, null, Modifier.padding(end = 12.dp))
                }
            }
        }
    }
}
@Composable internal fun EmptyState(title: String, description: String) {
    Column(Modifier.fillMaxWidth().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        AppIcon(AppIcons.Weight, null, Modifier.size(44.dp), tint = MaterialTheme.colorScheme.primary)
        Text(title, style = MaterialTheme.typography.titleLarge)
        Text(description, style = MaterialTheme.typography.bodyMedium)
    }
}
