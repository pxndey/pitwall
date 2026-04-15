package com.pitwall.app.ui.splash

import androidx.lifecycle.ViewModel
import com.pitwall.app.data.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.firstOrNull
import javax.inject.Inject

enum class SplashNavTarget { LOGIN, ONBOARDING, MAIN }

@HiltViewModel
class SplashViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _navigationTarget = MutableStateFlow<SplashNavTarget?>(null)
    val navigationTarget: StateFlow<SplashNavTarget?> = _navigationTarget

    suspend fun checkAuthState() {
        val token = authRepository.getToken().firstOrNull()
        val hasOnboarded = authRepository.hasSeenOnboarding().firstOrNull() ?: false

        _navigationTarget.value = when {
            token == null -> SplashNavTarget.LOGIN
            !hasOnboarded -> SplashNavTarget.ONBOARDING
            else -> SplashNavTarget.MAIN
        }
    }
}
