@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.workoutes.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.annotation.DrawableRes
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.draw.clip
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.workoutes.data.*
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt

@Composable internal fun SummaryScreen(data: ExportData, bottomPadding: Dp, pull: MotivationalPull, unit: WeightUnit = WeightUnit.Metric) {
    var now by remember { mutableStateOf(Instant.now()) }
    LifecycleResumeEffect(Unit) { now = Instant.now(); onPauseOrDispose { pull.reset() } }
    LaunchedEffect(Unit) { while (true) { delay(60_000); now = Instant.now() } }
    DisposableEffect(Unit) { onDispose { pull.reset() } }
    val list = rememberLazyListState()
    val connection = rememberMotivationalConnection(pull) { !list.canScrollBackward }
    var selectedWeek by rememberSaveable { mutableStateOf<String?>(null) }
    var preview by remember { mutableStateOf<ExerciseCompletion?>(null) }
    val zone = ZoneId.systemDefault()
    val currentWeek = WeeklySummary.containing(emptyList(), now, zone).start
    val displayedWeek = selectedWeek?.let(java.time.LocalDate::parse)?.takeIf { it < currentWeek }
    val summary = WeeklySummary.containing(data.history.orEmpty(), displayedWeek?.atStartOfDay(zone)?.toInstant() ?: now, zone)
    fun moveWeek(amount: Long) {
        val target = summary.start.plusWeeks(amount)
        if (target <= currentWeek) selectedWeek = target.takeIf { it < currentWeek }?.toString()
    }
    Box(Modifier.fillMaxSize().clipToBounds().testTag("summaryViewport")) {
        LazyColumn(state = list, modifier = Modifier.fillMaxSize().testTag("summaryScroll").nestedScroll(connection)
            .offset { IntOffset(0, pull.distance.roundToInt()) },
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = bottomPadding),
            verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item { WeeklyChart(summary, data, now, { moveWeek(-1) }, { moveWeek(1) }, { preview = it }) }
            item {
                if (LocalDensity.current.fontScale > 1.4f) Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatisticCard("Completed Exercises", summary.total, AppIcons.CheckCircle, Modifier.fillMaxWidth())
                    StatisticCard("Active Days", summary.activeDays, AppIcons.Calendar, Modifier.fillMaxWidth())
                } else Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatisticCard("Completed Exercises", summary.total, AppIcons.CheckCircle, Modifier.weight(1f))
                    StatisticCard("Active Days", summary.activeDays, AppIcons.Calendar, Modifier.weight(1f))
                }
            }
        }
        MotivationalBanner(pull)
        MotivationalOverlay(pull)
    }
    preview?.let { CompletionPreview(it, unit) { preview = null } }
}

@Composable private fun WeeklyChart(summary: WeeklySummary, data: ExportData, now: Instant, previous: () -> Unit, next: () -> Unit, onPreview: (ExerciseCompletion) -> Unit) {
    val locale = Locale.getDefault()
    val dateFormat = remember(locale) { DateTimeFormatter.ofPattern("MMM d", locale) }
    val today = now.atZone(ZoneId.systemDefault()).toLocalDate()
    val emptyColor = MaterialTheme.colorScheme.onSurface.copy(alpha = .12f)
    val maximum = maxOf(1, summary.days.maxOf { it.completions.size })
    val exercises = data.exercises.associateBy { it.id }
    val tags = data.tags.associateBy { it.id }
    Card(shape = RoundedCornerShape(24.dp), elevation = CardDefaults.cardElevation(defaultElevation = 1.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(if (summary.start == WeeklySummary.containing(emptyList(), now).start) "This Week" else "Week of ${summary.start.format(dateFormat)}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text("${summary.start.format(dateFormat)} – ${summary.endExclusive.minusDays(1).format(dateFormat)}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                IconButton(onClick = previous) { AppIcon(AppIcons.Back, "Previous Week") }
                IconButton(onClick = next, enabled = summary.start < WeeklySummary.containing(emptyList(), now).start) { AppIcon(AppIcons.Forward, "Next Week") }
            }
            Row(Modifier.fillMaxWidth().testTag("weeklyExerciseChart"), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Bottom) {
                summary.days.forEach { day ->
                    Column(Modifier.weight(1f).semantics {
                        contentDescription = day.date.format(DateTimeFormatter.ofPattern("EEEE, MMMM d", locale))
                        stateDescription = "${day.completions.size} completed exercises. " + day.completions.joinToString(", ") { exercises[it.exerciseID]?.title ?: "Exercise deleted" }
                    }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("${day.completions.size}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        val chartHeight = 190.dp * LocalDensity.current.fontScale
                        val gap = minOf(2.dp, chartHeight / maximum * .12f)
                        val blockHeight = (chartHeight - gap * (maximum - 1)) / maximum
                        Column(Modifier.fillMaxWidth().height(chartHeight), verticalArrangement = Arrangement.spacedBy(gap, Alignment.Bottom)) {
                            if (day.completions.isEmpty()) Box(Modifier.fillMaxWidth().height(3.dp).background(emptyColor, RoundedCornerShape(2.dp)))
                            day.completions.asReversed().forEach { completion ->
                                val colors = exercises[completion.exerciseID]?.tags.orEmpty().mapNotNull { tags[it.id]?.colorHex }.map(::hexColor).ifEmpty { listOf(Color.Gray.copy(alpha = .5f)) }
                                Row(Modifier.fillMaxWidth().height(blockHeight).clip(RoundedCornerShape(4.dp))
                                    .testTag("weeklyExerciseBlock.${completion.id}").combinedClickable(onClick = { onPreview(completion) }, onLongClick = { onPreview(completion) })
                                    .semantics { contentDescription = completion.snapshot?.title ?: exercises[completion.exerciseID]?.title ?: "Exercise deleted"; stateDescription = completionDate(completion) }) {
                                    colors.forEach { color -> Box(Modifier.weight(1f).fillMaxHeight().background(color)) }
                                }
                            }
                        }
                        Text(day.date.format(DateTimeFormatter.ofPattern("EEEEE", locale)), style = MaterialTheme.typography.labelSmall,
                            fontWeight = if (day.date == today) FontWeight.Bold else FontWeight.Normal,
                            color = if (day.date == today) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            Text(if (summary.total == 0) (if (summary.start == WeeklySummary.containing(emptyList(), now).start) "No completed exercises this week. Start an exercise and stop after more than 10 seconds to record it." else "No completed exercises this week.")
                else "Each block is one completed exercise. Colors follow its current tags.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable private fun StatisticCard(title: String, value: Int, @DrawableRes icon: Int, modifier: Modifier) {
    Card(modifier.aspectRatio(1f).semantics(mergeDescendants = true) {}, shape = RoundedCornerShape(24.dp), elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            AppIcon(icon, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("$value", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
            Text(title, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
