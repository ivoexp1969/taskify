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
        private fun getEmptyMessage(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lang = prefs.getString(LANGUAGE_KEY, "bg") ?: "bg"
            val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
            val index = hour % 12
            
            val messages = when (lang) {
                "bg" -> listOf(
                    "🦥 Дори мързелът ти завижда",
                    "🏖️ Плажен режим: активиран",
                    "🎮 Нула задачи. Време за игри?",
                    "🧘 Вътрешен мир: постигнат",
                    "🦸 Всички задачи — победени!",
                    "🍕 Няма задачи = време за пица!",
                    "🚀 Всичко чисто. Готов за излитане!",
                    "🎵 Без задачи, само вайб",
                    "🐱 Дори котката ти е впечатлена",
                    "🌴 Рай на земята: 0 задачи",
                    "🏆 Шампион по продуктивност!",
                    "☕ Само кафе и спокойствие"
                )
                "en" -> listOf(
                    "🦥 Even sloths envy your free time",
                    "🏖️ Beach mode: activated",
                    "🎮 Zero tasks. Game time?",
                    "🧘 Inner peace: achieved",
                    "🦸 All tasks — defeated!",
                    "🍕 No tasks = pizza time!",
                    "🚀 All clear. Ready for takeoff!",
                    "🎵 No tasks, just vibes",
                    "🐱 Even your cat is impressed",
                    "🌴 Paradise found: 0 tasks",
                    "🏆 Productivity champion!",
                    "☕ Just coffee and calm"
                )
                "de" -> listOf(
                    "🦥 Selbst Faultiere beneiden dich",
                    "🏖️ Strandmodus: aktiviert",
                    "🎮 Null Aufgaben. Spielzeit?",
                    "🧘 Innerer Frieden: erreicht",
                    "🦸 Alle Aufgaben — besiegt!",
                    "🍕 Keine Aufgaben = Pizzazeit!",
                    "🚀 Alles klar. Bereit zum Abheben!",
                    "🎵 Keine Aufgaben, nur gute Laune",
                    "🐱 Selbst deine Katze staunt",
                    "🌴 Paradies gefunden: 0 Aufgaben",
                    "🏆 Produktivitäts-Champion!",
                    "☕ Nur Kaffee und Gelassenheit"
                )
                "fr" -> listOf(
                    "🦥 Même les paresseux t'envient",
                    "🏖️ Mode plage : activé",
                    "🎮 Zéro tâche. On joue ?",
                    "🧘 Paix intérieure : atteinte",
                    "🦸 Toutes les tâches — vaincues !",
                    "🍕 Pas de tâches = pizza !",
                    "🚀 Tout est clair. Prêt au décollage !",
                    "🎵 Pas de tâches, que du bon",
                    "🐱 Même ton chat est impressionné",
                    "🌴 Paradis trouvé : 0 tâches",
                    "🏆 Champion de productivité !",
                    "☕ Juste un café et du calme"
                )
                "it" -> listOf(
                    "🦥 Anche i bradipi ti invidiano",
                    "🏖️ Modalità spiaggia: attivata",
                    "🎮 Zero compiti. Si gioca?",
                    "🧘 Pace interiore: raggiunta",
                    "🦸 Tutti i compiti — sconfitti!",
                    "🍕 Niente compiti = pizza!",
                    "🚀 Tutto libero. Pronti al decollo!",
                    "🎵 Niente compiti, solo relax",
                    "🐱 Anche il gatto è colpito",
                    "🌴 Paradiso trovato: 0 compiti",
                    "🏆 Campione di produttività!",
                    "☕ Solo caffè e tranquillità"
                )
                "es" -> listOf(
                    "🦥 Hasta los perezosos te envidian",
                    "🏖️ Modo playa: activado",
                    "🎮 Cero tareas. ¿Jugamos?",
                    "🧘 Paz interior: alcanzada",
                    "🦸 ¡Todas las tareas — vencidas!",
                    "🍕 Sin tareas = ¡hora de pizza!",
                    "🚀 Todo listo. ¡Listos para despegar!",
                    "🎵 Sin tareas, solo buena onda",
                    "🐱 Hasta tu gato está impresionado",
                    "🌴 Paraíso encontrado: 0 tareas",
                    "🏆 ¡Campeón de productividad!",
                    "☕ Solo café y tranquilidad"
                )
                "pt" -> listOf(
                    "🦥 Até as preguiças te invejam",
                    "🏖️ Modo praia: ativado",
                    "🎮 Zero tarefas. Hora de jogar?",
                    "🧘 Paz interior: alcançada",
                    "🦸 Todas as tarefas — vencidas!",
                    "🍕 Sem tarefas = hora da pizza!",
                    "🚀 Tudo limpo. Pronto pra decolar!",
                    "🎵 Sem tarefas, só boa vibe",
                    "🐱 Até o gato ficou impressionado",
                    "🌴 Paraíso encontrado: 0 tarefas",
                    "🏆 Campeão de produtividade!",
                    "☕ Só café e tranquilidade"
                )
                "ru" -> listOf(
                    "🦥 Даже ленивцы тебе завидуют",
                    "🏖️ Режим пляжа: активирован",
                    "🎮 Ноль задач. Поиграем?",
                    "🧘 Внутренний покой: достигнут",
                    "🦸 Все задачи — повержены!",
                    "🍕 Нет задач = время пиццы!",
                    "🚀 Всё чисто. Готов к взлёту!",
                    "🎵 Без задач, только вайб",
                    "🐱 Даже кот впечатлён",
                    "🌴 Рай найден: 0 задач",
                    "🏆 Чемпион продуктивности!",
                    "☕ Только кофе и спокойствие"
                )
                "el" -> listOf(
                    "🦥 Ακόμα και οι βραδύποδες σε ζηλεύουν",
                    "🏖️ Λειτουργία παραλίας: ενεργή",
                    "🎮 Μηδέν εργασίες. Παιχνίδι;",
                    "🧘 Εσωτερική γαλήνη: επιτεύχθηκε",
                    "🦸 Όλες οι εργασίες — νικήθηκαν!",
                    "🍕 Καμία εργασία = ώρα για πίτσα!",
                    "🚀 Όλα καθαρά. Έτοιμοι για απογείωση!",
                    "🎵 Χωρίς εργασίες, μόνο χαλάρωση",
                    "🐱 Ακόμα και η γάτα εντυπωσιάστηκε",
                    "🌴 Παράδεισος: 0 εργασίες",
                    "🏆 Πρωταθλητής παραγωγικότητας!",
                    "☕ Μόνο καφές και ηρεμία"
                )
                "tr" -> listOf(
                    "🦥 Tembel hayvanlar bile kıskanıyor",
                    "🏖️ Plaj modu: aktif",
                    "🎮 Sıfır görev. Oyun zamanı?",
                    "🧘 İç huzur: sağlandı",
                    "🦸 Tüm görevler — yenildi!",
                    "🍕 Görev yok = pizza zamanı!",
                    "🚀 Her şey temiz. Kalkışa hazır!",
                    "🎵 Görev yok, sadece keyif",
                    "🐱 Kedin bile etkilendi",
                    "🌴 Cennet bulundu: 0 görev",
                    "🏆 Verimlilik şampiyonu!",
                    "☕ Sadece kahve ve huzur"
                )
                else -> listOf(
                    "🦥 Even sloths envy your free time",
                    "🏖️ Beach mode: activated",
                    "🎮 Zero tasks. Game time?",
                    "🧘 Inner peace: achieved",
                    "🦸 All tasks — defeated!",
                    "🍕 No tasks = pizza time!",
                    "🚀 All clear. Ready for takeoff!",
                    "🎵 No tasks, just vibes",
                    "🐱 Even your cat is impressed",
                    "🌴 Paradise found: 0 tasks",
                    "🏆 Productivity champion!",
                    "☕ Just coffee and calm"
                )
            }
            return messages[index]
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
                val rows = listOf(
                    Triple(R.id.task_row_1, R.id.task_title_1, R.id.task_checkbox_1),
                    Triple(R.id.task_row_2, R.id.task_title_2, R.id.task_checkbox_2),
                    Triple(R.id.task_row_3, R.id.task_title_3, R.id.task_checkbox_3),
                    Triple(R.id.task_row_4, R.id.task_title_4, R.id.task_checkbox_4),
                    Triple(R.id.task_row_5, R.id.task_title_5, R.id.task_checkbox_5))
                if (tasks.isEmpty()) {
                    views.setTextViewText(R.id.widget_title, "Taskify")
                    views.setViewVisibility(R.id.empty_container, View.VISIBLE)
                    views.setTextViewText(R.id.empty_text, getEmptyMessage(context))
                    rows.forEach { views.setViewVisibility(it.first, View.GONE) }
                } else {
                    views.setTextViewText(R.id.widget_title, getTaskCountText(tasks.size, context))
                    views.setViewVisibility(R.id.empty_container, View.GONE)
                    for (i in 0 until 5) {
                        val (rowId, titleId, checkboxId) = rows[i]
                        if (i < tasks.size) {
                            val task = tasks[i]
                            val key = task.optInt("key", -1)
                            views.setViewVisibility(rowId, View.VISIBLE)
                            views.setTextViewText(titleId, task.optString("title", ""))
                            val intent = Intent(context, TaskWidgetLargeProvider::class.java).apply {
                                action = ACTION_COMPLETE_TASK
                                putExtra(EXTRA_TASK_KEY, key)
                                data = Uri.parse("taskify://complete_large/$key")
                            }
                            views.setOnClickPendingIntent(checkboxId, PendingIntent.getBroadcast(context, key + 1000, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE))
                        } else { views.setViewVisibility(rowId, View.GONE) }
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
