# Retrofit
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.pitwall.app.data.remote.model.** { *; }
-keepclassmembers class com.pitwall.app.data.remote.model.** { *; }

# Gson
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
