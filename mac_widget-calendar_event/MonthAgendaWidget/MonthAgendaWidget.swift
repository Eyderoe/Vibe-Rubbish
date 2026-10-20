import SwiftUI
import WidgetKit

struct MonthAgendaEntry: TimelineEntry {
    let date: Date
    let snapshot: AgendaSnapshot
}

struct MonthAgendaProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthAgendaEntry {
        let snapshot = AgendaSnapshot.preview()
        return MonthAgendaEntry(date: snapshot.date, snapshot: snapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthAgendaEntry) -> Void) {
        if context.isPreview {
            let snapshot = AgendaSnapshot.preview()
            completion(MonthAgendaEntry(date: snapshot.date, snapshot: snapshot))
        } else {
            AgendaData.load { snapshot in
                completion(MonthAgendaEntry(date: snapshot.date, snapshot: snapshot))
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthAgendaEntry>) -> Void) {
        let now = Date()
        AgendaData.load(at: now) { snapshot in
            let entry = MonthAgendaEntry(date: now, snapshot: snapshot)
            let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(nextHour)))
        }
    }
}

@main
struct MonthAgendaWidget: Widget {
    let kind = "MonthAgendaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthAgendaProvider()) { entry in
            MonthAgendaCard(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    Color(red: 0.17, green: 0.17, blue: 0.18)
                }
                .widgetURL(URL(string: "monthagenda://open"))
        }
        .configurationDisplayName("月历日程")
        .description("左侧月历，右侧近期日程。")
        .supportedFamilies([.systemMedium])
    }
}
