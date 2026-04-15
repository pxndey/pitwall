package com.pitwall.app.data.remote

import com.pitwall.app.data.remote.model.*
import retrofit2.Response
import retrofit2.http.*

interface ApiService {

    // Auth
    @POST("api/auth/login")
    suspend fun login(@Body request: LoginRequest): Response<TokenResponse>

    @POST("api/auth/signup")
    suspend fun signup(@Body request: SignUpRequest): Response<TokenResponse>

    @GET("api/auth/me")
    suspend fun getMe(): Response<UserOut>

    @PUT("api/auth/me")
    suspend fun updateMe(@Body request: UpdateProfileRequest): Response<UserOut>

    @DELETE("api/auth/me")
    suspend fun deleteMe(): Response<Map<String, String>>

    // Chat
    @POST("api/chat/watsonx")
    suspend fun sendMessage(@Body request: ChatRequest): Response<ChatResponse>

    @GET("api/chat/history")
    suspend fun getChatHistory(
        @Query("offset") offset: Int = 0,
        @Query("limit") limit: Int = 30,
        @Query("conversation_id") conversationId: String? = null,
    ): Response<List<ChatMessageOut>>

    @GET("api/chat/search")
    suspend fun searchChat(
        @Query("q") query: String,
        @Query("limit") limit: Int = 20,
    ): Response<List<ChatMessageOut>>

    @GET("api/chat/conversations")
    suspend fun getConversations(): Response<List<ConversationOut>>

    @POST("api/chat/conversations")
    suspend fun createConversation(
        @Body request: CreateConversationRequest,
    ): Response<ConversationOut>

    @DELETE("api/chat/conversations/{id}")
    suspend fun deleteConversation(@Path("id") id: String): Response<Map<String, String>>

    // F1 Data
    @GET("api/f1/driver-dashboard")
    suspend fun getDriverDashboard(): Response<DriverDashboard>

    @GET("api/f1/standings/drivers")
    suspend fun getDriverStandings(
        @Query("season") season: Int = 2025,
    ): Response<List<DriverStanding>>

    @GET("api/f1/standings/constructors")
    suspend fun getConstructorStandings(
        @Query("season") season: Int = 2025,
    ): Response<List<ConstructorStanding>>

    @GET("api/f1/race-results/{season}/{round}")
    suspend fun getRaceResults(
        @Path("season") season: Int,
        @Path("round") round: Int,
    ): Response<RaceResultResponse>

    @GET("api/f1/laps/{season}/{round}")
    suspend fun getLaps(
        @Path("season") season: Int,
        @Path("round") round: Int,
    ): Response<LapsResponse>

    @GET("api/f1/driver/{driverId}/season/{season}")
    suspend fun getDriverSeason(
        @Path("driverId") driverId: String,
        @Path("season") season: Int = 2025,
    ): Response<DriverSeasonResponse>
}
