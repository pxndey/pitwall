package com.pitwall.app.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pitwall.app.data.remote.StreamEvent
import com.pitwall.app.data.remote.model.ChatHistoryItem
import com.pitwall.app.data.remote.model.ChatMessageOut
import com.pitwall.app.data.remote.model.ConversationOut
import com.pitwall.app.data.remote.model.DriverDashboard
import com.pitwall.app.data.repository.ChatRepository
import com.pitwall.app.data.repository.F1Repository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class Message(
    val id: String = java.util.UUID.randomUUID().toString(),
    val role: String,
    val content: String,
)

data class ChatUiState(
    val messages: List<Message> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingHistory: Boolean = false,
    val hasMoreHistory: Boolean = true,
    val errorMessage: String? = null,
    val conversations: List<ConversationOut> = emptyList(),
    val activeConversationId: String? = null,
    val searchResults: List<ChatMessageOut> = emptyList(),
    val streamingText: String = "",
    val dashboard: DriverDashboard? = null,
)

@HiltViewModel
class ChatViewModel @Inject constructor(
    private val chatRepository: ChatRepository,
    private val f1Repository: F1Repository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState

    private var streamJob: Job? = null

    init {
        loadHistory()
        loadDashboard()
    }

    fun sendStreaming(text: String, circuitContext: String = "") {
        val userMsg = Message(role = "user", content = text)
        _uiState.value = _uiState.value.copy(
            messages = _uiState.value.messages + userMsg,
            isLoading = true,
            streamingText = "",
            errorMessage = null,
        )

        val history = _uiState.value.messages.takeLast(10).map {
            ChatHistoryItem(role = it.role, content = it.content)
        }

        streamJob = viewModelScope.launch {
            var fullText = ""
            try {
                chatRepository.sendStreaming(
                    message = text,
                    history = history,
                    circuitContext = circuitContext,
                    conversationId = _uiState.value.activeConversationId ?: "",
                ).collect { event ->
                    when (event) {
                        is StreamEvent.Token -> {
                            fullText += event.content
                            _uiState.value = _uiState.value.copy(streamingText = fullText)
                        }
                        is StreamEvent.Done -> {
                            val assistantMsg = Message(role = "assistant", content = event.fullContent)
                            _uiState.value = _uiState.value.copy(
                                messages = _uiState.value.messages + assistantMsg,
                                isLoading = false,
                                streamingText = "",
                            )
                        }
                        is StreamEvent.Error -> {
                            // Fallback to HTTP
                            sendHttp(text, history, circuitContext)
                        }
                    }
                }
            } catch (e: Exception) {
                sendHttp(text, history, circuitContext)
            }
        }
    }

    private fun sendHttp(text: String, history: List<ChatHistoryItem>, circuitContext: String) {
        viewModelScope.launch {
            val result = chatRepository.sendMessage(
                message = text,
                history = history,
                circuitContext = circuitContext,
                conversationId = _uiState.value.activeConversationId ?: "",
            )
            result.fold(
                onSuccess = { response ->
                    val assistantMsg = Message(role = "assistant", content = response.reply)
                    _uiState.value = _uiState.value.copy(
                        messages = _uiState.value.messages + assistantMsg,
                        isLoading = false,
                        streamingText = "",
                        activeConversationId = response.conversationId ?: _uiState.value.activeConversationId,
                    )
                },
                onFailure = {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        streamingText = "",
                        errorMessage = it.message,
                    )
                },
            )
        }
    }

    fun loadHistory() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoadingHistory = true)
            val result = chatRepository.getHistory(
                offset = 0,
                limit = 30,
                conversationId = _uiState.value.activeConversationId,
            )
            result.fold(
                onSuccess = { messages ->
                    _uiState.value = _uiState.value.copy(
                        messages = messages.map { Message(id = it.id, role = it.role, content = it.content) },
                        isLoadingHistory = false,
                        hasMoreHistory = messages.size >= 30,
                    )
                },
                onFailure = {
                    _uiState.value = _uiState.value.copy(isLoadingHistory = false)
                },
            )
        }
    }

    fun loadMoreHistory() {
        if (_uiState.value.isLoadingHistory || !_uiState.value.hasMoreHistory) return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoadingHistory = true)
            val offset = _uiState.value.messages.size
            val result = chatRepository.getHistory(
                offset = offset,
                limit = 30,
                conversationId = _uiState.value.activeConversationId,
            )
            result.fold(
                onSuccess = { older ->
                    val olderMessages = older.map { Message(id = it.id, role = it.role, content = it.content) }
                    _uiState.value = _uiState.value.copy(
                        messages = olderMessages + _uiState.value.messages,
                        isLoadingHistory = false,
                        hasMoreHistory = older.size >= 30,
                    )
                },
                onFailure = {
                    _uiState.value = _uiState.value.copy(isLoadingHistory = false)
                },
            )
        }
    }

    fun loadConversations() {
        viewModelScope.launch {
            chatRepository.getConversations().onSuccess { convos ->
                _uiState.value = _uiState.value.copy(conversations = convos)
            }
        }
    }

    fun createConversation() {
        viewModelScope.launch {
            chatRepository.createConversation().onSuccess { convo ->
                _uiState.value = _uiState.value.copy(
                    activeConversationId = convo.id,
                    messages = emptyList(),
                )
                loadConversations()
            }
        }
    }

    fun switchConversation(id: String) {
        _uiState.value = _uiState.value.copy(activeConversationId = id, messages = emptyList())
        loadHistory()
    }

    fun deleteConversation(id: String) {
        viewModelScope.launch {
            chatRepository.deleteConversation(id).onSuccess {
                if (_uiState.value.activeConversationId == id) {
                    _uiState.value = _uiState.value.copy(activeConversationId = null, messages = emptyList())
                    loadHistory()
                }
                loadConversations()
            }
        }
    }

    fun searchHistory(query: String) {
        viewModelScope.launch {
            chatRepository.searchHistory(query).onSuccess { results ->
                _uiState.value = _uiState.value.copy(searchResults = results)
            }
        }
    }

    fun clearSearch() {
        _uiState.value = _uiState.value.copy(searchResults = emptyList())
    }

    private fun loadDashboard() {
        viewModelScope.launch {
            f1Repository.getDriverDashboard().onSuccess { dashboard ->
                _uiState.value = _uiState.value.copy(dashboard = dashboard)
            }
        }
    }

    fun refresh() {
        loadHistory()
        loadDashboard()
    }
}
