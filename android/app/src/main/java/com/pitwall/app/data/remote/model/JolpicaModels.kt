package com.pitwall.app.data.remote.model

import com.google.gson.annotations.SerializedName

// Schedule
data class JolpicaScheduleResponse(
    @SerializedName("MRData") val mrData: MRScheduleData?,
)

data class MRScheduleData(
    @SerializedName("RaceTable") val raceTable: RaceTable?,
)

data class RaceTable(
    val season: String?,
    @SerializedName("Races") val races: List<JolpicaRace>?,
)

data class JolpicaRace(
    val season: String?,
    val round: String?,
    val raceName: String?,
    @SerializedName("Circuit") val circuit: JolpicaCircuit?,
    val date: String?,
    val time: String?,
) {
    val roundInt: Int get() = round?.toIntOrNull() ?: 0
}

data class JolpicaCircuit(
    val circuitName: String?,
    @SerializedName("Location") val location: JolpicaLocation?,
)

data class JolpicaLocation(
    val country: String?,
    val locality: String?,
)

// Drivers
data class JolpicaDriversResponse(
    @SerializedName("MRData") val mrData: MRDriverData?,
)

data class MRDriverData(
    @SerializedName("DriverTable") val driverTable: DriverTable?,
)

data class DriverTable(
    @SerializedName("Drivers") val drivers: List<JolpicaDriver>?,
)

data class JolpicaDriver(
    val driverId: String?,
    val givenName: String?,
    val familyName: String?,
)

// Constructors
data class JolpicaConstructorsResponse(
    @SerializedName("MRData") val mrData: MRConstructorData?,
)

data class MRConstructorData(
    @SerializedName("ConstructorTable") val constructorTable: ConstructorTable?,
)

data class ConstructorTable(
    @SerializedName("Constructors") val constructors: List<JolpicaConstructor>?,
)

data class JolpicaConstructor(
    val constructorId: String?,
    val name: String?,
)
