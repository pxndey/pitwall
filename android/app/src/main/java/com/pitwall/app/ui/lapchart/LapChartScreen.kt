package com.pitwall.app.ui.lapchart

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pitwall.app.ui.components.ErrorState
import com.pitwall.app.ui.components.LoadingIndicator
import com.pitwall.app.ui.theme.*

@Composable
fun LapChartScreen(
    season: Int,
    round: Int,
    raceName: String,
    onBack: () -> Unit,
    viewModel: LapChartViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(season, round) { viewModel.loadLaps(season, round) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PitwallBackground),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                }
                Spacer(modifier = Modifier.width(4.dp))
                Column {
                    Text("Lap Chart", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Text(raceName, color = PitwallSecondaryText, fontSize = 13.sp)
                }
            }

            when {
                uiState.isLoading -> LoadingIndicator()
                uiState.errorMessage != null -> ErrorState(message = uiState.errorMessage!!, onRetry = { viewModel.loadLaps(season, round) })
                uiState.lapData.isEmpty() -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("No lap data available", color = PitwallTertiaryText, fontSize = 14.sp)
                    }
                }
                else -> {
                    // Driver filter chips
                    LazyRow(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        items(uiState.drivers) { driverId ->
                            val isVisible = uiState.visibleDrivers.contains(driverId)
                            val colorIndex = uiState.drivers.indexOf(driverId)
                            val chipColor = if (colorIndex < ChartColors.size) ChartColors[colorIndex] else ChartFallback

                            FilterChip(
                                selected = isVisible,
                                onClick = { viewModel.toggleDriver(driverId) },
                                label = { Text(driverId.uppercase().take(3), fontSize = 11.sp) },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = chipColor.copy(alpha = 0.3f),
                                    selectedLabelColor = chipColor,
                                    containerColor = PitwallCard,
                                    labelColor = PitwallTertiaryText,
                                ),
                                border = FilterChipDefaults.filterChipBorder(
                                    borderColor = if (isVisible) chipColor else Color.Transparent,
                                    selectedBorderColor = chipColor,
                                    enabled = true,
                                    selected = isVisible,
                                ),
                            )
                        }
                    }

                    // Chart
                    val maxLap = uiState.lapData.maxOfOrNull { it.lap } ?: 1
                    val maxPos = 20
                    val chartWidth = (maxLap * 14).coerceAtLeast(400)

                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                            .horizontalScroll(rememberScrollState()),
                    ) {
                        Canvas(
                            modifier = Modifier
                                .width(chartWidth.dp)
                                .fillMaxHeight()
                                .padding(start = 32.dp, end = 16.dp, top = 16.dp, bottom = 32.dp),
                        ) {
                            val plotWidth = size.width
                            val plotHeight = size.height

                            // Grid lines
                            for (p in 1..maxPos) {
                                val y = (p.toFloat() / maxPos) * plotHeight
                                drawLine(
                                    color = Color.White.copy(alpha = 0.05f),
                                    start = Offset(0f, y),
                                    end = Offset(plotWidth, y),
                                    strokeWidth = 1f,
                                )
                            }

                            // Draw lines for each visible driver
                            uiState.visibleDrivers.forEach { driverId ->
                                val colorIndex = uiState.drivers.indexOf(driverId)
                                val lineColor = if (colorIndex in ChartColors.indices) ChartColors[colorIndex] else ChartFallback

                                val driverLaps = uiState.lapData
                                    .filter { it.driverId == driverId }
                                    .sortedBy { it.lap }

                                if (driverLaps.size >= 2) {
                                    val path = Path()
                                    driverLaps.forEachIndexed { index, entry ->
                                        val x = (entry.lap.toFloat() / maxLap) * plotWidth
                                        val y = (entry.position.toFloat() / maxPos) * plotHeight

                                        if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
                                    }
                                    drawPath(path, lineColor, style = Stroke(width = 2.5f))
                                }
                            }
                        }

                        // Y-axis labels
                        Column(
                            modifier = Modifier
                                .fillMaxHeight()
                                .padding(top = 16.dp, bottom = 32.dp),
                            verticalArrangement = Arrangement.SpaceBetween,
                        ) {
                            listOf("P1", "P5", "P10", "P15", "P20").forEach { label ->
                                Text(label, color = PitwallTertiaryText, fontSize = 9.sp)
                            }
                        }
                    }
                }
            }
        }
    }
}
