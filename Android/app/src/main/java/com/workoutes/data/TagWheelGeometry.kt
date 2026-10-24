package com.workoutes.data

import kotlin.math.*

/** Continuous turns across the atan2 seam, with shortest-path menu selection. */
class TagWheelPosition(var position: Double = 0.0) {
    private var previous: Double? = null
    fun selectedIndex(count: Int): Int = wrap(position.roundToInt(), count)
    fun drag(angle: Double, count: Int) {
        previous?.let { if (count > 1) position += atan2(sin(angle - it), cos(angle - it)) / spacing(count) }
        previous = angle
    }
    fun snap() { position = position.roundToInt().toDouble(); previous = null }
    fun select(index: Int, count: Int) {
        if (count <= 1) { position = 0.0; previous = null; return }
        position = index + ((position - index) / count).roundToInt() * count.toDouble()
        previous = null
    }
    companion object {
        fun spacing(count: Int) = 2 * PI / max(1, count)
        fun wrap(index: Int, count: Int) = if (count > 0) ((index % count) + count) % count else 0
    }
}

data class WheelBounds(val left: Float, val top: Float, val right: Float, val bottom: Float) {
    fun center(dock: WheelDock): Pair<Float, Float> {
        val fraction = dock.fraction.takeIf { it.isFinite() }?.coerceIn(0f, 1f) ?: .85f
        return when (dock.edge) {
            "leading" -> left to top + (bottom - top) * fraction
            "top" -> left + (right - left) * fraction to top
            "bottom" -> left + (right - left) * fraction to bottom
            else -> right to top + (bottom - top) * fraction
        }
    }
    fun nearest(x: Float, y: Float, preferred: String): WheelDock {
        val px = x.coerceIn(left, right); val py = y.coerceIn(top, bottom)
        val distances = linkedMapOf("leading" to px-left, "trailing" to right-px, "top" to py-top, "bottom" to bottom-py)
        val edge = (listOf(preferred) + distances.keys.filter { it != preferred }).minBy { distances[it] ?: Float.MAX_VALUE }
        val fraction = if (edge in listOf("leading", "trailing")) (py-top) / (bottom-top).coerceAtLeast(1f) else (px-left) / (right-left).coerceAtLeast(1f)
        return WheelDock(edge, fraction.coerceIn(0f, 1f))
    }
}
