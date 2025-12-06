package com.example.task_manager

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

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == ACTION_COMPLETE_TASK) {
            val taskKey = intent.getIntExtra(EXTRA_TASK_KEY, -1)
            if (taskKey != -1) {
                markTaskCompleted(context, taskKey)
                
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val widgetComponent = ComponentName(context, TaskWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)
                for (appWidgetId in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, appWidgetId)
                }
            }
        }
    }

    companion object {
        const val ACTION_COMPLETE_TASK = "com.example.task_manager.ACTION_COMPLETE_TASK"
        const val EXTRA_TASK_KEY = "task_key"
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val TASKS_KEY = "flutter.widget_tasks"
        const val LANGUAGE_KEY = "flutter.app_language"

        private fun isBulgarian(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val langCode = prefs.getString(LANGUAGE_KEY, "bg") ?: "bg"
            return langCode == "bg"
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.task_widget)
            val isBg = isBulgarian(context)
            
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val tasksJson = prefs.getString(TASKS_KEY, "[]") ?: "[]"
            
            try {
                val tasksArray = JSONArray(tasksJson)
                val todayTasks = mutableListOf<JSONObject>()
                
                for (i in 0 until tasksArray.length()) {
                    val task = tasksArray.getJSONObject(i)
                    if (!task.optBoolean("isCompleted", false)) {
                        todayTasks.add(task)
                    }
                }
                
                val taskViews = listOf(
                    Triple(R.id.task_row_1, R.id.task_title_1, R.id.task_checkbox_1),
                    Triple(R.id.task_row_2, R.id.task_title_2, R.id.task_checkbox_2),
                    Triple(R.id.task_row_3, R.id.task_title_3, R.id.task_checkbox_3)
                )
                
                if (todayTasks.isEmpty()) {
                    views.setViewVisibility(R.id.widget_title, View.GONE)
                    views.setViewVisibility(R.id.empty_container, View.VISIBLE)
                    views.setTextViewText(R.id.empty_text, if (isBg) "Всичко е наред!" else "All done!")
                    views.setViewVisibility(R.id.task_row_1, View.GONE)
                    views.setViewVisibility(R.id.task_row_2, View.GONE)
                    views.setViewVisibility(R.id.task_row_3, View.GONE)
                } else {
                    val count = todayTasks.size
                    val title = if (isBg) {
                        if (count == 1) "1 задача за деня" else "$count задачи за деня"
                    } else {
                        if (count == 1) "1 task for today" else "$count tasks for today"
                    }
                    views.setTextViewText(R.id.widget_title, title)
                    views.setViewVisibility(R.id.widget_title, View.VISIBLE)
                    views.setViewVisibility(R.id.empty_container, View.GONE)
                    
                    for (i in 0 until 3) {
                        val (rowId, titleId, checkboxId) = taskViews[i]
                        
                        if (i < todayTasks.size) {
                            val task = todayTasks[i]
                            val taskKey = task.optInt("key", -1)
                            
                            views.setViewVisibility(rowId, View.VISIBLE)
                            views.setTextViewText(titleId, task.optString("title", ""))
                            
                            val completeIntent = Intent(context, TaskWidgetProvider::class.java).apply {
                                action = ACTION_COMPLETE_TASK
                                putExtra(EXTRA_TASK_KEY, taskKey)
                                data = Uri.parse("taskify://complete/$taskKey")
                            }
                            val pendingIntent = PendingIntent.getBroadcast(
                                context,
                                taskKey,
                                completeIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                            )
                            views.setOnClickPendingIntent(checkboxId, pendingIntent)
                        } else {
                            views.setViewVisibility(rowId, View.GONE)
                        }
                    }
                }
                
            } catch (e: Exception) {
                views.setViewVisibility(R.id.widget_title, View.GONE)
                views.setViewVisibility(R.id.empty_container, View.VISIBLE)
                views.setTextViewText(R.id.empty_text, if (isBg) "Всичко е наред!" else "All done!")
                views.setViewVisibility(R.id.task_row_1, View.GONE)
                views.setViewVisibility(R.id.task_row_2, View.GONE)
                views.setViewVisibility(R.id.task_row_3, View.GONE)
            }
            
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingLaunchIntent = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingLaunchIntent)
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun markTaskCompleted(context: Context, taskKey: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val tasksJson = prefs.getString(TASKS_KEY, "[]") ?: "[]"
            
            try {
                val tasksArray = JSONArray(tasksJson)
                val newArray = JSONArray()
                
                for (i in 0 until tasksArray.length()) {
                    val task = tasksArray.getJSONObject(i)
                    if (task.optInt("key", -1) == taskKey) {
                        task.put("isCompleted", true)
                        task.put("completedFromWidget", true)
                    }
                    newArray.put(task)
                }
                
                prefs.edit().putString(TASKS_KEY, newArray.toString()).apply()
                
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}