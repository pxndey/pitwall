package com.pitcrew.app.ui.standings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pitcrew.app.ui.components.ErrorState
import com.pitcrew.app.ui.components.LoadingIndicator
import com.pitcrew.app.ui.theme.*

@Composable
fun DriverDetailScreen(
    driverId: String,
    driverName: String,
    onBack: () -> Unit,
    viewModel: DriverDetailViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(driverId) { viewModel.load(driverId) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PitCrewBackground),
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
                Text(driverName, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            }

            when {
                uiState.isLoading -> LoadingIndicator()
                uiState.errorMessage != null -> ErrorState(message = uiState.errorMessage!!, onRetry = { viewModel.load(driverId) })
                else -> {
                    LazyColumn(
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        // Header card
                        item {
                            Card(
                                colors = CardDefaults.cardColors(containerColor = PitCrewCard),
                                shape = RoundedCornerShape(12.dp),
                            ) {
                                Row(
                                    modifier = Modifier.padding(16.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    val pos = uiState.standing?.positionInt ?: 0
                                    val posColor = when (pos) {
                                        1 -> PodiumGold
                                        2 -> PodiumSilver
                                        3 -> PodiumBronze
                                        else -> PitCrewRed
                                    }
                                    Box(
                                        modifier = Modifier
                                            .size(56.dp)
                                            .clip(CircleShape)
                                            .background(posColor),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Text("P$pos", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                                    }
                                    Spacer(modifier = Modifier.width(16.dp))
                                    Column {
                                        Text(
                                            text = "${uiState.driverInfo?.givenName ?: ""} ${uiState.driverInfo?.familyName ?: ""}",
                                            color = Color.White,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 18.sp,
                                        )
                                        Text(
                                            text = uiState.driverInfo?.nationality ?: "",
                                            color = PitCrewSecondaryText,
                                            fontSize = 14.sp,
                                        )
                                        Text(
                                            text = uiState.standing?.constructorName ?: "",
                                            color = PitCrewRed,
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.SemiBold,
                                        )
                                    }
                                }
                            }
                        }

                        // Stats grid
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                StatCell("Avg Finish", "%.1f".format(uiState.avgFinish), Modifier.weight(1f))
                                StatCell("Best", if (uiState.bestFinish > 0) "P${uiState.bestFinish}" else "-", Modifier.weight(1f))
                                StatCell("Points", "${uiState.totalPoints.toInt()}", Modifier.weight(1f))
                                StatCell("DNFs", "${uiState.dnfCount}", Modifier.weight(1f))
                            }
                        }

                        // Race results header
                        item {
                            Text("Race Results", color = PitCrewSecondaryText, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }

                        // Race-by-race results
                        items(uiState.seasonResults) { result ->
                            val pos = result.positionInt
                            val posColor = when (pos) {
                                1 -> PodiumGold
                                2 -> PodiumSilver
                                3 -> PodiumBronze
                                else -> Color.White
                            }
                            Card(
                                colors = CardDefaults.cardColors(containerColor = PitCrewCard),
                                shape = RoundedCornerShape(8.dp),
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 12.dp, vertical = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(28.dp)
                                            .clip(RoundedCornerShape(6.dp))
                                            .background(posColor.copy(alpha = 0.15f)),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Text("$pos", color = posColor, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Text(
                                        text = result.raceName ?: "",
                                        color = Color.White,
                                        fontSize = 13.sp,
                                        modifier = Modifier.weight(1f),
                                    )
                                    Text(
                                        text = "${result.pointsFloat.toInt()} pts",
                                        color = PitCrewSecondaryText,
                                        fontSize = 12.sp,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun StatCell(label: String, value: String, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = PitCrewCard),
        shape = RoundedCornerShape(8.dp),
    ) {
        Column(
            modifier = Modifier.padding(vertical = 10.dp, horizontal = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            Spacer(modifier = Modifier.height(2.dp))
            Text(label, color = PitCrewTertiaryText, fontSize = 11.sp)
        }
    }
}
