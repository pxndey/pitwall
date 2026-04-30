# Retrofit
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.pitcrew.app.data.remote.model.** { *; }
-keepclassmembers class com.pitcrew.app.data.remote.model.** { *; }

# Gson
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
