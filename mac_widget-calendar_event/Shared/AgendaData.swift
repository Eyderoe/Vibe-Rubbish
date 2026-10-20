import EventKit
import Foundation

enum AgendaItemKind: Equatable {
    case event
    case reminder
}

struct AgendaItem: Identifiable {
    let id: String
    let title: String
    let start: Date
    let isAllDay: Bool
    let tint: CGColor
    let kind: AgendaItemKind
}

struct AgendaSnapshot {
    let date: Date
    let hasCalendarAccess: Bool
    let hasReminderAccess: Bool
    let events: [AgendaItem]

    static func preview(at date: Date = .now) -> AgendaSnapshot {
        let calendar = Calendar.current
        let twoDaysLater = calendar.date(byAdding: .day, value: 2, to: date) ?? date
        let threeDaysLater = calendar.date(byAdding: .day, value: 3, to: date) ?? date
        return AgendaSnapshot(date: date, hasCalendarAccess: true, hasReminderAccess: true, events: [
            AgendaItem(id: "preview-1", title: "整理本周待办", start: twoDaysLater, isAllDay: true, tint: CGColor(red: 1, green: 0.65, blue: 0.1, alpha: 1), kind: .reminder),
            AgendaItem(id: "preview-2", title: "霜降", start: threeDaysLater, isAllDay: true, tint: CGColor(red: 0.83, green: 0.38, blue: 0.9, alpha: 1), kind: .event)
        ])
    }
}

enum AgendaData {
    static func load(at date: Date = .now, completion: @escaping (AgendaSnapshot) -> Void) {
        let calendarAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        let reminderAccess = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        let store = EKEventStore()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? date.addingTimeInterval(14 * 86_400)

        var items: [AgendaItem] = []
        if calendarAccess {
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            items = store.events(matching: predicate)
                .filter { $0.endDate > date }
                .prefix(24)
                .map { event in
                    AgendaItem(
                        id: "event-\(event.eventIdentifier ?? UUID().uuidString)",
                        title: event.title.isEmpty ? "无标题日程" : event.title,
                        start: event.startDate,
                        isAllDay: event.isAllDay,
                        tint: event.calendar.cgColor,
                        kind: .event
                    )
                }
        }

        guard reminderAccess else {
            completion(AgendaSnapshot(date: date, hasCalendarAccess: calendarAccess, hasReminderAccess: false, events: items))
            return
        }

        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: start, ending: end, calendars: nil)
        store.fetchReminders(matching: predicate) { reminders in
            let reminderItems = (reminders ?? []).compactMap { reminder -> AgendaItem? in
                guard let due = reminder.dueDateComponents,
                      let dueDate = Self.reminderDate(due),
                      dueDate >= start,
                      dueDate < end else { return nil }
                return AgendaItem(
                    id: "reminder-\(reminder.calendarItemIdentifier)",
                    title: reminder.title.isEmpty ? "无标题提醒" : reminder.title,
                    start: dueDate,
                    isAllDay: due.hour == nil,
                    tint: reminder.calendar.cgColor,
                    kind: .reminder
                )
            }
            let allItems = (items + reminderItems).sorted {
                if $0.start != $1.start { return $0.start < $1.start }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            completion(AgendaSnapshot(date: date, hasCalendarAccess: calendarAccess, hasReminderAccess: true, events: allItems))
        }
    }

    private static func reminderDate(_ components: DateComponents) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = components.timeZone ?? .current
        return calendar.date(from: components)
    }
}
