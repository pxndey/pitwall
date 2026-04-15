package com.pitwall.app.ui.schedule

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pitwall.app.data.remote.model.JolpicaRace
import com.pitwall.app.ui.components.ErrorState
import com.pitwall.app.ui.components.LoadingIndicator
import com.pitwall.app.ui.theme.*
import com.pitwall.app.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduleScreen(
    onNavigateToLapChart: (Int, Int, String) -> Unit,
    viewModel: ScheduleViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    var selectedRace by remember { mutableStateOf<JolpicaRace?>(null) }
    var showContextChat by remember { mutableStateOf(false) }
    var contextChatRace by remember { mutableStateOf<JolpicaRace?>(null) }
    val context = LocalContext.current

    val notifPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            NotificationHelper.scheduleAllUpcoming(context, uiState.races)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PitwallBackground),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Schedule", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                IconButton(onClick = {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        notifPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else {
                        NotificationHelper.scheduleAllUpcoming(context, uiState.races)
                    }
                }) {
                    Icon(Icons.Default.Notifications, contentDescription = "Schedule All Notifications", tint = PitwallRed)
                }
            }

            when {
                uiState.isLoading -> LoadingIndicator()
                uiState.errorMessage != null -> ErrorState(
                    message = uiState.errorMessage!!,
                    onRetry = { viewModel.loadSchedule() },
                )
                else -> {
                    val nextRaceIndex = uiState.races.indexOfFirst { isNextRace(it.date) }
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(uiState.races) { race ->
                            val isNext = uiState.races.indexOf(race) == nextRaceIndex
                            RaceCard(
                                race = race,
                                isNext = isNext,
                                onClick = {
                                    selectedRace = race
                                    val season = race.season?.toIntOrNull() ?: 2025
                                    if (isPast(race.date)) {
                                        viewModel.loadRaceResults(season, race.roundInt)
                                    }
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    // Race detail sheet
    if (selectedRace != null) {
        RaceDetailSheet(
            race = selectedRace!!,
            raceResults = uiState.raceResults,
            isLoadingResults = uiState.isLoadingResults,
            onDismiss = {
                selectedRace = null
                viewModel.clearResults()
            },
            onLapChart = { season, round, name ->
                selectedRace = null
                onNavigateToLapChart(season, round, name)
            },
            onAskAboutRace = { race ->
                contextChatRace = race
                showContextChat = true
                viewModel.clearContextChat()
                val circuitName = race.circuit?.circuitName ?: ""
                viewModel.sendContextMessage(
                    "brief me on ${race.raceName} at $circuitName",
                    circuitContext = circuitName,
                )
            },
            onScheduleNotification = { race ->
                NotificationHelper.scheduleRaceNotifications(context, race)
            },
        )
    }

    // Race context chat sheet
    if (showContextChat && contextChatRace != null) {
        RaceContextChatSheet(
            raceName = contextChatRace!!.raceName ?: "",
            messages = uiState.contextChatMessages,
            isLoading = uiState.contextChatLoading,
            onSend = { message ->
                viewModel.sendContextMessage(
                    message,
                    circuitContext = contextChatRace!!.circuit?.circuitName ?: "",
                )
            },
            onDismiss = {
                showContextChat = false
                viewModel.clearContextChat()
            },
        )
    }
}

@Composable
fun RaceCard(
    race: JolpicaRace,
    isNext: Boolean,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        colors = CardDefaults.cardColors(containerColor = PitwallCard),
        shape = RoundedCornerShape(12.dp),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Round badge
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (isNext) PitwallRed else PitwallBackground),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "R${race.roundInt}",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = flag(race.circuit?.location?.country),
                        fontSize = 16.sp,
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = race.raceName ?: "",
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                        maxLines = 1,
                    )
                }
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = race.circuit?.circuitName ?: "",
                    color = PitwallTertiaryText,
                    fontSize = 12.sp,
                    maxLines = 1,
                )
                Text(
                    text = weekendRange(race.date),
                    color = PitwallSecondaryText,
                    fontSize = 12.sp,
                )
            }

            if (isNext) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(PitwallRed)
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                ) {
                    Text("NEXT", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
