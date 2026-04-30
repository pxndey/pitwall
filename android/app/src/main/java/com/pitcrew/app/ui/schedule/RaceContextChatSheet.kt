package com.pitcrew.app.ui.schedule

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pitcrew.app.ui.components.MessageBubble
import com.pitcrew.app.ui.home.Message
import com.pitcrew.app.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RaceContextChatSheet(
    raceName: String,
    messages: List<Message>,
    isLoading: Boolean,
    onSend: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var inputText by remember { mutableStateOf("") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = PitCrewCard,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 400.dp)
                .padding(horizontal = 16.dp)
                .padding(bottom = 16.dp),
        ) {
            Text(
                text = raceName,
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
            )
            Spacer(modifier = Modifier.height(12.dp))

            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(vertical = 4.dp),
            ) {
                items(messages, key = { it.id }) { message ->
                    MessageBubble(content = message.content, isUser = message.role == "user")
                }
                if (isLoading) {
                    item {
                        CircularProgressIndicator(
                            modifier = Modifier.padding(start = 4.dp).size(20.dp),
                            color = PitCrewRed,
                            strokeWidth = 2.dp,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    placeholder = { Text("Ask about this race...", color = PitCrewTertiaryText) },
                    modifier = Modifier.weight(1f),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = PitCrewRed,
                        unfocusedBorderColor = PitCrewTertiaryText,
                        cursorColor = PitCrewRed,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        focusedContainerColor = PitCrewBackground,
                        unfocusedContainerColor = PitCrewBackground,
                    ),
                    shape = RoundedCornerShape(20.dp),
                    singleLine = true,
                )
                Spacer(modifier = Modifier.width(8.dp))
                IconButton(
                    onClick = {
                        if (inputText.isNotBlank() && !isLoading) {
                            onSend(inputText.trim())
                            inputText = ""
                        }
                    },
                ) {
                    Icon(Icons.AutoMirrored.Filled.Send, contentDescription = "Send", tint = PitCrewRed)
                }
            }
        }
    }
}
