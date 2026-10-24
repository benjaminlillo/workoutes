package com.workoutes.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.workoutes.WorkoutesViewModel
import com.workoutes.data.*
import kotlinx.coroutines.launch
import kotlin.math.absoluteValue

@Composable internal fun ThemeSelectionScreen(preferences: Preferences, model: WorkoutesViewModel, bottomPadding: Dp) {
    val selected = AppTheme.resolve(preferences.accent)
    val pager = rememberPagerState(initialPage = selected.ordinal) { AppTheme.entries.size }
    val scope = rememberCoroutineScope()
    val dark = isSystemInDarkTheme()
    val fontScale = LocalDensity.current.fontScale
    BoxWithConstraints(Modifier.fillMaxSize().padding(bottom = bottomPadding)) {
        val screenWidth = maxWidth
        val labelSpace = if (fontScale > 1.4f) 120.dp else 72.dp
        val width = minOf(maxWidth * .72f, (maxHeight - labelSpace - 56.dp) * (140f / 272f)).coerceAtLeast(80.dp)
        Column(Modifier.align(Alignment.Center).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            HorizontalPager(state = pager, pageSize = PageSize.Fixed(width), contentPadding = PaddingValues(horizontal = (screenWidth - width) / 2),
                pageSpacing = -width * .18f, modifier = Modifier.fillMaxWidth().testTag("themeCarousel"), key = { AppTheme.entries[it].name }) { page ->
                val theme = AppTheme.entries[page]
                val accent = hexColor(theme.hex(dark))
                val isSelected = theme == selected
                val offset = ((pager.currentPage - page) + pager.currentPageOffsetFraction).absoluteValue.coerceAtMost(1f)
                Column(Modifier.width(width).zIndex(1 - offset).graphicsLayer { scaleX = 1 - offset * .14f; scaleY = scaleX }
                    .selectable(isSelected, role = Role.RadioButton, interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = {
                        model.update { it.copy(preferences = it.preferences.copy(accent = theme.name)) }
                        scope.launch { pager.animateScrollToPage(page) }
                    }).testTag("themeOption.${theme.name}").semantics(mergeDescendants = true) { contentDescription = theme.label },
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Box(Modifier.padding(8.dp)) {
                        ThemeExercisePreview(theme, Modifier.fillMaxWidth().aspectRatio(140f / 272f).shadow(1.dp, RoundedCornerShape(26.dp)).clip(RoundedCornerShape(26.dp)))
                    }
                    Row(Modifier.heightIn(min = labelSpace - 16.dp).padding(horizontal = 4.dp), horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.Top) {
                        AppIcon(AppIcons.Completed, null, tint = if (isSelected) accent else androidx.compose.ui.graphics.Color.Transparent, modifier = Modifier.size(20.dp))
                        Text(theme.label, style = MaterialTheme.typography.titleMedium, fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal)
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.clearAndSetSemantics {}) {
                AppTheme.entries.forEach { theme -> Box(Modifier.size(6.dp).background(MaterialTheme.colorScheme.onSurface.copy(alpha = if (theme.ordinal == pager.currentPage) .7f else .18f), CircleShape)) }
            }
        }
    }
}

@Composable private fun ThemeExercisePreview(theme: AppTheme, modifier: Modifier) {
    val accent = hexColor(theme.hex(isSystemInDarkTheme()))
    BoxWithConstraints(modifier.clearAndSetSemantics {}) {
        ThemeBackground(theme, modifier = Modifier.matchParentSize())
        val scale = maxWidth / 140.dp
        Column(Modifier.fillMaxSize().padding(10.dp * scale), verticalArrangement = Arrangement.spacedBy(10.dp * scale)) {
            Row(Modifier.fillMaxWidth().height(25.dp * scale), verticalAlignment = Alignment.Bottom) {
                Box(Modifier.width(61.dp * scale).height(7.dp * scale).background(MaterialTheme.colorScheme.onSurface.copy(alpha = .18f), RoundedCornerShape(3.dp)))
                Spacer(Modifier.weight(1f))
                AppIcon(AppIcons.Add, null, Modifier.size(12.dp * scale), tint = accent)
            }
            repeat(3) {
                Surface(shape = RoundedCornerShape(10.dp * scale), color = MaterialTheme.colorScheme.surface, border = androidx.compose.foundation.BorderStroke(.5.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = .1f))) {
                    Box(Modifier.fillMaxWidth().height(51.dp * scale)) {
                        AppIcon(AppIcons.Completed, null, Modifier.align(Alignment.TopEnd).padding(5.dp * scale).size(16.dp * scale), tint = accent)
                    }
                }
            }
            Spacer(Modifier.weight(1f))
            Row(Modifier.fillMaxWidth().height(25.dp * scale).background(MaterialTheme.colorScheme.onSurface.copy(alpha = .05f), CircleShape), verticalAlignment = Alignment.CenterVertically) {
                listOf(AppIcons.Home, AppIcons.Workouts, AppIcons.Weight, AppIcons.Settings).forEachIndexed { index, icon ->
                    AppIcon(icon, null, Modifier.weight(1f).size(12.dp * scale), tint = if (index == 2) accent else MaterialTheme.colorScheme.onSurface.copy(alpha = .35f))
                }
            }
        }
    }
}
