# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# Hive
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# Play Core library (missing classes fix)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
