package com.pitwall.app.ui.standings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
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
import com.pitwall.app.ui.components.ErrorState
import com.pitwall.app.ui.components.LoadingIndicator
import com.pitwall.app.ui.theme.*

@Composable
fun StandingsScreen(
    onDriverClick: (String, String) -> Unit,
    viewModel: StandingsViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    var selectedTab by remember { mutableIntStateOf(0) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PitwallBackground),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Header
            Text(
                text = "Standings",
                color = Color.White,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            )

            // Tab Row
            TabRow(
                selectedTabIndex = selectedTab,
                containerColor = PitwallBackground,
                contentColor = PitwallRed,
                indicator = { tabPositions ->
                    TabRowDefaults.SecondaryIndicator(
                        modifier = Modifier.tabIndicatorOffset(tabPositions[selectedTab]),
                        color = PitwallRed,
                    )
                },
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = {
                        selectedTab = 0
                        viewModel.loadDriverStandings()
                    },
                    text = { Text("Drivers", color = if (selectedTab == 0) PitwallRed else PitwallTertiaryText) },
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = {
                        selectedTab = 1
                        viewModel.loadConstructorStandings()
                    },
                    text = { Text("Constructors", color = if (selectedTab == 1) PitwallRed else PitwallTertiaryText) },
                )
            }

            when {
                uiState.isLoading -> LoadingIndicator()
                uiState.errorMessage != null -> ErrorState(
                    message = uiState.errorMessage!!,
                    onRetry = {
                        if (selectedTab == 0) viewModel.loadDriverStandings()
                        else viewModel.loadConstructorStandings()
                    },
                )
                else -> {
                    if (selectedTab == 0) {
                        LazyColumn(
                            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            items(uiState.driverStandings) { driver ->
                                DriverStandingRow(
                                    driver = driver,
                                    onClick = {
                                        val driverId = driver.driverId ?: return@DriverStandingRow
                                        val name = "${driver.givenName ?: ""} ${driver.familyName ?: ""}"
                                        onDriverClick(driverId, name)
                                    },
                                )
                            }
                        }
                    } else {
                        LazyColumn(
                            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            items(uiState.constructorStandings) { constructor ->
                                ConstructorStandingRow(constructor = constructor)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun DriverStandingRow(
    driver: com.pitwall.app.data.remote.model.DriverStanding,
    onClick: () -> Unit,
) {
    val pos = driver.positionInt
    val posColor = when (pos) {
        1 -> PodiumGold
        2 -> PodiumSilver
        3 -> PodiumBronze
        else -> PitwallRed
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        colors = CardDefaults.cardColors(containerColor = PitwallCard),
        shape = RoundedCornerShape(8.dp),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(posColor),
                contentAlignment = Alignment.Center,
            ) {
                Text("$pos", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "${driver.givenName ?: ""} ${driver.familyName ?: ""}",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
                Text(
                    text = driver.constructorName ?: "",
                    color = PitwallTertiaryText,
                    fontSize = 12.sp,
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "${driver.pointsFloat.toInt()} pts",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
                Text(
                    text = "${driver.winsInt} wins",
                    color = PitwallTertiaryText,
                    fontSize = 12.sp,
                )
            }
        }
    }
}

@Composable
fun ConstructorStandingRow(
    constructor: com.pitwall.app.data.remote.model.ConstructorStanding,
) {
    val pos = constructor.positionInt
    val posColor = when (pos) {
        1 -> PodiumGold
        2 -> PodiumSilver
        3 -> PodiumBronze
        else -> PitwallRed
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = PitwallCard),
        shape = RoundedCornerShape(8.dp),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(posColor),
                contentAlignment = Alignment.Center,
            ) {
                Text("$pos", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            }
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = constructor.name ?: "",
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
                modifier = Modifier.weight(1f),
            )
            Column(horizontalAlignment = Alignment.End) {
                Text("${constructor.pointsFloat.toInt()} pts", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                Text("${constructor.winsInt} wins", color = PitwallTertiaryText, fontSize = 12.sp)
            }
        }
    }
}
