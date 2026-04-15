package com.pitwall.app.data.remote

import com.pitwall.app.data.repository.AuthRepository
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject

class AuthInterceptor @Inject constructor(
    private val authRepository: AuthRepository,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()

        // Skip auth header for public endpoints
        val path = original.url.encodedPath
        if (path.endsWith("/login") || path.endsWith("/signup")) {
            return chain.proceed(original)
        }

        val token = runBlocking { authRepository.getToken().firstOrNull() }

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
