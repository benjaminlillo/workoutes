@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.workoutes.ui

import android.graphics.Paint
import android.graphics.Path
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.workoutes.data.*
import kotlin.math.*

@Composable internal fun TagToolbar(tags: List<Tag>, selected: String?, onSelect: (String?) -> Unit,
    onAdd: () -> Unit, onEdit: (Tag) -> Unit, onDelete: (Tag) -> Unit) {
    var menu by remember { mutableStateOf<String?>(null) }
    Box {
        IconButton(onClick = { menu = "filter" }) { AppIcon(AppIcons.Tags, "Manage Tags", tint = MaterialTheme.colorScheme.primary) }
        DropdownMenu(expanded = menu != null, onDismissRequest = { menu = null }, modifier = Modifier.heightIn(max = 480.dp)) {
            if (menu == "filter") {
                if (tags.isNotEmpty()) Text("Filter by Tag", Modifier.padding(16.dp), style = MaterialTheme.typography.labelLarge)
                tags.forEach { tag -> DropdownMenuItem(text = { Text(tag.name) }, leadingIcon = { TagGlyph(tag) },
                    trailingIcon = { if (tag.id == selected) AppIcon(AppIcons.Completed, null, tint = MaterialTheme.colorScheme.primary) },
                    onClick = { onSelect(tag.id.takeUnless { it == selected }); menu = null }) }
                if (tags.isNotEmpty()) {
                    DropdownMenuItem(text = { Text("Deselect All Tags") }, enabled = selected != null, onClick = { onSelect(null); menu = null })
                    HorizontalDivider()
                }
                DropdownMenuItem(text = { Text("Add Tag") }, leadingIcon = { AppIcon(AppIcons.Add, null) }, onClick = { menu = null; onAdd() })
                if (tags.isNotEmpty()) {
                    DropdownMenuItem(text = { Text("Edit Tag") }, leadingIcon = { AppIcon(AppIcons.Edit, null) }, onClick = { menu = "edit" })
                    DropdownMenuItem(text = { Text("Delete Tag") }, leadingIcon = { AppIcon(AppIcons.Delete, null) }, onClick = { menu = "delete" })
                }
            } else {
                DropdownMenuItem(text = { Text("Back") }, onClick = { menu = "filter" })
                tags.forEach { tag -> DropdownMenuItem(text = { Text(tag.name) }, leadingIcon = { TagGlyph(tag) }, onClick = {
                    val action = menu; menu = null; if (action == "edit") onEdit(tag) else onDelete(tag)
                }) }
            }
        }
    }
}

/** Opaque native Compose plate; body icons orbit together with the rim inscriptions. */
@Composable internal fun TagWheel(tags: List<Tag>, selected: String?, dock: WheelDock?, bottomPadding: Dp,
    onSelect: (String?) -> Unit, onDock: (WheelDock) -> Unit, onAdd: () -> Unit,
    onEdit: (Tag) -> Unit, onDelete: (Tag) -> Unit) {
    val density = LocalDensity.current
    val haptics = LocalHapticFeedback.current
    val wheel = remember { TagWheelPosition() }
    val initialTouch = remember { mutableStateOf(Offset.Zero) }
    var position by remember { mutableFloatStateOf(0f) }
    var dragging by remember { mutableStateOf(false) }
    var localDock by remember { mutableStateOf(dock) }
    LaunchedEffect(dock) { localDock = dock }
    fun commitDock(value: WheelDock) { localDock = value; onDock(value) }
    var translation by remember { mutableStateOf(Offset.Zero) }
    var contextTag by remember { mutableStateOf<Tag?>(null) }
    val currentSelect by rememberUpdatedState(onSelect)
    val currentSelected by rememberUpdatedState(selected)
    var previousSelection by remember { mutableStateOf(selected) }
    LaunchedEffect(selected) {
        if (previousSelection != selected) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        previousSelection = selected
    }
    val animated by animateFloatAsState(position, if (dragging) androidx.compose.animation.core.snap() else spring(.86f, 450f), label = "Tag wheel rotation")
    val displayedRotation by rememberUpdatedState(animated)
    LaunchedEffect(selected, tags.map { it.id }) {
        val index = tags.indexOfFirst { it.id == selected }
        if (index >= 0 && wheel.selectedIndex(tags.size) != index) { wheel.select(index, tags.size); position = wheel.position.toFloat() }
    }
    BoxWithConstraints(Modifier.fillMaxSize().clip(androidx.compose.ui.graphics.RectangleShape)) {
        val statusInset = WindowInsets.statusBars.getTop(density)
        val bounds = with(density) {
            val inset = 34.dp.toPx()
            WheelBounds(minOf(inset, maxWidth.toPx()/2), minOf(inset+statusInset, maxHeight.toPx()/2),
                maxOf(inset, maxWidth.toPx()-inset), maxOf(inset, maxHeight.toPx()-bottomPadding.toPx()-inset))
        }
        val stored = localDock ?: WheelDock("trailing", .94f)
        val centerPair = bounds.center(stored)
        val center = Offset(centerPair.first, centerPair.second) + translation
        val diameter = 233.dp
        val radius = with(density) { diameter.toPx()/2 }
        val reference = when (stored.edge) {
            "leading" -> if (stored.fraction < .5f) PI/4 else -PI/4
            "top" -> if (stored.fraction < .5f) PI/4 else 3*PI/4
            "bottom" -> if (stored.fraction < .5f) -PI/4 else -3*PI/4
            else -> if (stored.fraction < .5f) 3*PI/4 else -3*PI/4
        }
        val surface = MaterialTheme.colorScheme.surfaceContainerHigh
        val neutral = MaterialTheme.colorScheme.onSurfaceVariant
        val fraction = with(density) { 69.dp.toPx() }
        Box(Modifier.offset { IntOffset((center.x-radius).roundToInt(), (center.y-radius).roundToInt()) }.size(diameter)
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent(PointerEventPass.Initial)
                        event.changes.firstOrNull { it.pressed && !it.previousPressed }?.let { initialTouch.value = it.position }
                    }
                }
            }
            .pointerInput(tags.map { it.id }, reference, stored) {
                var moving = false; var rotating = false; var origin = Offset.Zero; var startAngle = 0.0
                detectDragGestures(onDragStart = {
                    // Classify the initial touch, before a fast drag crosses the hub boundary.
                    val start = initialTouch.value
                    origin = start-Offset(radius,radius); moving = origin.getDistance() < with(density) { 35.dp.toPx() }
                    startAngle = atan2(origin.y.toDouble(), origin.x.toDouble()); rotating = false; dragging = true
                }, onDrag = { change, delta ->
                    change.consume()
                    if (moving) translation += delta else {
                        val relative = change.position-Offset(radius,radius)
                        val angle = atan2(relative.y.toDouble(),relative.x.toDouble())
                        if (!rotating && abs(atan2(sin(angle-startAngle),cos(angle-startAngle))) * origin.getDistance() > abs(relative.getDistance()-origin.getDistance())) {
                            rotating = true; wheel.drag(startAngle,tags.size)
                        }
                        if (rotating) { wheel.drag(angle,tags.size); position = wheel.position.toFloat()
                            if (currentSelected != null && tags.isNotEmpty()) currentSelect(tags[wheel.selectedIndex(tags.size)].id) }
                    }
                }, onDragEnd = {
                    if (moving) { commitDock(bounds.nearest(centerPair.first+translation.x,centerPair.second+translation.y,stored.edge)); translation = Offset.Zero }
                    else if (rotating && tags.isNotEmpty()) { wheel.snap(); position=wheel.position.toFloat(); currentSelect(tags[wheel.selectedIndex(tags.size)].id) }
                    dragging = false
                }, onDragCancel = { translation=Offset.Zero; wheel.snap(); position=wheel.position.toFloat(); dragging=false })
            }
            .testTag("tag-wheel").semantics {
                contentDescription = "Filter by Tag"; stateDescription = tags.firstOrNull { it.id == selected }?.name ?: "No Tag Selected"
                customActions = listOf(CustomAccessibilityAction("Deselect All Tags") { onSelect(null); true },
                    CustomAccessibilityAction("Add Tag") { onAdd(); true }) + listOf("leading", "trailing", "top", "bottom").map { edge ->
                    CustomAccessibilityAction("Move Wheel to ${when(edge) {"leading" -> "Left"; "trailing" -> "Right"; else -> edge.replaceFirstChar { it.uppercase() }}} Edge") { commitDock(WheelDock(edge, stored.fraction)); true }
                } + listOf(-1 to "Previous Tag", 1 to "Next Tag").map { (step, label) -> CustomAccessibilityAction(label) {
                    if (tags.isNotEmpty()) onSelect(tags[TagWheelPosition.wrap(tags.indexOfFirst { it.id == selected }.coerceAtLeast(0)+step, tags.size)].id); true
                } }
            }) {
            Canvas(Modifier.matchParentSize().pointerInput(tags.map { it.id }, reference) {
                detectTapGestures { point ->
                    val relative = point-Offset(radius,radius)
                    if (relative.getDistance() >= with(density) { 35.dp.toPx() }) {
                        if (tags.isEmpty()) onAdd() else {
                            val angle=atan2(relative.y.toDouble(),relative.x.toDouble())
                            val target=displayedRotation+(reference-angle)/TagWheelPosition.spacing(tags.size)
                            val index=TagWheelPosition.wrap(target.roundToInt(),tags.size)
                            currentSelect(tags[index].id.takeUnless { it==currentSelected })
                            wheel.select(index,tags.size);position=wheel.position.toFloat()
                        }
                    }
                }
            }) {
                drawCircle(surface.copy(alpha = .97f))
                drawCircle(neutral.copy(alpha=.12f), style=Stroke(1.dp.toPx()))
                drawCircle(neutral.copy(alpha=.09f), radius=size.minDimension/2-4.dp.toPx(), style=Stroke(1.dp.toPx()))
                tags.forEachIndexed { index, tag ->
                    val angle = reference-(index-animated)*TagWheelPosition.spacing(tags.size)
                    val path = Path().apply { val r = size.minDimension/2-9.dp.toPx();
                        addArc(size.width/2-r,size.height/2-r,size.width/2+r,size.height/2+r, (angle*180/PI-minOf(80.0,360.0/maxOf(1,tags.size)*.82)/2).toFloat(),minOf(80.0,360.0/maxOf(1,tags.size)*.82).toFloat()) }
                    val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize=9.dp.toPx(); textAlign=Paint.Align.CENTER; color=(if (tag.id==selected) hexColor(tag.colorHex) else neutral).toArgb() }
                    drawContext.canvas.nativeCanvas.drawTextOnPath(tag.name.take(20),path,0f,0f,paint)
                }
                val hub=23.dp.toPx()
                drawCircle(Brush.sweepGradient(listOf(Color(.92f,.93f,.94f),Color(.68f,.69f,.70f),Color(.96f,.97f,.98f),Color(.78f,.79f,.80f),Color(.98f,.99f,1f),Color(.71f,.72f,.73f),Color(.92f,.93f,.94f))),hub)
                for (ring in 4..21 step 2) drawCircle(Color.Black.copy(alpha=.07f),ring.dp.toPx(),style=Stroke(.3.dp.toPx()))
                drawCircle(Color.White.copy(alpha=.65f),hub-1.dp.toPx(),style=Stroke(.65.dp.toPx()))
            }
            Box(Modifier.align(Alignment.Center).size(56.dp).testTag("tag-wheel-hub").semantics { contentDescription = "Move Tag Wheel" })
            tags.forEachIndexed { index, tag ->
                val angle=reference-(index-animated)*TagWheelPosition.spacing(tags.size)
                val available = if (tags.size<=2) 1f else ((2*sin(PI/tags.size)*69-8)/48).toFloat().coerceIn(.42f,1f)
                Box(Modifier.offset { IntOffset((radius+cos(angle)*fraction-with(density){25.dp.toPx()}).roundToInt(),(radius+sin(angle)*fraction-with(density){25.dp.toPx()}).roundToInt()) }
                    .size(50.dp).clip(CircleShape).combinedClickable(onClick = {
                        onSelect(tag.id.takeUnless { it==selected }); wheel.select(index,tags.size); position=wheel.position.toFloat()
                    }, onLongClick = { contextTag=tag }).testTag("tag-wheel-option.${tag.id}").semantics { this.selected = tag.id==selected; contentDescription=tag.name }, contentAlignment=Alignment.Center) {
                    TagGlyph(tag, Modifier.size((if(tag.iconName==null) 20.dp else 36.dp)*available), color=if(tag.id==selected) hexColor(tag.colorHex) else neutral.copy(alpha=if(selected==null) .65f else 1f))
                }
            }
            if(tags.isEmpty()) TextButton(onClick=onAdd, modifier=Modifier.align(Alignment.TopStart).padding(34.dp)) { Text("+") }
        }
    }
    contextTag?.let { tag -> AlertDialog(onDismissRequest={ contextTag=null }, title={ Text(tag.name) },
        confirmButton={ TextButton(onClick={ contextTag=null; onEdit(tag) }) { Text("Edit Tag") } },
        dismissButton={ TextButton(onClick={ contextTag=null; onDelete(tag) }) { Text("Delete Tag",color=MaterialTheme.colorScheme.error) } }) }
}
