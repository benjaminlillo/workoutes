package com.workoutes.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import com.workoutes.R
import com.workoutes.data.Tag

internal data class MuscleSymbol(val name: String, val label: String, val group: String, val base: Int, val highlight: Int)
internal val muscleSymbols = listOf(
    MuscleSymbol("fullBody", "Full Body", "General", R.drawable.muscle_full_body_base, R.drawable.muscle_full_body_highlight),
    MuscleSymbol("upperBody", "Upper Body", "General", R.drawable.muscle_upper_body_base, R.drawable.muscle_upper_body_highlight),
    MuscleSymbol("lowerBody", "Legs", "General", R.drawable.muscle_lower_body_base, R.drawable.muscle_lower_body_highlight),
    MuscleSymbol("arms", "Arms", "General", R.drawable.muscle_arms_base, R.drawable.muscle_arms_highlight),
    MuscleSymbol("core", "Core", "General", R.drawable.muscle_core_base, R.drawable.muscle_core_highlight),
    MuscleSymbol("chest", "Chest", "Upper Body", R.drawable.muscle_chest_base, R.drawable.muscle_chest_highlight),
    MuscleSymbol("back", "Back", "Upper Body", R.drawable.muscle_back_base, R.drawable.muscle_back_highlight),
    MuscleSymbol("shoulders", "Shoulders", "Upper Body", R.drawable.muscle_shoulders_base, R.drawable.muscle_shoulders_highlight),
    MuscleSymbol("biceps", "Biceps", "Upper Body", R.drawable.muscle_biceps_base, R.drawable.muscle_biceps_highlight),
    MuscleSymbol("triceps", "Triceps", "Upper Body", R.drawable.muscle_triceps_base, R.drawable.muscle_triceps_highlight),
    MuscleSymbol("forearms", "Forearms", "Upper Body", R.drawable.muscle_forearms_base, R.drawable.muscle_forearms_highlight),
    MuscleSymbol("trapezius", "Trapezius", "Upper Body", R.drawable.muscle_trapezius_base, R.drawable.muscle_trapezius_highlight),
    MuscleSymbol("upperBack", "Upper Back", "Upper Body", R.drawable.muscle_upper_back_base, R.drawable.muscle_upper_back_highlight),
    MuscleSymbol("lowerBack", "Lower Back", "Upper Body", R.drawable.muscle_lower_back_base, R.drawable.muscle_lower_back_highlight),
    MuscleSymbol("abdominals", "Abdominals", "Upper Body", R.drawable.muscle_abdominals_base, R.drawable.muscle_abdominals_highlight),
    MuscleSymbol("obliques", "Obliques", "Upper Body", R.drawable.muscle_obliques_base, R.drawable.muscle_obliques_highlight),
    MuscleSymbol("neck", "Neck", "Upper Body", R.drawable.muscle_neck_base, R.drawable.muscle_neck_highlight),
    MuscleSymbol("glutes", "Glutes", "Lower Body", R.drawable.muscle_glutes_base, R.drawable.muscle_glutes_highlight),
    MuscleSymbol("quadriceps", "Quadriceps", "Lower Body", R.drawable.muscle_quadriceps_base, R.drawable.muscle_quadriceps_highlight),
    MuscleSymbol("hamstrings", "Hamstrings", "Lower Body", R.drawable.muscle_hamstrings_base, R.drawable.muscle_hamstrings_highlight),
    MuscleSymbol("calves", "Calves", "Lower Body", R.drawable.muscle_calves_base, R.drawable.muscle_calves_highlight),
    MuscleSymbol("adductors", "Adductors", "Lower Body", R.drawable.muscle_adductors_base, R.drawable.muscle_adductors_highlight),
    MuscleSymbol("abductors", "Abductors", "Lower Body", R.drawable.muscle_abductors_base, R.drawable.muscle_abductors_highlight),
    MuscleSymbol("tibialis", "Tibialis", "Lower Body", R.drawable.muscle_tibialis_base, R.drawable.muscle_tibialis_highlight),
)
@Composable internal fun TagGlyph(tag: Tag, modifier: Modifier = Modifier.size(24.dp), color: Color = hexColor(tag.colorHex)) {
    MuscleGlyph(tag.iconName, color, modifier.semantics { contentDescription = "Tag: ${tag.name}" })
}
@Composable internal fun MuscleGlyph(name: String?, color: Color, modifier: Modifier = Modifier.size(32.dp)) {
    val icon = muscleSymbols.firstOrNull { it.name == name }
    Box(modifier, contentAlignment = Alignment.Center) {
        if (icon == null) Box(Modifier.size(7.dp).background(color, CircleShape)) else {
            AppIcon(icon.base, null, Modifier.matchParentSize(), tint = if (isSystemInDarkTheme()) Color(.36f,.36f,.36f) else Color(.78f,.78f,.78f))
            AppIcon(icon.highlight, null, Modifier.matchParentSize(), tint = color)
        }
    }
}
