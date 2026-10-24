package com.workoutes.ui

import android.provider.Settings
import androidx.compose.animation.core.animate
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.nestedscroll.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job
import kotlin.math.sin
import kotlin.random.Random

internal val motivationalEmojis = listOf("💪", "🏋️", "🏃", "🤸", "🔥", "🏆")
internal val motivationalPhrases = listOf("One rep at a time.", "Small steps. Stronger you.", "Show up for yourself.", "Progress starts with movement.", "Your pace. Your progress.", "Every effort counts.", "Build strength. Build confidence.", "Consistency is your superpower.")

@Stable internal class MotivationalPull {
    var distance by mutableFloatStateOf(0f)
    var emoji by mutableStateOf<String?>(null)
    var phrase by mutableStateOf<String?>(null)
    var celebration by mutableIntStateOf(0)
    var celebrating by mutableStateOf(false)
    var didCelebrate = false
    fun reset() { distance = 0f; emoji = null; phrase = null; celebrating = false; didCelebrate = false }
}

@Composable internal fun rememberMotivationalConnection(pull: MotivationalPull, atTop: () -> Boolean): NestedScrollConnection {
    val density = LocalDensity.current
    val threshold = with(density) { 120.dp.toPx() }
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val currentAtTop by rememberUpdatedState(atTop)
    return remember(pull, threshold, haptics) {
        object : NestedScrollConnection {
            private var returning: Job? = null
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                if (source != NestedScrollSource.UserInput) return Offset.Zero
                if ((available.y > 0 && currentAtTop()) || (available.y < 0 && pull.distance > 0)) {
                    returning?.cancel()
                    val previous = pull.distance
                    pull.distance = (previous + available.y * .55f).coerceIn(0f, threshold * 2)
                    if (pull.distance > 0 && pull.emoji == null) { pull.emoji = motivationalEmojis.random(); pull.phrase = motivationalPhrases.random() }
                    if (pull.distance > threshold && !pull.celebrating && !pull.didCelebrate) {
                        pull.celebrating = true; pull.didCelebrate = true; pull.celebration++
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    }
                    return Offset(0f, if (pull.distance == 0f) -previous / .55f else available.y)
                }
                return Offset.Zero
            }
            override suspend fun onPreFling(available: Velocity): Velocity {
                if (pull.distance == 0f) return Velocity.Zero
                returning = scope.launch {
                    animate(pull.distance, 0f) { value, _ -> pull.distance = value }
                    if (!pull.celebrating) { pull.emoji = null; pull.phrase = null }
                    pull.didCelebrate = false
                }
                return available
            }
        }
    }
}

private data class Particle(val lane: Float, val size: Float, val drift: Float, val restingY: Float, val delay: Float, val duration: Float)

@Composable internal fun MotivationalBanner(pull: MotivationalPull) {
    val density = LocalDensity.current
    val height = with(density) { pull.distance.toDp() }
    val progress = (height / 120.dp).coerceIn(0f, 1f)
    if (pull.distance > 0 && pull.emoji != null) {
        // Occupy precisely the space revealed by the pull. Partial pulls clip the banner,
        // and the emoji never scales outside its own layout bounds.
        Box(Modifier.fillMaxWidth().height(height).clipToBounds().testTag("motivationalPullBanner"),
            contentAlignment = Alignment.Center) {
            Column(Modifier.padding(horizontal = 24.dp, vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(pull.emoji.orEmpty(), fontSize = 52.sp,
                    modifier = Modifier.testTag("motivationalPullEmoji").clearAndSetSemantics {}.graphicsLayer {
                        scaleX = .65f + .35f * progress; scaleY = scaleX
                    })
                Text(pull.phrase.orEmpty(), style = MaterialTheme.typography.titleSmall,
                    textAlign = TextAlign.Center, modifier = Modifier.testTag("motivationalPullPhrase"))
            }
        }
    }
}

@Composable internal fun MotivationalOverlay(pull: MotivationalPull) {
    val context = LocalContext.current
    val reduceMotion = Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    LaunchedEffect(pull.celebration, pull.celebrating) { if (pull.celebrating) {
        delay(3_000); pull.celebrating = false
        if (pull.distance == 0f) { pull.emoji = null; pull.phrase = null }
    } }
    BoxWithConstraints(Modifier.fillMaxSize().clipToBounds()) {
        val screenWidth = maxWidth
        val screenHeight = maxHeight
        if (pull.celebrating) {
            Box(Modifier.fillMaxSize().testTag("motivationalCelebration").clearAndSetSemantics {}) {
                val particles = remember(pull.celebration) {
                    val lanes = (0..23).map { (it + .15f + Random.nextFloat() * .7f) / 24 }.shuffled()
                    lanes.mapIndexed { index, lane ->
                        val delay = index / 23f * 1.15f + Random.nextFloat() * .05f
                        Particle(lane, Random.nextFloat() * 52 + 24, Random.nextFloat() * 84 - 42, Random.nextFloat() * .76f + .12f, delay,
                            1.65f + Random.nextFloat() * (minOf(2.4f, 3f - delay) - 1.65f))
                    }
                }
                var elapsed by remember(pull.celebration) { mutableFloatStateOf(0f) }
                LaunchedEffect(pull.celebration) { val start = withFrameNanos { it }; while (elapsed < 3f) { withFrameNanos { elapsed = (it - start) / 1_000_000_000f } } }
                particles.forEach { particle ->
                    val progress = ((elapsed - particle.delay) / particle.duration).coerceIn(0f, 1f)
                    Text(pull.emoji.orEmpty(), fontSize = particle.size.sp, modifier = Modifier.graphicsLayer {
                        translationX = screenWidth.toPx() * particle.lane + if (reduceMotion) 0f else sin(progress * Math.PI * 2).toFloat() * particle.drift.dp.toPx()
                        translationY = if (reduceMotion) screenHeight.toPx() * particle.restingY else screenHeight.toPx() + particle.size.dp.toPx() - (screenHeight.toPx() + particle.size.dp.toPx() * 2) * progress
                        rotationZ = if (reduceMotion) 0f else particle.drift * progress / 2
                        alpha = minOf(progress * 10, (1 - progress) * 10).coerceIn(0f, 1f)
                    })
                }
            }
        }
    }
}
