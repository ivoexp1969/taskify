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

class TaskWidgetLargeProvider : AppWidgetProvider() {
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
                val widgetComponent = ComponentName(context, TaskWidgetLargeProvider::class.java)
                for (id in appWidgetManager.getAppWidgetIds(widgetComponent)) { updateAppWidget(context, appWidgetManager, id) }
            }
        }
    }
    companion object {
        const val ACTION_COMPLETE_TASK = "com.ivoexp.taskify.ACTION_COMPLETE_TASK_LARGE"
        const val EXTRA_TASK_KEY = "task_key"
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val TASKS_KEY = "flutter.widget_tasks"
        const val LANGUAGE_KEY = "flutter.app_language"
        private fun setPriorityDot(views: RemoteViews, dotId: Int, priority: Int) {
            if (priority > 0) {
                val color = when (priority) {
                    3 -> 0xFFEF5350.toInt()
                    2 -> 0xFFFFB74D.toInt()
                    else -> 0xFF64B5F6.toInt()
                }
                views.setViewVisibility(dotId, View.VISIBLE)
                views.setTextColor(dotId, color)
            } else {
                views.setViewVisibility(dotId, View.GONE)
            }
        }

        private fun getEmptyMessage(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lang = prefs.getString(LANGUAGE_KEY, "bg") ?: "bg"
            return WidgetPhrases.random(lang)
        }

        private fun getTaskCountText(count: Int, context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lang = prefs.getString(LANGUAGE_KEY, "bg") ?: "bg"
            return when (lang) {
                "bg" -> "$count задачи"
                "de" -> "$count Aufgaben"
                "fr" -> "$count tâches"
                "it" -> "$count attività"
                "es" -> "$count tareas"
                "pt" -> "$count tarefas"
                "ru" -> "$count задач"
                "el" -> "$count εργασίες"
                "tr" -> "$count görev"
                else -> "$count tasks"
            }
        }

        private fun getErrorText(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lang = prefs.getString(LANGUAGE_KEY, "bg") ?: "bg"
            return when (lang) {
                "bg" -> "Грешка"
                "de" -> "Fehler"
                "fr" -> "Erreur"
                "it" -> "Errore"
                "es" -> "Error"
                "pt" -> "Erro"
                "ru" -> "Ошибка"
                "el" -> "Σφάλμα"
                "tr" -> "Hata"
                else -> "Error"
            }
        }

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.task_widget_large)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val tasksJson = prefs.getString(TASKS_KEY, "[]") ?: "[]"
            try {
                val tasksArray = JSONArray(tasksJson)
                val tasks = mutableListOf<JSONObject>()
                for (i in 0 until tasksArray.length()) {
                    val t = tasksArray.getJSONObject(i)
                    if (!t.optBoolean("isCompleted", false)) tasks.add(t)
                }
                data class WidgetRow(val rowId: Int, val titleId: Int, val checkboxId: Int, val dotId: Int)
                val rows = listOf(
                    WidgetRow(R.id.task_row_1, R.id.task_title_1, R.id.task_checkbox_1, R.id.priority_dot_1),
                    WidgetRow(R.id.task_row_2, R.id.task_title_2, R.id.task_checkbox_2, R.id.priority_dot_2),
                    WidgetRow(R.id.task_row_3, R.id.task_title_3, R.id.task_checkbox_3, R.id.priority_dot_3),
                    WidgetRow(R.id.task_row_4, R.id.task_title_4, R.id.task_checkbox_4, R.id.priority_dot_4),
                    WidgetRow(R.id.task_row_5, R.id.task_title_5, R.id.task_checkbox_5, R.id.priority_dot_5))
                if (tasks.isEmpty()) {
                    views.setTextViewText(R.id.widget_title, "Taskify")
                    views.setViewVisibility(R.id.empty_container, View.VISIBLE)
                    views.setTextViewText(R.id.empty_text, getEmptyMessage(context))
                    rows.forEach { views.setViewVisibility(it.rowId, View.GONE) }
                } else {
                    views.setTextViewText(R.id.widget_title, getTaskCountText(tasks.size, context))
                    views.setViewVisibility(R.id.empty_container, View.GONE)
                    for (i in 0 until 5) {
                        val row = rows[i]
                        if (i < tasks.size) {
                            val task = tasks[i]
                            val key = task.optInt("key", -1)
                            views.setViewVisibility(row.rowId, View.VISIBLE)
                            views.setTextViewText(row.titleId, task.optString("title", ""))
                            setPriorityDot(views, row.dotId, task.optInt("priority", 0))
                            val intent = Intent(context, TaskWidgetLargeProvider::class.java).apply {
                                action = ACTION_COMPLETE_TASK
                                putExtra(EXTRA_TASK_KEY, key)
                                data = Uri.parse("taskify://complete_large/$key")
                            }
                            views.setOnClickPendingIntent(row.checkboxId, PendingIntent.getBroadcast(context, key + 1000, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE))
                        } else { views.setViewVisibility(row.rowId, View.GONE) }
                    }
                }
            } catch (e: Exception) {
                views.setViewVisibility(R.id.empty_container, View.VISIBLE)
                views.setTextViewText(R.id.empty_text, getErrorText(context))
                listOf(R.id.task_row_1, R.id.task_row_2, R.id.task_row_3, R.id.task_row_4, R.id.task_row_5).forEach { views.setViewVisibility(it, View.GONE) }
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
