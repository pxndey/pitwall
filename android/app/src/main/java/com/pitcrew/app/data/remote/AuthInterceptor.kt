package com.pitcrew.app.data.remote

import android.content.Context
import androidx.datastore.preferences.core.stringPreferencesKey
import com.pitcrew.app.data.repository.dataStore
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.Response

class AuthInterceptor(
    private val context: Context,
) : Interceptor {

    private val tokenKey = stringPreferencesKey("access_token")

    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()

        val path = original.url.encodedPath
        if (path.endsWith("/login") || path.endsWith("/signup")) {
            return chain.proceed(original)
        }

        val token = runBlocking {
            context.dataStore.data.map { it[tokenKey] }.firstOrNull()
        }

        val request = if (token != null) {
            original.newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
        } else {
            original
        }

        return chain.proceed(request)
    }
}
