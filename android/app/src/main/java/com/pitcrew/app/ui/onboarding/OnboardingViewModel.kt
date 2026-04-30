package com.pitcrew.app.ui.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pitcrew.app.data.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    fun completeOnboarding() {
        viewModelScope.launch {
            authRepository.setOnboardingSeen()
        }
    }
}
