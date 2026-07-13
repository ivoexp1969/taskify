package com.ivoexp.taskify

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ivoexp.taskify/widget"
    private val PREFS_NAME = "widget_prefs"
    private val KEY_WIDGET_PROMPTED = "widget_prompted_v6"

    /// Действие от widget-а („+" → нова задача), което Dart още не е консумирал.
    private var pendingWidgetAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureWidgetAction(intent) // студен старт от „+"
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        captureWidgetAction(intent) // приложението вече върви (singleTop)
    }

    private fun captureWidgetAction(intent: Intent?) {
        if (intent?.action == WidgetActions.ACTION_NEW_TASK) {
            pendingWidgetAction = "new_task"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> { updateWidgets(); result.success(true) }
                "requestPinWidget" -> { requestPinWidget(); result.success(true) }
                // Dart пита при старт и при resume; връща действието веднъж.
                "consumeWidgetAction" -> {
                    val action = pendingWidgetAction
                    pendingWidgetAction = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        promptWidgetIfNeeded()
        // Освежаваме widget-ите при всяко връщане на преден план — така
        // закачливата фраза в празно състояние се сменя често (произволно).
        updateWidgets()
    }

    private fun promptWidgetIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(KEY_WIDGET_PROMPTED, false)) {
                prefs.edit().putBoolean(KEY_WIDGET_PROMPTED, true).apply()
                requestPinWidget()
            }
        }
    }

    private fun requestPinWidget() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val appWidgetManager = AppWidgetManager.getInstance(this)
            if (appWidgetManager.isRequestPinAppWidgetSupported) {
                val provider = ComponentName(this, TaskWidgetProvider::class.java)
                appWidgetManager.requestPinAppWidget(provider, null, null)
            }
        }
    }

    private fun updateWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val smallIds = appWidgetManager.getAppWidgetIds(ComponentName(this, TaskWidgetProvider::class.java))
        for (id in smallIds) { TaskWidgetProvider.updateAppWidget(this, appWidgetManager, id) }
        val largeIds = appWidgetManager.getAppWidgetIds(ComponentName(this, TaskWidgetLargeProvider::class.java))
        for (id in largeIds) { TaskWidgetLargeProvider.updateAppWidget(this, appWidgetManager, id) }
        val mediumIds = appWidgetManager.getAppWidgetIds(ComponentName(this, TaskWidgetMediumProvider::class.java))
        for (id in mediumIds) { TaskWidgetMediumProvider.updateAppWidget(this, appWidgetManager, id) }
    }
}
