# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Firebase Auth — в release (R8) сесията се губеше при рестарт, защото
# реалната имплементация на firebase_auth живее в този GMS internal пакет,
# който НЕ се покрива от com.google.firebase.**. Без keep R8 го обфускира
# и persistence-ът на потребителя се чупи.
-keep class com.google.android.gms.internal.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.internal.**

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

# android_alarm_manager_plus — prevent R8 from removing broadcast receiver
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }
