package com.pitcrew.app.ui.standings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pitcrew.app.data.remote.model.ConstructorStanding
import com.pitcrew.app.data.remote.model.DriverStanding
import com.pitcrew.app.data.repository.F1Repository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class StandingsUiState(
    val driverStandings: List<DriverStanding> = emptyList(),
    val constructorStandings: List<ConstructorStanding> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

@HiltViewModel
class StandingsViewModel @Inject constructor(
    private val f1Repository: F1Repository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(StandingsUiState())
    val uiState: StateFlow<StandingsUiState> = _uiState

    init {
        loadDriverStandings()
    }

    fun loadDriverStandings() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            f1Repository.getDriverStandings().fold(
                onSuccess = { _uiState.value = _uiState.value.copy(driverStandings = it, isLoading = false) },
                onFailure = { _uiState.value = _uiState.value.copy(errorMessage = it.message, isLoading = false) },
            )
        }
    }

    fun loadConstructorStandings() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            f1Repository.getConstructorStandings().fold(
                onSuccess = { _uiState.value = _uiState.value.copy(constructorStandings = it, isLoading = false) },
                onFailure = { _uiState.value = _uiState.value.copy(errorMessage = it.message, isLoading = false) },
            )
        }
    }
}
