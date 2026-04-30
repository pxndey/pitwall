package com.pitcrew.app.ui.schedule

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pitcrew.app.data.remote.model.JolpicaRace
import com.pitcrew.app.data.remote.model.RaceResultResponse
import com.pitcrew.app.data.repository.ChatRepository
import com.pitcrew.app.data.repository.F1Repository
import com.pitcrew.app.data.remote.model.ChatHistoryItem
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ScheduleUiState(
    val races: List<JolpicaRace> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val raceResults: RaceResultResponse? = null,
    val isLoadingResults: Boolean = false,
    // Race context chat
    val contextChatMessages: List<com.pitcrew.app.ui.home.Message> = emptyList(),
    val contextChatLoading: Boolean = false,
    val contextChatStreaming: String = "",
)

@HiltViewModel
class ScheduleViewModel @Inject constructor(
    private val f1Repository: F1Repository,
    private val chatRepository: ChatRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ScheduleUiState())
    val uiState: StateFlow<ScheduleUiState> = _uiState

    init {
        loadSchedule()
    }

    fun loadSchedule() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            f1Repository.getSchedule().fold(
                onSuccess = { _uiState.value = _uiState.value.copy(races = it, isLoading = false) },
                onFailure = { _uiState.value = _uiState.value.copy(errorMessage = it.message, isLoading = false) },
            )
        }
    }

    fun loadRaceResults(season: Int, round: Int) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoadingResults = true, raceResults = null)
            f1Repository.getRaceResults(season, round).fold(
                onSuccess = { _uiState.value = _uiState.value.copy(raceResults = it, isLoadingResults = false) },
                onFailure = { _uiState.value = _uiState.value.copy(isLoadingResults = false) },
            )
        }
    }

    fun sendContextMessage(message: String, circuitContext: String) {
        val userMsg = com.pitcrew.app.ui.home.Message(role = "user", content = message)
        _uiState.value = _uiState.value.copy(
            contextChatMessages = _uiState.value.contextChatMessages + userMsg,
            contextChatLoading = true,
        )

        viewModelScope.launch {
            chatRepository.sendMessage(
                message = message,
                circuitContext = circuitContext,
            ).fold(
                onSuccess = { response ->
                    val assistantMsg = com.pitcrew.app.ui.home.Message(role = "assistant", content = response.reply)
                    _uiState.value = _uiState.value.copy(
                        contextChatMessages = _uiState.value.contextChatMessages + assistantMsg,
                        contextChatLoading = false,
                    )
                },
                onFailure = {
                    _uiState.value = _uiState.value.copy(contextChatLoading = false)
                },
            )
        }
    }

    fun clearContextChat() {
        _uiState.value = _uiState.value.copy(contextChatMessages = emptyList())
    }

    fun clearResults() {
        _uiState.value = _uiState.value.copy(raceResults = null)
    }
}
