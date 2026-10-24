package com.workoutes.ui

import androidx.annotation.DrawableRes
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import com.workoutes.R

// Shared Phosphor glyphs for navigation, actions, status, and previews.
internal object AppIcons {
    val Tags = R.drawable.ic_tag
    val Home = R.drawable.ic_house_fill
    val Workouts = R.drawable.ic_clipboard_text_fill
    val Settings = R.drawable.ic_gear_six_fill
    val Back = R.drawable.ic_arrow_left
    val Forward = R.drawable.ic_caret_right
    val Palette = R.drawable.ic_palette
    val Reset = R.drawable.ic_arrow_counter_clockwise
    val Add = R.drawable.ic_plus
    val Delete = R.drawable.ic_trash
    val Stop = R.drawable.ic_stop_fill
    val Completed = R.drawable.ic_check_circle_fill
    val NotStarted = R.drawable.ic_circle
    val Edit = R.drawable.ic_pencil_simple
    val Remove = R.drawable.ic_minus_circle
    val Dot = R.drawable.ic_circle_fill
    val Export = R.drawable.ic_export
    val Import = R.drawable.ic_download_simple
    val Copy = R.drawable.ic_copy_simple
    val Folder = R.drawable.ic_folder_open
    val AddCircle = R.drawable.ic_plus_circle
    val CheckCircle = R.drawable.ic_check_circle
    val Calendar = R.drawable.ic_calendar_dots
    val Photos = R.drawable.ic_images
    val Camera = R.drawable.ic_camera
    val Weight = R.drawable.ic_exercise_weight
    val Sets = R.drawable.ic_exercise_sets
    val Repetitions = R.drawable.ic_exercise_repetitions
    val Notes = R.drawable.ic_exercise_notes
    val Bump = R.drawable.ic_exercise_bump
}

@Composable internal fun AppIcon(
    @DrawableRes icon: Int, contentDescription: String?, modifier: Modifier = Modifier,
    tint: Color = LocalContentColor.current
) {
    Icon(painterResource(icon), contentDescription, modifier, tint)
}
