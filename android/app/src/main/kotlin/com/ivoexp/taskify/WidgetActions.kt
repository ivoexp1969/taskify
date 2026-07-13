package com.ivoexp.taskify

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri

/// Бързо добавяне от widget-а: „+" отваря приложението директно на редактора
/// за нова задача. PendingIntent-ът е getActivity (системата стартира
/// активността → няма background-activity-start ограничение).
///
/// MainActivity прихваща action-а (onCreate/onNewIntent) и го подава на Dart
/// през MethodChannel-а („consumeWidgetAction") → TaskEditorBridge.
object WidgetActions {
    const val ACTION_NEW_TASK = "com.ivoexp.taskify.ACTION_NEW_TASK"

    /// requestCode различава PendingIntent-ите на трите размера widget.
    fun newTaskPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_NEW_TASK
            // Уникална data → intent-ът се доставя в onNewIntent (singleTop),
            // вместо просто да се извади наяве старият task без известие.
            data = Uri.parse("taskify://new_task")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
