package com.pitcrew.app.data.repository

import com.pitcrew.app.data.remote.ApiService
import com.pitcrew.app.data.remote.StreamEvent
import com.pitcrew.app.data.remote.WebSocketManager
import com.pitcrew.app.data.remote.model.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.firstOrNull
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ChatRepository @Inject constructor(
    private val apiService: ApiService,
    private val webSocketManager: WebSocketManager,
    private val authRepository: AuthRepository,
) {
    suspend fun sendMessage(
        message: String,
        history: List<ChatHistoryItem> = emptyList(),
        circuitContext: String = "",
        conversationId: String = "",
    ): Result<ChatResponse> {
        return try {
            val response = apiService.sendMessage(
                ChatRequest(message, history, circuitContext, conversationId)
            )
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception("Failed to send message"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun sendStreaming(
        message: String,
        history: List<ChatHistoryItem> = emptyList(),
        circuitContext: String = "",
        conversationId: String = "",
    ): Flow<StreamEvent> {
        val token = authRepository.getToken().firstOrNull() ?: ""
        return webSocketManager.stream(
            token = token,
            message = message,
            history = history,
            circuitContext = circuitContext,
            conversationId = conversationId,
        )
    }

    suspend fun getHistory(
        offset: Int = 0,
        limit: Int = 30,
        conversationId: String? = null,
    ): Result<List<ChatMessageOut>> {
        return try {
            val response = apiService.getChatHistory(offset, limit, conversationId)
            if (response.isSuccessful) {
                Result.success(response.body() ?: emptyList())
            } else {
                Result.failure(Exception("Failed to load history"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun searchHistory(query: String, limit: Int = 20): Result<List<ChatMessageOut>> {
        return try {
            val response = apiService.searchChat(query, limit)
            if (response.isSuccessful) {
                Result.success(response.body() ?: emptyList())
            } else {
                Result.failure(Exception("Search failed"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getConversations(): Result<List<ConversationOut>> {
        return try {
            val response = apiService.getConversations()
            if (response.isSuccessful) {
                Result.success(response.body() ?: emptyList())
            } else {
                Result.failure(Exception("Failed to load conversations"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun createConversation(title: String = "New Chat"): Result<ConversationOut> {
        return try {
            val response = apiService.createConversation(CreateConversationRequest(title))
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception("Failed to create conversation"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun deleteConversation(id: String): Result<Unit> {
        return try {
            val response = apiService.deleteConversation(id)
            if (response.isSuccessful) {
                Result.success(Unit)
            } else {
                Result.failure(Exception("Failed to delete conversation"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
