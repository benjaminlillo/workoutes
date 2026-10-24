package com.workoutes

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.workoutes.data.AppTheme

internal object ThemeIconController {
    fun update(context: Context, theme: AppTheme) {
        val manager = context.packageManager
        fun component(option: AppTheme) = ComponentName(context, "${context.packageName}.Launcher${option.name}")
        fun desired(option: AppTheme) = if (option == theme) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        val changes = AppTheme.entries.filter { option ->
            val current = manager.getComponentEnabledSetting(component(option))
            val enabled = current == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                (current == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && option == AppTheme.Indigo)
            enabled != (option == theme)
        }
        // Retired aliases may have an explicit enabled state from an older install.
        manager.setComponentEnabledSetting(component(theme), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        for (retired in listOf("Primary", "Mint", "Purple", "Orange")) {
            val alias = ComponentName(context, "${context.packageName}.Launcher$retired")
            if (manager.getComponentEnabledSetting(alias) != PackageManager.COMPONENT_ENABLED_STATE_DISABLED)
                manager.setComponentEnabledSetting(alias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            if (changes.isNotEmpty()) manager.setComponentEnabledSettings(changes.map {
                PackageManager.ComponentEnabledSetting(component(it), desired(it), PackageManager.DONT_KILL_APP)
            })
        } else {
            // Always enable the destination first; the launcher must retain one entry.
            changes.sortedBy { it != theme }.forEach { manager.setComponentEnabledSetting(component(it), desired(it), PackageManager.DONT_KILL_APP) }
        }
    }
}
