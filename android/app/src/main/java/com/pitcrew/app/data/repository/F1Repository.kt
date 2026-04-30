package com.pitcrew.app.data.repository

import com.pitcrew.app.data.remote.ApiService
import com.pitcrew.app.data.remote.JolpicaService
import com.pitcrew.app.data.remote.model.*
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class F1Repository @Inject constructor(
    private val apiService: ApiService,
    private val jolpicaService: JolpicaService,
) {
    suspend fun getDriverStandings(season: Int = 2025): Result<List<DriverStanding>> {
        return try {
            val response = apiService.getDriverStandings(season)
            if (response.isSuccessful) {
                Result.success(response.body() ?: emptyList())
            } else {
                Result.failure(Exception("Failed to load driver standings"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getConstructorStandings(season: Int = 2025): Result<List<ConstructorStanding>> {
        return try {
            val response = apiService.getConstructorStandings(season)
            if (response.isSuccessful) {
                Result.success(response.body() ?: emptyList())
            } else {
                Result.failure(Exception("Failed to load constructor standings"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getRaceResults(season: Int, round: Int): Result<RaceResultResponse> {
        return try {
            val response = apiService.getRaceResults(season, round)
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception("Failed to load race results"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getDriverDashboard(): Result<DriverDashboard> {
        return try {
            val response = apiService.getDriverDashboard()
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception("Failed to load dashboard"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getLaps(season: Int, round: Int): Result<LapsResponse> {
        return try {
            val response = apiService.getLaps(season, round)
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception("Failed to load lap data"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getDriverSeason(driverId: String, season: Int = 2025): Result<DriverSeasonResponse> {
        return try {
            val response = apiService.getDriverSeason(driverId, season)
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception("Failed to load driver season"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // Jolpica (external F1 API)

    suspend fun getSchedule(): Result<List<JolpicaRace>> {
        return try {
            val response = jolpicaService.getCurrentSchedule()
            if (response.isSuccessful) {
                val races = response.body()?.mrData?.raceTable?.races ?: emptyList()
                Result.success(races)
            } else {
                Result.failure(Exception("Failed to load schedule"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getDriversList(): Result<List<JolpicaDriver>> {
        return try {
            val response = jolpicaService.getCurrentDrivers()
            if (response.isSuccessful) {
                val drivers = response.body()?.mrData?.driverTable?.drivers ?: emptyList()
                Result.success(drivers)
            } else {
                Result.failure(Exception("Failed to load drivers"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getConstructorsList(): Result<List<JolpicaConstructor>> {
        return try {
            val response = jolpicaService.getCurrentConstructors()
            if (response.isSuccessful) {
                val constructors = response.body()?.mrData?.constructorTable?.constructors ?: emptyList()
                Result.success(constructors)
            } else {
                Result.failure(Exception("Failed to load constructors"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
