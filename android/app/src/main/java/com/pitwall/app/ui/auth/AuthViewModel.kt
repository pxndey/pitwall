package com.pitwall.app.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pitwall.app.data.remote.model.JolpicaConstructor
import com.pitwall.app.data.remote.model.JolpicaDriver
import com.pitwall.app.data.remote.model.SignUpRequest
import com.pitwall.app.data.repository.AuthRepository
import com.pitwall.app.data.repository.F1Repository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AuthUiState(
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val isSuccess: Boolean = false,
    val drivers: List<JolpicaDriver> = emptyList(),
    val constructors: List<JolpicaConstructor> = emptyList(),
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val f1Repository: F1Repository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState

    fun login(username: String, password: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            val result = authRepository.login(username, password)
            _uiState.value = result.fold(
                onSuccess = { _uiState.value.copy(isLoading = false, isSuccess = true) },
                onFailure = { _uiState.value.copy(isLoading = false, errorMessage = it.message) },
            )
        }
    }

    fun signup(
        username: String,
        name: String,
        email: String,
        password: String,
        favDriver: String?,
        favTeam: String?,
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            val result = authRepository.signup(
                SignUpRequest(
                    username = username,
                    name = name.ifBlank { null },
                    email = email,
                    password = password,
                    favDriver = favDriver,
                    favTeam = favTeam,
                )
            )
            _uiState.value = result.fold(
                onSuccess = { _uiState.value.copy(isLoading = false, isSuccess = true) },
                onFailure = { _uiState.value.copy(isLoading = false, errorMessage = it.message) },
            )
        }
    }

    fun loadF1Data() {
        viewModelScope.launch {
            f1Repository.getDriversList().onSuccess { drivers ->
                _uiState.value = _uiState.value.copy(drivers = drivers)
            }
            f1Repository.getConstructorsList().onSuccess { constructors ->
                _uiState.value = _uiState.value.copy(constructors = constructors)
            }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }

    fun resetSuccess() {
        _uiState.value = _uiState.value.copy(isSuccess = false)
    }
}
