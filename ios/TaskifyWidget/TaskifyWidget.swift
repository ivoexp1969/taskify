import WidgetKit
import SwiftUI

struct TaskItem: Codable, Identifiable {
    let id = UUID()
    let key: Int
    let title: String
    let priority: Int
    let isCompleted: Bool
    let dueDate: String?
    let template: String?
    enum CodingKeys: String, CodingKey { case key, title, priority, isCompleted, dueDate, template }

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
        TaskEntry(date: Date(), tasks: [], language: "en")
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

        let todayTasks = all.filter { task in
            guard !task.isCompleted, let ds = task.dueDate,
                  let d = parseDate(ds) else { return false }
            return d >= today && d < tomorrow
        }.prefix(3)

        return TaskEntry(date: Date(), tasks: Array(todayTasks), language: lang)
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

struct TaskRowView: View {
    let task: TaskItem
    let lang: String
    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
                    .frame(width: 14, height: 14)
            }
            if task.priority > 0 {
                Text("●")
                    .font(.system(size: 8))
                    .foregroundColor(dotColor(task.priority))
            }
            Text(task.displayTitle(lang: lang))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.07))
        .cornerRadius(5)
    }
}

struct TaskifyWidgetEntryView: View {
    var entry: TaskEntry
    @Environment(\.widgetFamily) var family

    var emptyMsg: String {
        let h = Calendar.current.component(.hour, from: Date())
        let msgs: [String]
        switch entry.language {
        case "bg": msgs = ["🦥 Дори мързелът ти завижда","🏖️ Плажен режим: активиран","🎮 Нула задачи. Игри?","🧘 Вътрешен мир: постигнат","🦸 Всички задачи победени!","☕ Само кафе и спокойствие"]
        case "de": msgs = ["🦥 Selbst Faultiere beneiden dich","🏖️ Strandmodus: aktiviert","🎮 Null Aufgaben. Spielzeit?","🧘 Innerer Frieden: erreicht","🦸 Alle Aufgaben besiegt!","☕ Nur Kaffee und Gelassenheit"]
        case "ru": msgs = ["🦥 Даже ленивцы тебе завидуют","🏖️ Режим пляжа: активирован","🎮 Ноль задач. Поиграем?","🧘 Внутренний покой: достигнут","🦸 Все задачи повержены!","☕ Только кофе и спокойствие"]
        default:   msgs = ["🦥 Even sloths envy you","🏖️ Beach mode: activated","🎮 Zero tasks. Game time?","🧘 Inner peace: achieved","🦸 All tasks defeated!","☕ Just coffee and calm"]
        }
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
                Text("Taskify")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.bottom, 6)

            if entry.tasks.isEmpty {
                Spacer()
                Text(emptyMsg)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(spacing: 3) {
                    ForEach(entry.tasks) { task in
                        TaskRowView(task: task, lang: entry.language)
                    }
                }
                Spacer()
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
