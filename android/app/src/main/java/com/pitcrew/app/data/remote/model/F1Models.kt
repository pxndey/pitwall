package com.pitcrew.app.data.remote.model

import com.google.gson.annotations.SerializedName

data class DriverStanding(
    val position: Any?,
    val points: Any?,
    val wins: Any?,
    val givenName: String?,
    val familyName: String?,
    val driverId: String?,
    val constructorName: String?,
) {
    val positionInt: Int get() = when (position) {
        is Number -> position.toInt()
        is String -> position.toIntOrNull() ?: 0
        else -> 0
    }
    val pointsFloat: Float get() = when (points) {
        is Number -> points.toFloat()
        is String -> points.toFloatOrNull() ?: 0f
        else -> 0f
    }
    val winsInt: Int get() = when (wins) {
        is Number -> wins.toInt()
        is String -> wins.toIntOrNull() ?: 0
        else -> 0
    }
}

data class ConstructorStanding(
    val position: Any?,
    val points: Any?,
    val wins: Any?,
    val name: String?,
    val constructorId: String?,
) {
    val positionInt: Int get() = when (position) {
        is Number -> position.toInt()
        is String -> position.toIntOrNull() ?: 0
        else -> 0
    }
    val pointsFloat: Float get() = when (points) {
        is Number -> points.toFloat()
        is String -> points.toFloatOrNull() ?: 0f
        else -> 0f
    }
    val winsInt: Int get() = when (wins) {
        is Number -> wins.toInt()
        is String -> wins.toIntOrNull() ?: 0
        else -> 0
    }
}

data class RaceResultResponse(
    val raceName: String?,
    val date: String?,
    @SerializedName("Results") val results: List<RaceResultEntry>?,
)

data class RaceResultEntry(
    val position: Any?,
    val points: Any?,
    @SerializedName("Driver") val driver: RaceDriver?,
    @SerializedName("Constructor") val constructor: RaceConstructor?,
) {
    val positionInt: Int get() = when (position) {
        is Number -> position.toInt()
        is String -> position.toIntOrNull() ?: 0
        else -> 0
    }
    val pointsFloat: Float get() = when (points) {
        is Number -> points.toFloat()
        is String -> points.toFloatOrNull() ?: 0f
        else -> 0f
    }
}

data class RaceDriver(
    val givenName: String?,
    val familyName: String?,
    val driverId: String?,
)

data class RaceConstructor(
    val name: String?,
    val constructorId: String?,
)

data class DriverDashboard(
    @SerializedName("driver_id") val driverId: String?,
    @SerializedName("championship_position") val championshipPosition: Int?,
    @SerializedName("championship_points") val championshipPoints: Float?,
    @SerializedName("last_race") val lastRace: DashboardLastRace?,
    @SerializedName("next_race") val nextRace: DashboardNextRace?,
    val error: String?,
)

data class DashboardLastRace(
    @SerializedName("race_name") val raceName: String?,
    val position: Any?,
    val points: Any?,
)

data class DashboardNextRace(
    @SerializedName("race_name") val raceName: String?,
    @SerializedName("circuit_name") val circuitName: String?,
    val date: String?,
)

data class LapsResponse(
    @SerializedName("Laps") val laps: List<LapData>?,
)

data class LapData(
    val number: Any?,
    @SerializedName("Timings") val timings: List<LapTiming>?,
)

data class LapTiming(
    val driverId: String?,
    val position: Any?,
    val time: String?,
) {
    val positionInt: Int get() = when (position) {
        is Number -> position.toInt()
        is String -> position.toIntOrNull() ?: 0
        else -> 0
    }
}

data class DriverSeasonResponse(
    @SerializedName("driver_info") val driverInfo: DriverInfo?,
    val standing: DriverSeasonStanding?,
    @SerializedName("season_results") val seasonResults: List<SeasonRaceResult>?,
)

data class DriverInfo(
    val driverId: String?,
    val givenName: String?,
    val familyName: String?,
    val permanentNumber: Any?,
    val nationality: String?,
)

data class DriverSeasonStanding(
    val position: Any?,
    val points: Any?,
    val constructorName: String?,
) {
    val positionInt: Int get() = when (position) {
        is Number -> position.toInt()
        is String -> position.toIntOrNull() ?: 0
        else -> 0
    }
    val pointsFloat: Float get() = when (points) {
        is Number -> points.toFloat()
        is String -> points.toFloatOrNull() ?: 0f
        else -> 0f
    }
}

data class SeasonRaceResult(
    val raceName: String?,
    val position: Any?,
    val points: Any?,
    val status: String?,
) {
    val positionInt: Int get() = when (position) {
        is Number -> position.toInt()
        is String -> position.toIntOrNull() ?: 0
        else -> 0
    }
    val pointsFloat: Float get() = when (points) {
        is Number -> points.toFloat()
        is String -> points.toFloatOrNull() ?: 0f
        else -> 0f
    }
}
