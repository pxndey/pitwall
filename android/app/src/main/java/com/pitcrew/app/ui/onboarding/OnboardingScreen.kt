package com.pitcrew.app.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pitcrew.app.ui.theme.*
import kotlinx.coroutines.launch

data class OnboardingPage(
    val icon: ImageVector,
    val title: String,
    val description: String,
)

val onboardingPages = listOf(
    OnboardingPage(Icons.Default.RocketLaunch, "Welcome to PitCrew", "Your personal AI-powered Formula 1 engineer, right in your pocket."),
    OnboardingPage(Icons.Default.SmartToy, "AI Race Engineer", "Ask anything about F1 — race strategies, driver stats, head-to-head comparisons, and more."),
    OnboardingPage(Icons.Default.CalendarMonth, "Race Schedule", "Stay on top of every race weekend with the full calendar and session notifications."),
    OnboardingPage(Icons.Default.Tune, "Your Preferences", "Set your favourite driver and team to get personalized insights and dashboards."),
)

@Composable
fun OnboardingScreen(
    onComplete: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val pagerState = rememberPagerState(pageCount = { onboardingPages.size })
    val scope = rememberCoroutineScope()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PitCrewBackground),
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) { page ->
                val item = onboardingPages[page]
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 40.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(
                        imageVector = item.icon,
                        contentDescription = null,
                        tint = PitCrewRed,
                        modifier = Modifier.size(80.dp),
                    )
                    Spacer(modifier = Modifier.height(32.dp))
                    Text(
                        text = item.title,
                        color = Color.White,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = item.description,
                        color = PitCrewSecondaryText,
                        fontSize = 16.sp,
                        textAlign = TextAlign.Center,
                        lineHeight = 24.sp,
                    )
                }
            }

            // Page indicator
            Row(
                modifier = Modifier.padding(bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                repeat(onboardingPages.size) { index ->
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (index == pagerState.currentPage) PitCrewRed else PitCrewTertiaryText),
                    )
                }
            }

            // Button
            Button(
                onClick = {
                    if (pagerState.currentPage < onboardingPages.size - 1) {
                        scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                    } else {
                        viewModel.completeOnboarding()
                        onComplete()
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .padding(bottom = 48.dp)
                    .height(50.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PitCrewRed),
                shape = RoundedCornerShape(10.dp),
            ) {
                Text(
                    text = if (pagerState.currentPage < onboardingPages.size - 1) "Next" else "Get Started",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 16.sp,
                )
            }
        }
    }
}
