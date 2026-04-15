package com.pitwall.app.ui.standings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pitwall.app.data.remote.model.DriverInfo
import com.pitwall.app.data.remote.model.DriverSeasonStanding
import com.pitwall.app.data.remote.model.SeasonRaceResult
import com.pitwall.app.data.repository.F1Repository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DriverDetailUiState(
    val driverInfo: DriverInfo? = null,
    val standing: DriverSeasonStanding? = null,
    val seasonResults: List<SeasonRaceResult> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
) {
    val totalPoints: Float get() = seasonResults.sumOf { it.pointsFloat.toDouble() }.toFloat()

    val bestFinish: Int get() = seasonResults
        .map { it.positionInt }
        .filter { it > 0 }
        .minOrNull() ?: 0

    val dnfCount: Int get() = seasonResults.count {
        val status = it.status?.lowercase() ?: ""
        status.contains("retired") || status.contains("dnf") ||
            status.contains("accident") || status.contains("collision") ||
            status.contains("engine") || status.contains("gearbox") ||
            status.contains("hydraulic") || status.contains("electrical")
    }

    val avgFinish: Float get() {
        val positions = seasonResults.map { it.positionInt }.filter { it > 0 }
        return if (positions.isEmpty()) 0f else positions.average().toFloat()
    }
}

@HiltViewModel
class DriverDetailViewModel @Inject constructor(
    private val f1Repository: F1Repository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DriverDetailUiState())
    val uiState: StateFlow<DriverDetailUiState> = _uiState

    fun load(driverId: String, season: Int = 2025) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            f1Repository.getDriverSeason(driverId, season).fold(
                onSuccess = { response ->
                    _uiState.value = _uiState.value.copy(
                        driverInfo = response.driverInfo,
                        standing = response.standing,
                        seasonResults = response.seasonResults ?: emptyList(),
                        isLoading = false,
                    )
                },
                onFailure = {
                    _uiState.value = _uiState.value.copy(errorMessage = it.message, isLoading = false)
                },
            )
        }
    }
}
