package com.pitwall.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val PitwallColorScheme = darkColorScheme(
    primary = PitwallRed,
    onPrimary = Color.White,
    primaryContainer = PitwallRed,
    onPrimaryContainer = Color.White,
    secondary = PitwallCard,
    onSecondary = Color.White,
    background = PitwallBackground,
    onBackground = Color.White,
    surface = PitwallBackground,
    onSurface = Color.White,
    surfaceVariant = PitwallCard,
    onSurfaceVariant = PitwallSecondaryText,
    outline = PitwallTertiaryText,
    error = Color(0xFFCF6679),
    onError = Color.Black,
)

@Composable
fun PitwallTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = PitwallColorScheme,
        typography = PitwallTypography,
        content = content,
    )
}
