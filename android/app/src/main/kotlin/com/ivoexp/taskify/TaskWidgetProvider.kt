package com.ivoexp.taskify

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.content.ComponentName
import android.net.Uri
import android.view.View
import org.json.JSONArray
import org.json.JSONObject

class TaskWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) { updateAppWidget(context, appWidgetManager, appWidgetId) }
    }
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_COMPLETE_TASK) {
            val taskKey = intent.getIntExtra(EXTRA_TASK_KEY, -1)
            if (taskKey != -1) {
                markTaskCompleted(context, taskKey)
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val widgetComponent = ComponentName(context, TaskWidgetProvider::class.java)
                for (id in appWidgetManager.getAppWidgetIds(widgetComponent)) { updateAppWidget(context, appWidgetManager, id) }
            }
        }
    }
    companion object {
        const val ACTION_COMPLETE_TASK = "com.ivoexp.taskify.ACTION_COMPLETE_TASK"
        const val EXTRA_TASK_KEY = "task_key"
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val TASKS_KEY = "flutter.widget_tasks"
        const val LANGUAGE_KEY = "flutter.app_language"

        private fun isBg(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getString(LANGUAGE_KEY, "bg") == "bg"
        }

        private fun getEmptyMessage(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lang = prefs.getString(LANGUAGE_KEY, "bg") ?: "bg"
            val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
            val index = hour % 4
            
            val messages = when (lang) {
                "bg" -> listOf("🤔 Няма ли да свършим нещо?", "🎉 Свободен ден!", "✅ Всичко е готово!", "😎 Време за почивка!")
                "en" -> listOf("🤔 Nothing to do today?", "🎉 Free day!", "✅ All done!", "😎 Time to relax!")
                "de" -> listOf("🤔 Nichts zu tun heute?", "🎉 Freier Tag!", "✅ Alles erledigt!", "😎 Zeit zum Entspannen!")
                "fr" -> listOf("🤔 Rien à faire?", "🎉 Journée libre!", "✅ Tout est fait!", "😎 Temps de repos!")
                "it" -> listOf("🤔 Niente da fare oggi?", "🎉 Giorno libero!", "✅ Tutto fatto!", "😎 Tempo di relax!")
                "es" -> listOf("🤔 ¿Nada que hacer?", "🎉 ¡Día libre!", "✅ ¡Todo listo!", "😎 ¡A descansar!")
                "pt" -> listOf("🤔 Nada para fazer?", "🎉 Dia livre!", "✅ Tudo pronto!", "😎 Hora de relaxar!")
                "ru" -> listOf("🤔 Нечего делать?", "🎉 Свободный день!", "✅ Всё готово!", "😎 Время отдыхать!")
                "el" -> listOf("🤔 Τίποτα για σήμερα;", "🎉 Ελεύθερη μέρα!", "✅ Όλα έτοιμα!", "😎 Ώρα για χαλάρωση!")
                "tr" -> listOf("🤔 Yapacak bir şey yok?", "🎉 Boş gün!", "✅ Her şey tamam!", "😎 Dinlenme zamanı!")
                else -> listOf("🤔 Nothing to do today?", "🎉 Free day!", "✅ All done!", "😎 Time to relax!")
            }
            return messages[index]
        }


        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.task_widget)
            val isBg = isBg(context)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val tasksJson = prefs.getString(TASKS_KEY, "[]") ?: "[]"
            try {
                val tasksArray = JSONArray(tasksJson)
                val tasks = mutableListOf<JSONObject>()
                for (i in 0 until tasksArray.length()) {
                    val t = tasksArray.getJSONObject(i)
                    if (!t.optBoolean("isCompleted", false)) tasks.add(t)
                }
                val rows = listOf(
                    Triple(R.id.task_row_1, R.id.task_title_1, R.id.task_checkbox_1),
                    Triple(R.id.task_row_2, R.id.task_title_2, R.id.task_checkbox_2),
                    Triple(R.id.task_row_3, R.id.task_title_3, R.id.task_checkbox_3))
                if (tasks.isEmpty()) {
                    views.setTextViewText(R.id.widget_title, "Taskify")
                    views.setViewVisibility(R.id.empty_container, View.VISIBLE)
                    views.setTextViewText(R.id.empty_text, getEmptyMessage(context))
                    rows.forEach { views.setViewVisibility(it.first, View.GONE) }
                } else {
                    views.setTextViewText(R.id.widget_title, if (isBg) "${tasks.size} задачи" else "${tasks.size} tasks")
                    views.setViewVisibility(R.id.empty_container, View.GONE)
                    for (i in 0 until 3) {
                        val (rowId, titleId, checkboxId) = rows[i]
                        if (i < tasks.size) {
                            val task = tasks[i]
                            val key = task.optInt("key", -1)
                            views.setViewVisibility(rowId, View.VISIBLE)
                            views.setTextViewText(titleId, task.optString("title", ""))
                            val intent = Intent(context, TaskWidgetProvider::class.java).apply {
                                action = ACTION_COMPLETE_TASK
                                putExtra(EXTRA_TASK_KEY, key)
                                data = Uri.parse("taskify://complete/$key")
                            }
                            views.setOnClickPendingIntent(checkboxId, PendingIntent.getBroadcast(context, key, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE))
                        } else { views.setViewVisibility(rowId, View.GONE) }
                    }
                }
            } catch (e: Exception) {
                views.setViewVisibility(R.id.empty_container, View.VISIBLE)
                views.setTextViewText(R.id.empty_text, if (isBg) "Грешка" else "Error")
                listOf(R.id.task_row_1, R.id.task_row_2, R.id.task_row_3).forEach { views.setViewVisibility(it, View.GONE) }
            }
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                views.setOnClickPendingIntent(R.id.widget_container, PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun markTaskCompleted(context: Context, taskKey: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val tasksJson = prefs.getString(TASKS_KEY, "[]") ?: "[]"
            try {
                val arr = JSONArray(tasksJson)
                val newArr = JSONArray()
                for (i in 0 until arr.length()) {
                    val t = arr.getJSONObject(i)
                    if (t.optInt("key", -1) == taskKey) t.put("isCompleted", true)
                    newArr.put(t)
                }
                prefs.edit().putString(TASKS_KEY, newArr.toString()).apply()
            } catch (e: Exception) {}
        }
    }
}
