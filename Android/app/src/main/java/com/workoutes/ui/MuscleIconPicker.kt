package com.workoutes.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp

@Composable internal fun MuscleIconPicker(selected: String?, color: Color, onChoose: (String?) -> Unit, onDismiss: () -> Unit) {
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Muscle Icon") }, text = {
        LazyColumn(Modifier.heightIn(max = 440.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item { TextButton(onClick = { onChoose(null) }) { Text("None (Color Only)") } }
            muscleSymbols.groupBy { it.group }.forEach { (group, icons) ->
                item { Text(group, style = MaterialTheme.typography.titleSmall) }
                items(icons.chunked(3)) { row ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        row.forEach { icon ->
                            Column(Modifier.weight(1f).clickable { onChoose(icon.name) }.semantics {
                                contentDescription = "Muscle: ${icon.label}"; this.selected = selected == icon.name
                            }.padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                MuscleGlyph(icon.name, color, Modifier.size(40.dp))
                                Text(icon.label, style = MaterialTheme.typography.labelSmall)
                            }
                        }
                        repeat(3-row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }, confirmButton = { TextButton(onClick = onDismiss) { Text("Done") } })
}
