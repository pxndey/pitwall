package com.pitcrew.app.ui.home

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pitcrew.app.ui.components.MessageBubble
import com.pitcrew.app.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: ChatViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    var inputText by remember { mutableStateOf("") }
    var showConversations by remember { mutableStateOf(false) }
    var showSearch by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    val context = LocalContext.current

    // Auto-scroll to bottom on new messages
    LaunchedEffect(uiState.messages.size, uiState.streamingText) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(listState.layoutInfo.totalItemsCount.coerceAtLeast(1) - 1)
        }
    }

    // Search debounce
    LaunchedEffect(searchQuery) {
        if (searchQuery.isNotBlank()) {
            delay(300)
            viewModel.searchHistory(searchQuery)
        } else {
            viewModel.clearSearch()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(PitCrewBackground, PitCrewBackgroundGradientEnd),
                )
            ),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = {
                    showConversations = true
                    viewModel.loadConversations()
                }) {
                    Icon(Icons.AutoMirrored.Filled.List, contentDescription = "Conversations", tint = Color.White)
                }
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = "PITCREW",
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.sp,
                )
                Spacer(modifier = Modifier.weight(1f))
                IconButton(onClick = { showSearch = !showSearch }) {
                    Icon(Icons.Default.Search, contentDescription = "Search", tint = Color.White)
                }
            }

            // Search bar
            if (showSearch) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text("Search messages...", color = PitCrewTertiaryText) },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = PitCrewRed,
                        unfocusedBorderColor = PitCrewTertiaryText,
                        cursorColor = PitCrewRed,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                    ),
                    shape = RoundedCornerShape(10.dp),
                )

                if (uiState.searchResults.isNotEmpty()) {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 200.dp)
                            .padding(horizontal = 16.dp),
                    ) {
                        items(uiState.searchResults) { msg ->
                            Text(
                                text = msg.content.take(100),
                                color = PitCrewSecondaryText,
                                fontSize = 13.sp,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .defaultMinSize(minHeight = 48.dp)
                                    .padding(vertical = 8.dp),
                                maxLines = 2,
                            )
                            HorizontalDivider(color = PitCrewCard)
                        }
                    }
                }
            }

            // Messages
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(vertical = 8.dp),
            ) {
                // Load more button
                if (uiState.hasMoreHistory) {
                    item {
                        TextButton(
                            onClick = { viewModel.loadMoreHistory() },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !uiState.isLoadingHistory,
                        ) {
                            if (uiState.isLoadingHistory) {
                                CircularProgressIndicator(modifier = Modifier.size(16.dp), color = PitCrewRed, strokeWidth = 2.dp)
                            } else {
                                Text("Load More History", color = PitCrewRed)
                            }
                        }
                    }
                }

                // Dashboard card (when no messages)
                if (uiState.messages.isEmpty() && uiState.dashboard != null && uiState.dashboard!!.error == null) {
                    item {
                        DashboardCard(dashboard = uiState.dashboard!!)
                    }
                }

                // Empty state
                if (uiState.messages.isEmpty() && !uiState.isLoadingHistory) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 40.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "Ask me anything about the race.",
                                color = PitCrewTertiaryText,
                                fontSize = 15.sp,
                            )
                        }
                    }
                }

                // Message bubbles
                items(uiState.messages, key = { it.id }) { message ->
                    MessageBubble(
                        content = message.content,
                        isUser = message.role == "user",
                    )
                }

                // Streaming text
                if (uiState.streamingText.isNotEmpty()) {
                    item {
                        MessageBubble(
                            content = uiState.streamingText,
                            isUser = false,
                        )
                    }
                }

                // Loading indicator
                if (uiState.isLoading && uiState.streamingText.isEmpty()) {
                    item {
                        Row(
                            modifier = Modifier
                                .padding(start = 4.dp, top = 4.dp)
                                .semantics { contentDescription = "Generating response" },
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            repeat(3) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(PitCrewSecondaryText),
                                )
                            }
                        }
                    }
                }
            }

            // Input bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(PitCrewBackground)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
                    .navigationBarsPadding(),
                verticalAlignment = Alignment.Bottom,
            ) {
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    placeholder = { Text("Message...", color = PitCrewTertiaryText) },
                    modifier = Modifier.weight(1f),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = PitCrewRed,
                        unfocusedBorderColor = PitCrewTertiaryText,
                        cursorColor = PitCrewRed,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        focusedContainerColor = PitCrewInputBg,
                        unfocusedContainerColor = PitCrewInputBg,
                    ),
                    shape = RoundedCornerShape(20.dp),
                    maxLines = 4,
                )
                Spacer(modifier = Modifier.width(8.dp))
                IconButton(
                    onClick = {
                        if (inputText.isNotBlank() && !uiState.isLoading) {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            val text = inputText.trim()
                            inputText = ""
                            viewModel.sendStreaming(text)
                        }
                    },
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(if (inputText.isNotBlank()) PitCrewRed else PitCrewCard),
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
        }
    }

    // Conversations bottom sheet
    if (showConversations) {
        ConversationListSheet(
            conversations = uiState.conversations,
            activeId = uiState.activeConversationId,
            onSelect = { id ->
                viewModel.switchConversation(id)
                showConversations = false
            },
            onDelete = { id -> viewModel.deleteConversation(id) },
            onCreate = { viewModel.createConversation() },
            onDismiss = { showConversations = false },
        )
    }
}

@Composable
fun DashboardCard(dashboard: com.pitcrew.app.data.remote.model.DriverDashboard) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        colors = CardDefaults.cardColors(containerColor = PitCrewCard),
        shape = RoundedCornerShape(12.dp),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Your Driver",
                color = PitCrewSecondaryText,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.height(8.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                if (dashboard.championshipPosition != null) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(PitCrewRed)
                            .semantics { contentDescription = "Championship position ${dashboard.championshipPosition}" },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = "P${dashboard.championshipPosition}",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp,
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                }
                Column {
                    Text(
                        text = dashboard.driverId?.replaceFirstChar { it.uppercase() } ?: "",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                    )
                    if (dashboard.championshipPoints != null) {
                        Text(
                            text = "${dashboard.championshipPoints.toInt()} pts",
                            color = PitCrewSecondaryText,
                            fontSize = 13.sp,
                        )
                    }
                }
            }

            if (dashboard.lastRace != null) {
                Spacer(modifier = Modifier.height(12.dp))
                Text("Last Race: ${dashboard.lastRace.raceName ?: ""}", color = PitCrewSecondaryText, fontSize = 13.sp)
            }
            if (dashboard.nextRace != null) {
                Spacer(modifier = Modifier.height(4.dp))
                Text("Next: ${dashboard.nextRace.raceName ?: ""}", color = PitCrewRed, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
