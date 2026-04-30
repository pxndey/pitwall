package com.pitcrew.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val PitCrewColorScheme = darkColorScheme(
    primary = PitCrewRed,
    onPrimary = Color.White,
    primaryContainer = PitCrewRed,
    onPrimaryContainer = Color.White,
    secondary = PitCrewCard,
    onSecondary = Color.White,
    background = PitCrewBackground,
    onBackground = Color.White,
    surface = PitCrewBackground,
    onSurface = Color.White,
    surfaceVariant = PitCrewCard,
    onSurfaceVariant = PitCrewSecondaryText,
    outline = PitCrewTertiaryText,
    error = Color(0xFFCF6679),
    onError = Color.Black,
)

@Composable
fun PitCrewTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = PitCrewColorScheme,
        typography = PitCrewTypography,
        content = content,
    )
}
