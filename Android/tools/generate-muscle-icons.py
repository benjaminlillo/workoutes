"""Generate the same MIT muscle masks as iOS as native Android vectors.
Uses the shared source paths and crop definitions; no rasterization or SF Symbols.
"""
from pathlib import Path
import ast, json, html
root=Path(__file__).resolve().parents[2]
source=(root/'tools/muscle-icons/generate.py').read_text()
# Read the declarative constants without importing the PDF generator's dependencies.
env={}
for node in ast.parse(source).body:
    if isinstance(node,ast.Assign) and isinstance(node.targets[0],ast.Name) and node.targets[0].id in ['TRUNK','MUSCLES','FRONT','BACK','ICONS']:
        env[node.targets[0].id]=eval(compile(ast.Expression(node.value),'<icon constants>','eval'),{'__builtins__':{}},env)
data=json.loads((root/'tools/muscle-icons/body-paths.json').read_text())
res=root/'Android/app/src/main/res/drawable'
def resource(name):
    import re
    return re.sub(r'(?<!^)(?=[A-Z])','_',name).lower()
def normalize_path(path):
    # SVG packs arc flags as e.g. "01.08.73". The Android framework parser
    # needs these as separate numeric arguments, even though Compose accepts them.
    import re
    number=re.compile(r"[-+]?(?:[0-9]*\.[0-9]+|[0-9]+\.?)(?:[eE][-+]?[0-9]+)?")
    i=0;command=None;argument=0;result=[]
    while i<len(path):
        if path[i].isspace() or path[i]==',':i+=1;continue
        if path[i].isalpha():
            command=path[i];argument=0;result.append(command);i+=1;continue
        if command in ['A','a'] and argument%7 in [3,4]:
            assert path[i] in '01',(path,i)
            result.append(path[i]);i+=1
        else:
            match=number.match(path,i)
            assert match,(path,i)
            result.append(match.group());i=match.end()
        argument+=1
    return ' '.join(result)

for name,(side,box,selected,family) in env['ICONS'].items():
    for highlight in [False,True]:
        stroke=12 if highlight else 20
        if highlight and name=='abductors':paths=[data['back']['gluteal'][i] for i in [0,2]]
        elif highlight: paths=[d for n in selected for d in data[side].get(n,[])]
        elif family=='legs': paths=['M255 645Q300 630 350 650L340 850Q325 920 320 980L307 1240Q286 1250 267 1238L253 1100Q245 1030 260 970Q246 900 240 800Z M380 650Q425 630 475 645L490 800Q484 900 470 970Q485 1030 477 1100L463 1238Q444 1250 423 1240L410 980Q405 920 390 850Z']
        else:
            names=env['TRUNK'] if family=='trunk' else ['deltoids','biceps','triceps','forearm','hands'] if family=='arm' else data[side].keys()
            paths=[d for n in names for d in data[side].get(n,[])]
        x,y,w,h=box;scale=min(28/w,28/h);tx=(32-w*scale)/2-x*scale;ty=(32-h*scale)/2-y*scale
        if not highlight and family=='legs':tx+=(724 if side=='back' else 0)*scale;stroke=0
        clip_left=(32-w*scale)/2;clip_top=(32-h*scale)/2
        clip_right=32-clip_left;clip_bottom=32-clip_top
        ps='\n'.join(f'<path android:fillColor="#FF000000" android:strokeColor="#FF000000" android:strokeWidth="{stroke}" android:strokeLineJoin="round" android:pathData="{html.escape(normalize_path(d),quote=True)}"/>' for d in paths)
        xml=f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Same muscle source and crop as iOS. MIT: assets/licenses/muscle-icons.txt -->
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="32dp" android:height="32dp" android:viewportWidth="32" android:viewportHeight="32">
<group><clip-path android:pathData="M{clip_left} {clip_top}H{clip_right}V{clip_bottom}H{clip_left}Z"/>
<group android:translateX="{tx}" android:translateY="{ty}" android:scaleX="{scale}" android:scaleY="{scale}">{ps}</group></group></vector>'''
        (res/f'muscle_{resource(name)}_{"highlight" if highlight else "base"}.xml').write_text(xml)
(root/'Android/app/src/main/assets/licenses/muscle-icons.txt').write_text((root/'Workoutes/Shared/MuscleIcons-LICENSE.txt').read_text())
labels={'fullBody':'Full Body','upperBody':'Upper Body','lowerBody':'Legs','upperBack':'Upper Back','lowerBack':'Lower Back'}
entries='\n'.join(f'    MuscleSymbol("{name}", "{labels.get(name,name.title())}", "'+('General' if i<5 else 'Lower Body' if i>=17 else 'Upper Body')+f'", R.drawable.muscle_{resource(name)}_base, R.drawable.muscle_{resource(name)}_highlight),' for i,name in enumerate(env['ICONS']))
(root/'Android/app/src/main/java/com/workoutes/ui/MuscleGlyph.kt').write_text('''package com.workoutes.ui

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
'''+entries+'''
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
''')
print('Generated',len(env['ICONS']),'two-layer muscle icons.')
