package com.pitcrew.app.ui.lapchart

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pitcrew.app.data.repository.F1Repository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LapEntry(
    val driverId: String,
    val lap: Int,
    val position: Int,
)

data class LapChartUiState(
    val lapData: List<LapEntry> = emptyList(),
    val drivers: List<String> = emptyList(),
    val visibleDrivers: Set<String> = emptySet(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

@HiltViewModel
class LapChartViewModel @Inject constructor(
    private val f1Repository: F1Repository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(LapChartUiState())
    val uiState: StateFlow<LapChartUiState> = _uiState

    fun loadLaps(season: Int, round: Int) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            f1Repository.getLaps(season, round).fold(
                onSuccess = { response ->
                    val entries = mutableListOf<LapEntry>()
                    response.laps?.forEach { lap ->
                        val lapNum = when (val n = lap.number) {
                            is Number -> n.toInt()
                            is String -> n.toIntOrNull() ?: 0
                            else -> 0
                        }
                        lap.timings?.forEach { timing ->
                            entries.add(
                                LapEntry(
                                    driverId = timing.driverId ?: "",
                                    lap = lapNum,
                                    position = timing.positionInt,
                                )
                            )
                        }
                    }
                    val allDrivers = entries.map { it.driverId }.distinct().sorted()
                    _uiState.value = _uiState.value.copy(
                        lapData = entries,
                        drivers = allDrivers,
                        visibleDrivers = allDrivers.take(10).toSet(),
                        isLoading = false,
                    )
                },
                onFailure = {
                    _uiState.value = _uiState.value.copy(errorMessage = it.message, isLoading = false)
                },
            )
        }
    }

    fun toggleDriver(driverId: String) {
        val current = _uiState.value.visibleDrivers.toMutableSet()
        if (current.contains(driverId)) {
            current.remove(driverId)
        } else {
            current.add(driverId)
        }
        _uiState.value = _uiState.value.copy(visibleDrivers = current)
    }
}
