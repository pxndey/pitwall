package com.pitwall.app.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pitwall.app.data.remote.model.UpdateProfileRequest
import com.pitwall.app.data.remote.model.UserOut
import com.pitwall.app.data.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProfileUiState(
    val user: UserOut? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val updateSuccess: Boolean = false,
)

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState

    init {
        loadProfile()
    }

    fun loadProfile() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            authRepository.getMe().fold(
                onSuccess = { _uiState.value = _uiState.value.copy(user = it, isLoading = false) },
                onFailure = { _uiState.value = _uiState.value.copy(errorMessage = it.message, isLoading = false) },
            )
        }
    }

    fun updateProfile(request: UpdateProfileRequest) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null, updateSuccess = false)
            authRepository.updateMe(request).fold(
                onSuccess = { _uiState.value = _uiState.value.copy(user = it, isLoading = false, updateSuccess = true) },
                onFailure = { _uiState.value = _uiState.value.copy(errorMessage = it.message, isLoading = false) },
            )
        }
    }

    fun logout() {
        viewModelScope.launch { authRepository.logout() }
    }

    fun deleteAccount() {
        viewModelScope.launch {
            authRepository.deleteMe().fold(
                onSuccess = { /* handled by navigation */ },
                onFailure = { _uiState.value = _uiState.value.copy(errorMessage = it.message) },
            )
        }
    }

    fun clearUpdateSuccess() {
        _uiState.value = _uiState.value.copy(updateSuccess = false)
    }
}
