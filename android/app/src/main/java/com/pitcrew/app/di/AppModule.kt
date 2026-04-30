package com.pitcrew.app.di

import android.content.Context
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.pitcrew.app.data.remote.ApiService
import com.pitcrew.app.data.remote.AuthInterceptor
import com.pitcrew.app.data.remote.JolpicaService
import com.pitcrew.app.data.remote.WebSocketManager
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import com.pitcrew.app.BuildConfig
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    private val BASE_URL: String get() = BuildConfig.API_BASE_URL
    private const val JOLPICA_URL = "https://api.jolpi.ca/ergast/"

    @Provides
    @Singleton
    fun provideGson(): Gson = GsonBuilder().create()

    @Provides
    @Singleton
    fun provideAuthInterceptor(
        @ApplicationContext context: Context,
    ): AuthInterceptor = AuthInterceptor(context)

    @Provides
    @Singleton
    fun provideOkHttpClient(authInterceptor: AuthInterceptor): OkHttpClient {
        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        }
        return OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .addInterceptor(logging)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideApiService(okHttpClient: OkHttpClient, gson: Gson): ApiService {
        return Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create(gson))
            .build()
            .create(ApiService::class.java)
    }

    @Provides
    @Singleton
    fun provideJolpicaService(gson: Gson): JolpicaService {
        val client = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
        return Retrofit.Builder()
            .baseUrl(JOLPICA_URL)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create(gson))
            .build()
            .create(JolpicaService::class.java)
    }

    @Provides
    @Singleton
    fun provideWebSocketManager(okHttpClient: OkHttpClient, gson: Gson): WebSocketManager {
        return WebSocketManager(okHttpClient, gson)
    }
}
