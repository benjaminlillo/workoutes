package com.workoutes.ui

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.foundation.Image
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.painter.Painter
import coil.compose.AsyncImagePainter
import coil.request.ImageRequest
import coil.size.Size
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.platform.LocalContext
import coil.compose.rememberAsyncImagePainter
import com.workoutes.data.*
import java.io.File

private data class BackgroundFrame(val background: Background?, val colors: List<String>, val theme: AppTheme, val dark: Boolean, val image: Painter? = null)

@Composable fun BackgroundView(background: Background?, tagColors: List<String>, modifier: Modifier = Modifier) {
    val effectiveColors = if (background?.mode == BackgroundMode.Automatic) tagColors else emptyList()
    val context = LocalContext.current
    val theme = LocalAppTheme.current
    val dark = isSystemInDarkTheme()
    val imageRequest = remember(background?.imageFile, context) {
        background?.imageFile?.let { filename ->
            ImageRequest.Builder(context).data(File(context.filesDir, filename)).size(Size.ORIGINAL).build()
        }
    }
    val imagePainter = if (background?.mode == BackgroundMode.Wallpaper && imageRequest != null)
        rememberAsyncImagePainter(imageRequest) else null
    val imageState = imagePainter?.state
    var displayed by remember { mutableStateOf(BackgroundFrame(null, emptyList(), theme, dark)) }
    LaunchedEffect(background, effectiveColors, imageState, theme, dark) {
        // Hold the previous frame while a new wallpaper decodes, then fade the ready image in.
        if (imagePainter == null || imageState is AsyncImagePainter.State.Success || imageState is AsyncImagePainter.State.Error) {
            displayed = BackgroundFrame(background, effectiveColors, theme, dark, (imageState as? AsyncImagePainter.State.Success)?.painter)
        }
    }
    Crossfade(targetState = displayed, modifier = modifier,
        animationSpec = tween(450), label = "Background transition") { frame ->
        val current = frame.background
        if (current == null || (current.mode == BackgroundMode.Gradient && current.colors == defaultGradient) ||
            (current.mode == BackgroundMode.Automatic && frame.colors.isEmpty()) ||
            (current.mode == BackgroundMode.Wallpaper && frame.image == null)) {
            ThemeBackground(frame.theme, Modifier.fillMaxSize(), frame.dark)
        } else BackgroundLayer(current, frame.colors, frame.image, frame.dark, Modifier.fillMaxSize())
    }
}

@Composable internal fun ThemeBackground(theme: AppTheme, modifier: Modifier = Modifier, dark: Boolean = isSystemInDarkTheme()) {
    AtmosphericGradient(theme.gradient(dark), dark, modifier)
}

@Composable private fun AtmosphericGradient(colors: List<String>, dark: Boolean, modifier: Modifier) {
    val grain = androidx.compose.ui.graphics.ImageBitmap.imageResource(com.workoutes.R.drawable.background_film_grain)
    val texture = remember(grain) { androidx.compose.ui.graphics.ShaderBrush(
        androidx.compose.ui.graphics.ImageShader(grain, androidx.compose.ui.graphics.TileMode.Repeated, androidx.compose.ui.graphics.TileMode.Repeated)) }
    val palette = (0..2).map { hexColor(colors.ifEmpty { AppTheme.Indigo.gradient(dark) }[minOf(it, colors.ifEmpty { AppTheme.Indigo.gradient(dark) }.lastIndex)]) }
    Canvas(modifier) {
        drawRect(if (dark) Color(0xFF090A0E) else Color.White)
        drawRect(Brush.verticalGradient(listOf(palette[2].copy(alpha = if (dark) .4f else .8f),
            palette[1].copy(alpha = if (dark) .26f else .48f), palette[0].copy(alpha = if (dark) .48f else .64f))))
        val radius = maxOf(size.width * 1.05f, size.height * .65f)
        fun field(color: Color, x: Float, y: Float, scale: Float, opacity: Float) {
            drawRect(Brush.radialGradient(0f to color.copy(alpha = opacity), .35f to color.copy(alpha = opacity * .65f),
                .75f to color.copy(alpha = opacity * .15f), 1f to color.copy(alpha = 0f), center = Offset(size.width * x, size.height * y), radius = radius * scale))
        }
        field(palette[1], -.12f, .12f, 1f, if (dark) .36f else .48f)
        field(palette[2], 1.05f, .25f, .85f, if (dark) .22f else .5f)
        field(palette[0], -.08f, 1.02f, .9f, if (dark) .5f else .48f)
        field(palette[1], 1.1f, .8f, .75f, if (dark) .2f else .38f)
        drawRect(texture, alpha = .4f, blendMode = androidx.compose.ui.graphics.BlendMode.Overlay)
    }
}

@Composable private fun BackgroundLayer(background: Background, tagColors: List<String>, image: Painter?, dark: Boolean, modifier: Modifier) {
    if (background.mode == BackgroundMode.Wallpaper && image != null) {
        Image(image, contentDescription = null, modifier = modifier, contentScale = ContentScale.Crop)
    } else {
        val colors = if (background.mode == BackgroundMode.Automatic) tagColors.ifEmpty { defaultGradient }
            else background.colors.ifEmpty { defaultGradient }
        AtmosphericGradient(colors, dark, modifier)
    }
}
