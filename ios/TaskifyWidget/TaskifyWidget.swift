import WidgetKit
import SwiftUI
import AppIntents

/// Парсва датата, която Flutter записва (ISO/локална без часова зона).
func parseTaskDate(_ ds: String?) -> Date? {
    guard let ds = ds else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = iso.date(from: ds) { return d }
    iso.formatOptions = [.withInternetDateTime]
    if let d = iso.date(from: ds) { return d }
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return df.date(from: String(ds.prefix(19)))
}

struct TaskItem: Codable, Identifiable {
    let id = UUID()
    let key: Int
    let title: String
    let priority: Int
    let isCompleted: Bool
    let dueDate: String?
    let template: String?
    enum CodingKeys: String, CodingKey { case key, title, priority, isCompleted, dueDate, template }

    /// Просрочена = денят на падежа е преди днешния (като Android). Маркира се червено.
    var isOverdue: Bool {
        guard let d = parseTaskDate(dueDate) else { return false }
        return d < Calendar.current.startOfDay(for: Date())
    }

    func displayTitle(lang: String) -> String {
        switch template {
        case "meeting":
            switch lang {
            case "bg": return "Среща с \(title)"
            case "de": return "Treffen mit \(title)"
            case "fr": return "Réunion avec \(title)"
            case "it": return "Incontro con \(title)"
            case "el": return "Συνάντηση με \(title)"
            case "es": return "Reunión con \(title)"
            case "pt": return "Reunião com \(title)"
            case "ru": return "Встреча с \(title)"
            case "tr": return "\(title) ile toplantı"
            default:   return "Meeting with \(title)"
            }
        case "travel":
            switch lang {
            case "bg": return "Пътуване до \(title)"
            case "de": return "Reise nach \(title)"
            case "fr": return "Voyage à \(title)"
            case "it": return "Viaggio a \(title)"
            case "el": return "Ταξίδι στο \(title)"
            case "es": return "Viaje a \(title)"
            case "pt": return "Viagem a \(title)"
            case "ru": return "Поездка в \(title)"
            case "tr": return "\(title)'a seyahat"
            default:   return "Trip to \(title)"
            }
        case "gift":
            switch lang {
            case "bg": return "Подарък за \(title)"
            case "de": return "Geschenk für \(title)"
            case "fr": return "Cadeau pour \(title)"
            case "it": return "Regalo per \(title)"
            case "el": return "Δώρο για \(title)"
            case "es": return "Regalo para \(title)"
            case "pt": return "Presente para \(title)"
            case "ru": return "Подарок для \(title)"
            case "tr": return "\(title) için hediye"
            default:   return "Gift for \(title)"
            }
        case "birthday":
            switch lang {
            case "bg": return "Рожден ден на \(title)"
            case "de": return "Geburtstag von \(title)"
            case "fr": return "Anniversaire de \(title)"
            case "it": return "Compleanno di \(title)"
            case "el": return "Γενέθλια του \(title)"
            case "es": return "Cumpleaños de \(title)"
            case "pt": return "Aniversário de \(title)"
            case "ru": return "День рождения \(title)"
            case "tr": return "\(title) doğum günü"
            default:   return "\(title)'s birthday"
            }
        default:
            return title
        }
    }
}

struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskItem]
    let language: String
    /// Локален контекст (готов ред): документ/имен ден/празник — като Android.
    let context: String?
    /// Име на потребителя (ако е въведено) → по-лично приветствие в заглавието.
    let userName: String?
}

let kWidgetBg = Color(red: 0.216, green: 0.188, blue: 0.639)

struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(kWidgetBg, for: .widget)
        } else {
            content.background(kWidgetBg)
        }
    }
}

struct TaskifyProvider: TimelineProvider {
    let appGroup = "group.com.ivoexp.taskify"

    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), tasks: [], language: "en", context: nil, userName: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func parseDate(_ ds: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: ds) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: ds) { return d }
        // Flutter stores local time without timezone — truncate to seconds
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.date(from: String(ds.prefix(19)))
    }

    private func loadEntry() -> TaskEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        let json = defaults?.string(forKey: "flutter.widget_tasks") ?? "[]"
        let lang = defaults?.string(forKey: "flutter.app_language") ?? "en"
        let data = json.data(using: .utf8) ?? Data()
        let all = (try? JSONDecoder().decode([TaskItem].self, from: data)) ?? []

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        // Като Android: днешни + ПРОСРОЧЕНИ (всичко до утре). Dart вече ги е
        // сортирал просрочените първи; prefix(3) запазва реда.
        let todayTasks = all.filter { task in
            guard !task.isCompleted, let ds = task.dueDate,
                  let d = parseDate(ds) else { return false }
            return d < tomorrow
        }.prefix(3)

        // Локален контекст — приоритет като Android: документ > имен ден > празник.
        var ctxLine: String? = nil
        if let cj = defaults?.string(forKey: "flutter.widget_context"),
           let cdata = cj.data(using: .utf8),
           let map = (try? JSONSerialization.jsonObject(with: cdata)) as? [String: String] {
            ctxLine = map["docExpiry"] ?? map["nameDay"] ?? map["holiday"]
        }

        let name = defaults?.string(forKey: "flutter.widget_user_name")
        let userName = (name?.isEmpty ?? true) ? nil : name

        return TaskEntry(date: Date(), tasks: Array(todayTasks),
                         language: lang, context: ctxLine, userName: userName)
    }
}

func dotColor(_ priority: Int) -> Color {
    switch priority {
    case 3: return Color(red: 0.94, green: 0.33, blue: 0.31)
    case 2: return Color(red: 1.0, green: 0.72, blue: 0.30)
    case 1: return Color(red: 0.39, green: 0.71, blue: 0.96)
    default: return .clear
    }
}

let kOverdueColor = Color(red: 0.94, green: 0.33, blue: 0.31)

/// AppIntent за отмятане на задача от widget-а (iOS 16+; интерактивен бутон iOS 17+).
/// Записва ключа в App Group (`flutter.widget_completed`) → приложението го прибира
/// в Hive при следващ фокус (WidgetService.syncFromWidget). Маха задачата веднага
/// от `flutter.widget_tasks`, за да изчезне от widget-а без да чака app-а.
@available(iOS 16.0, *)
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete task"
    @Parameter(title: "Task key") var key: Int
    init() {}
    init(key: Int) { self.key = key }

    func perform() async throws -> some IntentResult {
        let d = UserDefaults(suiteName: "group.com.ivoexp.taskify")
        var completed = d?.array(forKey: "flutter.widget_completed") as? [Int] ?? []
        if !completed.contains(key) { completed.append(key) }
        d?.set(completed, forKey: "flutter.widget_completed")
        // Махни от списъка веднага (маркирай isCompleted) → изчезва от widget-а.
        if let json = d?.string(forKey: "flutter.widget_tasks"),
           let data = json.data(using: .utf8),
           var arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
            arr = arr.map { item in
                var it = item
                if (it["key"] as? Int) == key { it["isCompleted"] = true }
                return it
            }
            if let out = try? JSONSerialization.data(withJSONObject: arr),
               let s = String(data: out, encoding: .utf8) {
                d?.set(s, forKey: "flutter.widget_tasks")
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct TaskRowView: View {
    let task: TaskItem
    let lang: String

    @ViewBuilder private var checkbox: some View {
        let box = RoundedRectangle(cornerRadius: 3)
            .stroke((task.isOverdue ? kOverdueColor : Color.white).opacity(0.6), lineWidth: 1.4)
            .frame(width: 16, height: 16)
        if #available(iOS 17.0, *) {
            Button(intent: CompleteTaskIntent(key: task.key)) { box }
                .buttonStyle(.plain)
        } else {
            box  // iOS <17: не-интерактивно; тап върху widget-а отваря приложението
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            checkbox
            if task.priority > 0 {
                Text("●")
                    .font(.system(size: 8))
                    .foregroundColor(dotColor(task.priority))
            }
            Text(task.displayTitle(lang: lang))
                .font(.system(size: 14, weight: task.isOverdue ? .semibold : .regular, design: .rounded))
                .foregroundColor(task.isOverdue ? kOverdueColor : .white)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background((task.isOverdue ? kOverdueColor.opacity(0.14) : Color.white.opacity(0.07)))
        .cornerRadius(5)
    }
}

// Playful empty-state phrases — mirror of Android WidgetPhrases.kt (10 langs × 18).
// `ja` is intentionally absent → falls back to "en".
enum WidgetPhrases {
    static let byLang: [String: [String]] = [
        "bg": [
            "🦥 Дори мързелът ти завижда", "🏖️ Плажен режим: активиран",
            "🎮 Нула задачи. Време за игри?", "🧘 Вътрешен мир: постигнат",
            "🦸 Всички задачи — победени!", "🍕 Няма задачи = време за пица!",
            "🚀 Всичко чисто. Готов за излитане!", "🎵 Без задачи, само вайб",
            "🐱 Дори котката ти е впечатлена", "🌴 Рай на земята: 0 задачи",
            "🏆 Шампион по продуктивност!", "☕ Само кафе и спокойствие",
            "🌟 Всичко е под контрол!", "😎 Нищо за вършене. Релакс.",
            "🍦 Свободно време: отключено!", "📚 Може би една книга?",
            "🌈 Чисто небе пред теб", "💆 Почивай, заслужи си го",
        ],
        "en": [
            "🦥 Even sloths envy your free time", "🏖️ Beach mode: activated",
            "🎮 Zero tasks. Game time?", "🧘 Inner peace: achieved",
            "🦸 All tasks — defeated!", "🍕 No tasks = pizza time!",
            "🚀 All clear. Ready for takeoff!", "🎵 No tasks, just vibes",
            "🐱 Even your cat is impressed", "🌴 Paradise found: 0 tasks",
            "🏆 Productivity champion!", "☕ Just coffee and calm",
            "🌟 You're all caught up!", "😎 Nothing to do. Stay cool.",
            "🍦 Free time unlocked!", "📚 Maybe read a book?",
            "🌈 Clear skies ahead", "💆 Relax, you earned it",
        ],
        "de": [
            "🦥 Selbst Faultiere beneiden dich", "🏖️ Strandmodus: aktiviert",
            "🎮 Null Aufgaben. Spielzeit?", "🧘 Innerer Frieden: erreicht",
            "🦸 Alle Aufgaben — besiegt!", "🍕 Keine Aufgaben = Pizzazeit!",
            "🚀 Alles klar. Bereit zum Abheben!", "🎵 Keine Aufgaben, nur gute Laune",
            "🐱 Selbst deine Katze staunt", "🌴 Paradies gefunden: 0 Aufgaben",
            "🏆 Produktivitäts-Champion!", "☕ Nur Kaffee und Gelassenheit",
            "🌟 Alles erledigt!", "😎 Nichts zu tun. Bleib cool.",
            "🍦 Freizeit freigeschaltet!", "📚 Vielleicht ein Buch?",
            "🌈 Klarer Himmel voraus", "💆 Entspann dich, du hast es verdient",
        ],
        "fr": [
            "🦥 Même les paresseux t'envient", "🏖️ Mode plage : activé",
            "🎮 Zéro tâche. On joue ?", "🧘 Paix intérieure : atteinte",
            "🦸 Toutes les tâches — vaincues !", "🍕 Pas de tâches = pizza !",
            "🚀 Tout est clair. Prêt au décollage !", "🎵 Pas de tâches, que du bon",
            "🐱 Même ton chat est impressionné", "🌴 Paradis trouvé : 0 tâches",
            "🏆 Champion de productivité !", "☕ Juste un café et du calme",
            "🌟 Tout est à jour !", "😎 Rien à faire. Reste cool.",
            "🍦 Temps libre débloqué !", "📚 Et si tu lisais un livre ?",
            "🌈 Ciel dégagé devant toi", "💆 Détends-toi, tu l'as mérité",
        ],
        "it": [
            "🦥 Anche i bradipi ti invidiano", "🏖️ Modalità spiaggia: attivata",
            "🎮 Zero compiti. Si gioca?", "🧘 Pace interiore: raggiunta",
            "🦸 Tutti i compiti — sconfitti!", "🍕 Niente compiti = pizza!",
            "🚀 Tutto libero. Pronti al decollo!", "🎵 Niente compiti, solo relax",
            "🐱 Anche il gatto è colpito", "🌴 Paradiso trovato: 0 compiti",
            "🏆 Campione di produttività!", "☕ Solo caffè e tranquillità",
            "🌟 Tutto in ordine!", "😎 Niente da fare. Stai sereno.",
            "🍦 Tempo libero sbloccato!", "📚 Magari un libro?",
            "🌈 Cielo sereno in vista", "💆 Rilassati, te lo sei meritato",
        ],
        "es": [
            "🦥 Hasta los perezosos te envidian", "🏖️ Modo playa: activado",
            "🎮 Cero tareas. ¿Jugamos?", "🧘 Paz interior: alcanzada",
            "🦸 ¡Todas las tareas — vencidas!", "🍕 Sin tareas = ¡hora de pizza!",
            "🚀 Todo listo. ¡Listos para despegar!", "🎵 Sin tareas, solo buena onda",
            "🐱 Hasta tu gato está impresionado", "🌴 Paraíso encontrado: 0 tareas",
            "🏆 ¡Campeón de productividad!", "☕ Solo café y tranquilidad",
            "🌟 ¡Todo al día!", "😎 Nada que hacer. Tranqui.",
            "🍦 ¡Tiempo libre desbloqueado!", "📚 ¿Quizás un libro?",
            "🌈 Cielo despejado por delante", "💆 Relájate, te lo mereces",
        ],
        "pt": [
            "🦥 Até as preguiças te invejam", "🏖️ Modo praia: ativado",
            "🎮 Zero tarefas. Hora de jogar?", "🧘 Paz interior: alcançada",
            "🦸 Todas as tarefas — vencidas!", "🍕 Sem tarefas = hora da pizza!",
            "🚀 Tudo limpo. Pronto pra decolar!", "🎵 Sem tarefas, só boa vibe",
            "🐱 Até o gato ficou impressionado", "🌴 Paraíso encontrado: 0 tarefas",
            "🏆 Campeão de produtividade!", "☕ Só café e tranquilidade",
            "🌟 Tudo em dia!", "😎 Nada a fazer. Fica tranquilo.",
            "🍦 Tempo livre desbloqueado!", "📚 Que tal um livro?",
            "🌈 Céu limpo à frente", "💆 Relaxa, mereceste",
        ],
        "ru": [
            "🦥 Даже ленивцы тебе завидуют", "🏖️ Режим пляжа: активирован",
            "🎮 Ноль задач. Поиграем?", "🧘 Внутренний покой: достигнут",
            "🦸 Все задачи — повержены!", "🍕 Нет задач = время пиццы!",
            "🚀 Всё чисто. Готов к взлёту!", "🎵 Без задач, только вайб",
            "🐱 Даже кот впечатлён", "🌴 Рай найден: 0 задач",
            "🏆 Чемпион продуктивности!", "☕ Только кофе и спокойствие",
            "🌟 Всё под контролем!", "😎 Делать нечего. Расслабься.",
            "🍦 Свободное время: открыто!", "📚 Может, книгу почитать?",
            "🌈 Ясное небо впереди", "💆 Отдыхай, ты заслужил",
        ],
        "el": [
            "🦥 Ακόμα και οι βραδύποδες σε ζηλεύουν", "🏖️ Λειτουργία παραλίας: ενεργή",
            "🎮 Μηδέν εργασίες. Παιχνίδι;", "🧘 Εσωτερική γαλήνη: επιτεύχθηκε",
            "🦸 Όλες οι εργασίες — νικήθηκαν!", "🍕 Καμία εργασία = ώρα για πίτσα!",
            "🚀 Όλα καθαρά. Έτοιμοι για απογείωση!", "🎵 Χωρίς εργασίες, μόνο χαλάρωση",
            "🐱 Ακόμα και η γάτα εντυπωσιάστηκε", "🌴 Παράδεισος: 0 εργασίες",
            "🏆 Πρωταθλητής παραγωγικότητας!", "☕ Μόνο καφές και ηρεμία",
            "🌟 Όλα τακτοποιημένα!", "😎 Τίποτα να κάνεις. Χαλάρωσε.",
            "🍦 Ελεύθερος χρόνος: ξεκλείδωτος!", "📚 Μήπως ένα βιβλίο;",
            "🌈 Καθαρός ουρανός μπροστά", "💆 Χαλάρωσε, το αξίζεις",
        ],
        "tr": [
            "🦥 Tembel hayvanlar bile kıskanıyor", "🏖️ Plaj modu: aktif",
            "🎮 Sıfır görev. Oyun zamanı?", "🧘 İç huzur: sağlandı",
            "🦸 Tüm görevler — yenildi!", "🍕 Görev yok = pizza zamanı!",
            "🚀 Her şey temiz. Kalkışa hazır!", "🎵 Görev yok, sadece keyif",
            "🐱 Kedin bile etkilendi", "🌴 Cennet bulundu: 0 görev",
            "🏆 Verimlilik şampiyonu!", "☕ Sadece kahve ve huzur",
            "🌟 Her şey güncel!", "😎 Yapacak bir şey yok. Sakin ol.",
            "🍦 Boş zaman açıldı!", "📚 Belki bir kitap?",
            "🌈 Önünde açık gökyüzü", "💆 Rahatla, hak ettin",
        ],
    ]
}

struct TaskifyWidgetEntryView: View {
    var entry: TaskEntry
    @Environment(\.widgetFamily) var family

    var emptyMsg: String {
        // Pick by hour-of-day (changes every hour, cycles through the full list).
        // Same phrase pool as Android (WidgetPhrases.kt); ja falls back to en.
        let h = Calendar.current.component(.hour, from: Date())
        let msgs = WidgetPhrases.byLang[entry.language] ?? WidgetPhrases.byLang["en"]!
        return msgs[h % msgs.count]
    }

    var countLabel: String {
        let n = entry.tasks.count
        switch entry.language {
        case "bg": return "\(n) задачи днес"
        case "de": return "\(n) Aufgaben heute"
        case "ru": return "\(n) задач сегодня"
        default:   return "\(n) tasks today"
        }
    }

    /// Заглавие на widget-а: лично приветствие, ако има въведено име; иначе „Taskify".
    var headerTitle: String {
        guard let n = entry.userName, !n.isEmpty else { return "Taskify" }
        switch entry.language {
        case "bg": return "Здравей, \(n)"
        case "de": return "Hallo, \(n)"
        case "ru": return "Привет, \(n)"
        case "fr": return "Salut, \(n)"
        case "it": return "Ciao, \(n)"
        case "es": return "Hola, \(n)"
        case "pt": return "Olá, \(n)"
        case "el": return "Γεια, \(n)"
        case "tr": return "Merhaba, \(n)"
        case "ja": return "\(n)さん"
        default:   return "Hi, \(n)"
        }
    }

    var body: some View {
        widgetContent
            .modifier(WidgetBackgroundModifier())
    }

    var widgetContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.square.fill")
                    .foregroundColor(Color(red: 0.20, green: 0.72, blue: 0.47))
                    .font(.system(size: 15))
                Text(headerTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            .padding(.bottom, 6)

            if entry.tasks.isEmpty {
                Spacer()
                if let ctx = entry.context {
                    // При празен списък контекстът заменя закачливата фраза
                    // (като Android) — четим шрифт, не ръкописният.
                    Text(ctx)
                        .font(.system(size: family == .systemSmall ? 13 : 15,
                                      weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(emptyMsg)
                        // Handwritten Caveat, like Android: as large as possible but
                        // auto-shrinks to the text length so it fits with no ellipsis.
                        .font(.custom("Caveat-Regular", size: family == .systemSmall ? 24 : 32))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.4)
                        .frame(maxWidth: .infinity)
                }
                Spacer()
            } else {
                VStack(spacing: 3) {
                    ForEach(entry.tasks) { task in
                        TaskRowView(task: task, lang: entry.language)
                    }
                }
                Spacer(minLength: 2)
                // Локален контекст под задачите (само medium — има място).
                if let ctx = entry.context, family != .systemSmall {
                    Text(ctx)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
        }
        .padding(10)
    }
}

@main
struct TaskifyWidget: Widget {
    let kind = "TaskifyWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskifyProvider()) { entry in
            TaskifyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Taskify")
        .description("Your tasks for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
