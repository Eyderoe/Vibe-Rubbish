import EventKit
import SwiftUI
import WidgetKit

@main
struct MonthAgendaApp: App {
    var body: some Scene {
        WindowGroup("月历日程") {
            SetupView()
                .frame(width: 400, height: 330)
        }
        .windowResizability(.contentSize)
    }
}

private struct SetupView: View {
    @State private var snapshot = AgendaSnapshot(date: .now, hasCalendarAccess: false, hasReminderAccess: false, events: [])
    @State private var errorMessage: String?
    private let eventStore = EKEventStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("月历日程")
                .font(.system(size: 23, weight: .bold))

            MonthAgendaCard(snapshot: snapshot)
                .frame(width: 339, height: 163)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 8) {
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button(buttonTitle) {
                        refreshCalendar()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .onAppear(perform: reloadSnapshot)
    }

    private func refreshCalendar() {
        if !snapshot.hasCalendarAccess {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    errorMessage = granted ? nil : (error?.localizedDescription ?? "日历权限未开启。可在系统设置 → 隐私与安全性 → 日历中允许访问。")
                    reloadSnapshot()
                }
            }
            return
        }

        if !snapshot.hasReminderAccess {
            eventStore.requestFullAccessToReminders { granted, error in
                DispatchQueue.main.async {
                    errorMessage = granted ? nil : (error?.localizedDescription ?? "提醒事项权限未开启。可在系统设置 → 隐私与安全性 → 提醒事项中允许访问。")
                    reloadSnapshot()
                }
            }
            return
        }

        reloadSnapshot()
    }

    private func reloadSnapshot() {
        AgendaData.load { freshSnapshot in
            DispatchQueue.main.async {
                snapshot = freshSnapshot
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private var statusText: String {
        if !snapshot.hasCalendarAccess { return "允许读取日历后，组件会显示真实的近期日程。" }
        if !snapshot.hasReminderAccess { return "日历已连接；允许读取提醒事项后可显示已安排日期的待办。" }
        return "已连接。添加桌面小组件后可关闭本应用，组件会自动更新。"
    }

    private var buttonTitle: String {
        if !snapshot.hasCalendarAccess { return "允许读取日历" }
        if !snapshot.hasReminderAccess { return "允许读取提醒事项" }
        return "刷新日程"
    }
}
