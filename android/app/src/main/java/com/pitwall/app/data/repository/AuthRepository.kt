package com.pitwall.app.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.pitwall.app.data.remote.ApiService
import com.pitwall.app.data.remote.model.*
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "pitwall_prefs")

@Singleton
class AuthRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val apiService: ApiService,
) {
    companion object {
        val TOKEN_KEY = stringPreferencesKey("access_token")
        val ONBOARDING_KEY = booleanPreferencesKey("has_seen_onboarding")
    }

    fun getToken(): Flow<String?> = context.dataStore.data.map { it[TOKEN_KEY] }

    fun hasSeenOnboarding(): Flow<Boolean> = context.dataStore.data.map { it[ONBOARDING_KEY] ?: false }

    suspend fun saveToken(token: String) {
        context.dataStore.edit { it[TOKEN_KEY] = token }
    }

    suspend fun setOnboardingSeen() {
        context.dataStore.edit { it[ONBOARDING_KEY] = true }
    }

    suspend fun clearToken() {
        context.dataStore.edit { it.remove(TOKEN_KEY) }
    }

    suspend fun login(username: String, password: String): Result<TokenResponse> {
        return try {
            val response = apiService.login(LoginRequest(username, password))
            if (response.isSuccessful && response.body() != null) {
                val token = response.body()!!
                saveToken(token.accessToken)
                Result.success(token)
            } else {
                Result.failure(Exception(response.errorBody()?.string() ?: "Login failed"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun signup(request: SignUpRequest): Result<TokenResponse> {
        return try {
            val response = apiService.signup(request)
            if (response.isSuccessful && response.body() != null) {
                val token = response.body()!!
                saveToken(token.accessToken)
                Result.success(token)
            } else {
                Result.failure(Exception(response.errorBody()?.string() ?: "Signup failed"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getMe(): Result<UserOut> {
        return try {
            val response = apiService.getMe()
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception("Failed to fetch profile"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun updateMe(request: UpdateProfileRequest): Result<UserOut> {
        return try {
            val response = apiService.updateMe(request)
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception(response.errorBody()?.string() ?: "Update failed"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun deleteMe(): Result<Unit> {
        return try {
            val response = apiService.deleteMe()
            if (response.isSuccessful) {
                clearToken()
                Result.success(Unit)
            } else {
                Result.failure(Exception("Delete failed"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun logout() {
        clearToken()
    }
}
