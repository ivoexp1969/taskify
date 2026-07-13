package com.ivoexp.taskify

import android.content.Context
import org.json.JSONObject

/// Локален контекст в widget-а (диференциаторът на Taskify): изтичащ документ,
/// имен ден, официален празник. Текстовете идват готови и локализирани от Dart
/// (WidgetService), записани в SharedPreferences ключ `flutter.widget_context`.
///
/// Dart записва САМО наличните и САМО ако потребителят е Pro и функциите са
/// включени → тук няма логика за gating, просто липсва ключ.
object WidgetContext {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val CONTEXT_KEY = "flutter.widget_context"

    /// Приоритет: изтичащ документ > имен ден > празник. null, ако няма нищо.
    fun line(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(CONTEXT_KEY, null)
        if (raw.isNullOrEmpty()) return null
        return try {
            val obj = JSONObject(raw)
            for (key in listOf("docExpiry", "nameDay", "holiday")) {
                val value = obj.optString(key, "")
                if (value.isNotEmpty()) return value
            }
            null
        } catch (e: Exception) {
            null
        }
    }
}
