package com.workoutes.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import com.workoutes.data.AppTheme

internal val LocalAppTheme = staticCompositionLocalOf { AppTheme.Indigo }
fun hexColor(hex: String): Color {
    val raw = hex.removePrefix("#")
    val value = raw.toLongOrNull(16) ?: return Color(0xFF6C3DD1)
    return if (raw.length == 8) Color(((value and 255) shl 24) or (value ushr 8)) else Color(value or 0xFF000000)
}
@Composable fun WorkoutesTheme(accent: String, content: @Composable () -> Unit) {
    val theme = AppTheme.resolve(accent)
    val dark = isSystemInDarkTheme()
    val primary = animateColorAsState(hexColor(theme.hex(dark)), tween(450), label = "Theme accent").value
    val scheme = if (dark) darkColorScheme(
        primary = primary, onPrimary = Color(0xFF17151E), primaryContainer = primary.copy(alpha = .28f),
        onPrimaryContainer = Color.White, background = Color(0xFF111216), surface = Color(0xFF202126),
        surfaceContainer = Color(0xFF25262C), surfaceContainerLow = Color(0xFF1E1F24), surfaceContainerHigh = Color(0xFF2B2C31)
    ) else lightColorScheme(
        primary = primary, onPrimary = Color.White, primaryContainer = primary.copy(alpha = .15f),
        onPrimaryContainer = Color(0xFF132E3C), background = Color(0xFFF2F2F7), surface = Color.White,
        surfaceContainer = lerp(Color.White, primary, .035f), surfaceContainerLow = lerp(Color.White, primary, .015f), surfaceContainerHigh = lerp(Color.White, primary, .06f)
    )
    CompositionLocalProvider(LocalAppTheme provides theme, LocalContentColor provides scheme.onBackground) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
