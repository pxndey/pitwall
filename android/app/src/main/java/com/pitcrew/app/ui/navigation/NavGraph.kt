package com.pitcrew.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.pitcrew.app.ui.auth.LoginScreen
import com.pitcrew.app.ui.auth.SignUpScreen
import com.pitcrew.app.ui.home.HomeScreen
import com.pitcrew.app.ui.lapchart.LapChartScreen
import com.pitcrew.app.ui.onboarding.OnboardingScreen
import com.pitcrew.app.ui.profile.ProfileScreen
import com.pitcrew.app.ui.schedule.ScheduleScreen
import com.pitcrew.app.ui.splash.SplashScreen
import com.pitcrew.app.ui.standings.DriverDetailScreen
import com.pitcrew.app.ui.standings.StandingsScreen
import com.pitcrew.app.ui.theme.PitCrewRed
import com.pitcrew.app.ui.theme.PitCrewTabBarBg
import com.pitcrew.app.ui.theme.PitCrewTertiaryText

object Routes {
    const val SPLASH = "splash"
    const val LOGIN = "login"
    const val SIGNUP = "signup"
    const val ONBOARDING = "onboarding"
    const val MAIN = "main"
    const val HOME = "home"
    const val SCHEDULE = "schedule"
    const val STANDINGS = "standings"
    const val PROFILE = "profile"
    const val DRIVER_DETAIL = "driverDetail/{driverId}/{driverName}"
    const val LAP_CHART = "lapChart/{season}/{round}/{raceName}"
}

data class BottomNavItem(
    val route: String,
    val label: String,
    val icon: ImageVector,
)

val bottomNavItems = listOf(
    BottomNavItem(Routes.HOME, "Home", Icons.Default.Home),
    BottomNavItem(Routes.SCHEDULE, "Schedule", Icons.Default.CalendarMonth),
    BottomNavItem(Routes.STANDINGS, "Standings", Icons.Default.EmojiEvents),
    BottomNavItem(Routes.PROFILE, "Profile", Icons.Default.Person),
)

@Composable
fun NavGraph() {
    val rootNavController = rememberNavController()

    NavHost(navController = rootNavController, startDestination = Routes.SPLASH) {
        composable(Routes.SPLASH) {
            SplashScreen(
                onNavigateToLogin = {
                    rootNavController.navigate(Routes.LOGIN) {
                        popUpTo(Routes.SPLASH) { inclusive = true }
                    }
                },
                onNavigateToOnboarding = {
                    rootNavController.navigate(Routes.ONBOARDING) {
                        popUpTo(Routes.SPLASH) { inclusive = true }
                    }
                },
                onNavigateToMain = {
                    rootNavController.navigate(Routes.MAIN) {
                        popUpTo(Routes.SPLASH) { inclusive = true }
                    }
                },
            )
        }

        composable(Routes.LOGIN) {
            LoginScreen(
                onLoginSuccess = {
                    rootNavController.navigate(Routes.MAIN) {
                        popUpTo(Routes.LOGIN) { inclusive = true }
                    }
                },
                onNavigateToSignUp = {
                    rootNavController.navigate(Routes.SIGNUP)
                },
            )
        }

        composable(Routes.SIGNUP) {
            SignUpScreen(
                onSignUpSuccess = {
                    rootNavController.navigate(Routes.ONBOARDING) {
                        popUpTo(Routes.SIGNUP) { inclusive = true }
                    }
                },
                onNavigateBack = { rootNavController.popBackStack() },
            )
        }

        composable(Routes.ONBOARDING) {
            OnboardingScreen(
                onComplete = {
                    rootNavController.navigate(Routes.MAIN) {
                        popUpTo(Routes.ONBOARDING) { inclusive = true }
                    }
                },
            )
        }

        composable(Routes.MAIN) {
            MainScreen(rootNavController = rootNavController)
        }

        composable(
            route = Routes.DRIVER_DETAIL,
            arguments = listOf(
                navArgument("driverId") { type = NavType.StringType },
                navArgument("driverName") { type = NavType.StringType },
            ),
        ) { backStackEntry ->
            DriverDetailScreen(
                driverId = backStackEntry.arguments?.getString("driverId") ?: "",
                driverName = backStackEntry.arguments?.getString("driverName") ?: "",
                onBack = { rootNavController.popBackStack() },
            )
        }

        composable(
            route = Routes.LAP_CHART,
            arguments = listOf(
                navArgument("season") { type = NavType.IntType },
                navArgument("round") { type = NavType.IntType },
                navArgument("raceName") { type = NavType.StringType },
            ),
        ) { backStackEntry ->
            LapChartScreen(
                season = backStackEntry.arguments?.getInt("season") ?: 2025,
                round = backStackEntry.arguments?.getInt("round") ?: 1,
                raceName = backStackEntry.arguments?.getString("raceName") ?: "",
                onBack = { rootNavController.popBackStack() },
            )
        }
    }
}

@Composable
fun MainScreen(rootNavController: androidx.navigation.NavHostController) {
    val tabNavController = rememberNavController()
    val navBackStackEntry by tabNavController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    Scaffold(
        containerColor = Color.Transparent,
        bottomBar = {
            NavigationBar(
                containerColor = PitCrewTabBarBg,
                contentColor = Color.White,
            ) {
                bottomNavItems.forEach { item ->
                    val selected = currentDestination?.hierarchy?.any { it.route == item.route } == true
                    NavigationBarItem(
                        icon = { Icon(item.icon, contentDescription = item.label) },
                        label = { Text(item.label) },
                        selected = selected,
                        onClick = {
                            tabNavController.navigate(item.route) {
                                popUpTo(tabNavController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = PitCrewRed,
                            selectedTextColor = PitCrewRed,
                            unselectedIconColor = PitCrewTertiaryText,
                            unselectedTextColor = PitCrewTertiaryText,
                            indicatorColor = Color.Transparent,
                        ),
                    )
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = tabNavController,
            startDestination = Routes.HOME,
            modifier = Modifier.padding(innerPadding),
        ) {
            composable(Routes.HOME) { HomeScreen() }
            composable(Routes.SCHEDULE) {
                ScheduleScreen(
                    onNavigateToLapChart = { season, round, raceName ->
                        rootNavController.navigate("lapChart/$season/$round/$raceName")
                    },
                )
            }
            composable(Routes.STANDINGS) {
                StandingsScreen(
                    onDriverClick = { driverId, driverName ->
                        rootNavController.navigate("driverDetail/$driverId/$driverName")
                    },
                )
            }
            composable(Routes.PROFILE) {
                ProfileScreen(
                    onLogout = {
                        rootNavController.navigate(Routes.LOGIN) {
                            popUpTo(Routes.MAIN) { inclusive = true }
                        }
                    },
                )
            }
        }
    }
}
