package com.pitcrew.app.ui.schedule

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pitcrew.app.data.remote.model.JolpicaRace
import com.pitcrew.app.data.remote.model.RaceResultResponse
import com.pitcrew.app.ui.theme.*
import com.pitcrew.app.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RaceDetailSheet(
    race: JolpicaRace,
    raceResults: RaceResultResponse?,
    isLoadingResults: Boolean,
    onDismiss: () -> Unit,
    onLapChart: (Int, Int, String) -> Unit,
    onAskAboutRace: (JolpicaRace) -> Unit,
    onScheduleNotification: (JolpicaRace) -> Unit,
) {
    val season = race.season?.toIntOrNull() ?: 2025
    val isPastRace = isPast(race.date)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = PitCrewCard,
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Race info
            item {
                Text(
                    text = "${flag(race.circuit?.location?.country)} ${race.raceName ?: ""}",
                    color = Color.White,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Round ${race.roundInt} — ${race.season ?: ""}",
                    color = PitCrewSecondaryText,
                    fontSize = 14.sp,
                )
            }

            // Circuit
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = PitCrewBackground),
                    shape = RoundedCornerShape(8.dp),
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text("Circuit", color = PitCrewSecondaryText, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(race.circuit?.circuitName ?: "", color = Color.White, fontSize = 15.sp)
                        Text(
                            "${race.circuit?.location?.locality ?: ""}, ${race.circuit?.location?.country ?: ""}",
                            color = PitCrewTertiaryText,
                            fontSize = 13.sp,
                        )
                    }
                }
            }

            // Weekend schedule
            item {
                Text("Race Weekend", color = PitCrewSecondaryText, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Spacer(modifier = Modifier.height(4.dp))
                val sessions = listOf("FP1 — Friday 11:30", "FP2 — Friday 15:00", "FP3 — Saturday 11:30", "Qualifying — Saturday 15:00", "Race — Sunday ${race.time?.take(5) ?: "14:00"}")
                sessions.forEach { session ->
                    Text(session, color = Color.White, fontSize = 13.sp, modifier = Modifier.padding(vertical = 2.dp))
                }
            }

            // Action buttons
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    OutlinedButton(
                        onClick = { onAskAboutRace(race) },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = PitCrewRed),
                    ) {
                        Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Ask AI", fontSize = 13.sp)
                    }

                    if (!isPastRace) {
                        OutlinedButton(
                            onClick = { onScheduleNotification(race) },
                            modifier = Modifier.weight(1f),
                            colors = ButtonDefaults.outlinedButtonColors(contentColor = PitCrewRed),
                        ) {
                            Icon(Icons.Default.Notifications, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Notify", fontSize = 13.sp)
                        }
                    }

                    if (isPastRace) {
                        OutlinedButton(
                            onClick = { onLapChart(season, race.roundInt, race.raceName ?: "") },
                            modifier = Modifier.weight(1f),
                            colors = ButtonDefaults.outlinedButtonColors(contentColor = PitCrewRed),
                        ) {
                            Icon(Icons.Default.ShowChart, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Laps", fontSize = 13.sp)
                        }
                    }
                }
            }

            // Race results
            if (isPastRace) {
                item {
                    Text("Race Results", color = PitCrewSecondaryText, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }

                if (isLoadingResults) {
                    item {
                        Box(modifier = Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(color = PitCrewRed, modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
                        }
                    }
                } else if (raceResults?.results != null) {
                    items(raceResults.results) { result ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            val pos = result.positionInt
                            val posColor = when (pos) {
                                1 -> PodiumGold
                                2 -> PodiumSilver
                                3 -> PodiumBronze
                                else -> Color.White
                            }
                            Box(
                                modifier = Modifier
                                    .size(28.dp)
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(posColor.copy(alpha = 0.2f)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text("$pos", color = posColor, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "${result.driver?.givenName ?: ""} ${result.driver?.familyName ?: ""}",
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
