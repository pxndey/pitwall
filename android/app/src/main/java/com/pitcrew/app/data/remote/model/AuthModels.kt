package com.pitcrew.app.data.remote.model

import com.google.gson.annotations.SerializedName

data class LoginRequest(
    val username: String,
    val password: String,
)

data class SignUpRequest(
    val username: String,
    val name: String? = null,
    val email: String,
    val password: String,
    @SerializedName("fav_driver") val favDriver: String? = null,
    @SerializedName("fav_team") val favTeam: String? = null,
    val language: String = "en",
)

data class TokenResponse(
    @SerializedName("access_token") val accessToken: String,
    @SerializedName("token_type") val tokenType: String,
)

data class UserOut(
    val id: String,
    val username: String,
    val name: String?,
    val email: String,
    @SerializedName("fav_driver") val favDriver: String?,
    @SerializedName("fav_team") val favTeam: String?,
    val language: String?,
    @SerializedName("created_at") val createdAt: String?,
)

data class UpdateProfileRequest(
    val name: String? = null,
    val email: String? = null,
    val password: String? = null,
    @SerializedName("fav_driver") val favDriver: String? = null,
    @SerializedName("fav_team") val favTeam: String? = null,
    val language: String? = null,
)
