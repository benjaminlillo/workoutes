package com.workoutes.data

enum class AppTheme(val label: String, val hex: String, val secondaryHex: String, val tertiaryHex: String) {
    Indigo("Violet Aura", "6C3DD1", "B784E8", "F3DDF2"),
    ElectricRush("Electric Rush", "3D52F5", "32D5E5", "D5F66A"),
    SunsetPop("Sunset Pop", "D12D78", "FF8059", "FFD65C"),
    Ultravolt("Ultravolt", "5621B6", "B9EE4A", "F0FFD0"),
    CobaltHeat("Cobalt Heat", "1745A3", "FF985C", "FFF1CB"),
    CherryIce("Cherry Ice", "AE194F", "55D6CF", "D9FFF7"),
    MidnightGold("Midnight Gold", "1C2D50", "F6C85F", "FFF1C7");
    fun hex(dark: Boolean) = if (dark) secondaryHex else hex
    fun gradient(@Suppress("UNUSED_PARAMETER") dark: Boolean): List<String> = listOf(hex, secondaryHex, tertiaryHex)
    companion object {
        fun resolve(raw: String?): AppTheme = entries.firstOrNull { it.name.equals(raw, true) } ?: Indigo
    }
}
