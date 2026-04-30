package com.pitcrew.app.data.remote

import com.pitcrew.app.data.remote.model.JolpicaConstructorsResponse
import com.pitcrew.app.data.remote.model.JolpicaDriversResponse
import com.pitcrew.app.data.remote.model.JolpicaScheduleResponse
import retrofit2.Response
import retrofit2.http.GET

interface JolpicaService {

    @GET("f1/current.json")
    suspend fun getCurrentSchedule(): Response<JolpicaScheduleResponse>

    @GET("f1/current/drivers.json")
    suspend fun getCurrentDrivers(): Response<JolpicaDriversResponse>

    @GET("f1/current/constructors.json")
    suspend fun getCurrentConstructors(): Response<JolpicaConstructorsResponse>
}
