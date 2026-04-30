plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.dagger.hilt.android")
    kotlin("kapt")
}

android {
    namespace = "com.pitcrew.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.pitcrew.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField("String", "API_BASE_URL", "\"https://pitcrew-backend.pxndey.com/\"")
        buildConfigField("String", "WS_BASE_URL", "\"wss://pitcrew-backend.pxndey.com/\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            buildConfigField("String", "API_BASE_URL", "\"https://pitcrew-backend.pxndey.com/\"")
            buildConfigField("String", "WS_BASE_URL", "\"wss://pitcrew-backend.pxndey.com/\"")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    // Compose BOM
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.3")

    // Navigation
    implementation("androidx.navigation:navigation-compose:2.8.5")

    // Lifecycle + ViewModel
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    // Hilt DI
    implementation("com.google.dagger:hilt-android:2.53.1")
    kapt("com.google.dagger:hilt-compiler:2.53.1")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")

    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("com.google.code.gson:gson:2.11.0")

    // DataStore
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Charts (Vico)
    implementation("com.patrykandpatrick.vico:compose-m3:2.0.0-beta.2")

    // WorkManager
    implementation("androidx.work:work-runtime-ktx:2.10.0")

    // Splash Screen
    implementation("androidx.core:core-splashscreen:1.0.1")

    // Foundation (HorizontalPager)
    implementation("androidx.compose.foundation:foundation")

    // Core
    implementation("androidx.core:core-ktx:1.15.0")
}

kapt {
    correctErrorTypes = true
}
