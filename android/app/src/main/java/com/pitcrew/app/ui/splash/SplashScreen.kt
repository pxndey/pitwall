package com.pitcrew.app.ui.splash

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.RocketLaunch
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pitcrew.app.ui.theme.PitCrewBackground
import com.pitcrew.app.ui.theme.PitCrewRed
import kotlinx.coroutines.delay

@Composable
fun SplashScreen(
    onNavigateToLogin: () -> Unit,
    onNavigateToOnboarding: () -> Unit,
    onNavigateToMain: () -> Unit,
    viewModel: SplashViewModel = hiltViewModel(),
) {
    var visible by remember { mutableStateOf(false) }
    val alpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(durationMillis = 1000),
        label = "splash_fade",
    )

    val navTarget by viewModel.navigationTarget.collectAsState()

    LaunchedEffect(Unit) {
        visible = true
        delay(2000)
        viewModel.checkAuthState()
    }

    LaunchedEffect(navTarget) {
        when (navTarget) {
            SplashNavTarget.LOGIN -> onNavigateToLogin()
            SplashNavTarget.ONBOARDING -> onNavigateToOnboarding()
            SplashNavTarget.MAIN -> onNavigateToMain()
            null -> {}
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PitCrewBackground),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.alpha(alpha),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(
                imageVector = Icons.Default.RocketLaunch,
                contentDescription = null,
                tint = PitCrewRed,
                modifier = Modifier.size(64.dp),
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "PITCREW",
                color = Color.White,
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 4.sp,
            )
        }
    }
}
