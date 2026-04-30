package com.pitcrew.app.data.remote.model

import com.google.gson.annotations.SerializedName

data class ChatRequest(
    val message: String,
    val history: List<ChatHistoryItem> = emptyList(),
    @SerializedName("circuit_context") val circuitContext: String = "",
    @SerializedName("conversation_id") val conversationId: String = "",
)

data class ChatHistoryItem(
    val role: String,
    val content: String,
)

data class ChatResponse(
    val reply: String,
    @SerializedName("conversation_id") val conversationId: String?,
)

data class ChatMessageOut(
    val id: String,
    val role: String,
    val content: String,
    @SerializedName("created_at") val createdAt: String?,
    @SerializedName("conversation_id") val conversationId: String?,
)

data class ConversationOut(
    val id: String,
    val title: String,
    @SerializedName("created_at") val createdAt: String?,
    @SerializedName("updated_at") val updatedAt: String?,
    @SerializedName("message_count") val messageCount: Int?,
)

data class CreateConversationRequest(
    val title: String = "New Chat",
)

data class UpdateConversationRequest(
    val title: String,
)

data class WebSocketOutbound(
    val token: String,
    val message: String,
    val history: List<ChatHistoryItem> = emptyList(),
    @SerializedName("circuit_context") val circuitContext: String = "",
    @SerializedName("conversation_id") val conversationId: String = "",
)

data class WebSocketInbound(
    val type: String,
    val content: String?,
    val error: String?,
)
