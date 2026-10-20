import SwiftUI

struct MonthAgendaCard: View {
    let snapshot: AgendaSnapshot

    private var calendar: Calendar { .current }

    var body: some View {
        GeometryReader { geometry in
            let days = monthCells
            let monthWidth = geometry.size.width * 0.46
            HStack(alignment: .top, spacing: 0) {
                monthPanel(days: days, availableSize: CGSize(width: monthWidth, height: geometry.size.height))
                    .frame(width: monthWidth, alignment: .topLeading)

                Rectangle()
                    .fill(.white.opacity(0.11))
                    .frame(width: 1, height: geometry.size.height)

                agendaPanel
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.17, green: 0.17, blue: 0.18))
    }

    private func monthPanel(days: [Date?], availableSize: CGSize) -> some View {
        let rows = max(1, days.count / 7)
        let compact = availableSize.height < 130
        let gap: CGFloat = compact ? 1 : 2
        let headerHeight: CGFloat = compact ? 14 : 16
        let weekdayHeight: CGFloat = compact ? 10 : 12
        let rowHeight = min(16, max(9, (availableSize.height - headerHeight - weekdayHeight - gap * CGFloat(rows + 1)) / CGFloat(rows)))
        let cellSide = min(rowHeight, max(9, (availableSize.width - 6) / 7))

        return VStack(spacing: gap) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(calendar.component(.month, from: snapshot.date))月")
                    .foregroundStyle(Color(red: 1, green: 0.28, blue: 0.25))
                    .font(.system(size: 13, weight: .bold))
                Text(lunarDay)
                    .foregroundStyle(.white.opacity(0.65))
                    .font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 0)
            }
            .frame(height: headerHeight)

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white.opacity(index == 0 || index == 6 ? 0.45 : 0.78))
                }
            }
            .font(.system(size: 9, weight: .semibold))
            .frame(height: weekdayHeight)

            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        dayCell(days[row * 7 + column], side: cellSide)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: rowHeight)
            }
        }
        .padding(.trailing, 6)
    }

    private func dayCell(_ day: Date?, side: CGFloat) -> some View {
        Group {
            if let day {
                let isToday = calendar.isDate(day, inSameDayAs: snapshot.date)
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: min(10, max(8, side - 5)), weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? .white : .white.opacity(0.82))
                    .frame(width: side, height: side)
                    .background(isToday ? Color(red: 1, green: 0.27, blue: 0.23) : .clear, in: Circle())
            } else {
                Color.clear.frame(width: side, height: side)
            }
        }
    }

    private var agendaPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !snapshot.hasCalendarAccess && !snapshot.hasReminderAccess {
                Text("打开「月历日程」允许读取日历和提醒事项")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            } else if eventDays.isEmpty {
                Text(snapshot.hasReminderAccess ? "近期无日程" : "提醒事项未授权，待办可能缺失")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.60))
                    .padding(.top, 24)
            } else {
                ForEach(eventDays, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dayHeading(group.day))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                        ForEach(group.events.prefix(2)) { event in
                            HStack(spacing: 4) {
                                if event.kind == .reminder {
                                    Circle()
                                        .stroke(Color(cgColor: event.tint), lineWidth: 1.5)
                                        .frame(width: 8, height: 8)
                                } else {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 7))
                                        .foregroundStyle(Color(cgColor: event.tint))
                                        .frame(width: 8, height: 8)
                                }
                                Text(event.title)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if !event.isAllDay {
                                    Text(timeLabel(event.start))
                                        .foregroundStyle(.white.opacity(0.48))
                                }
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 4)
                            .frame(height: 17)
                            .background(Color(cgColor: event.tint).opacity(0.13), in: Capsule())
                        }
                    }
                }
                if !snapshot.hasReminderAccess {
                    Text("提醒事项未授权，待办可能缺失")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
    }

    private var eventDays: [(day: Date, events: [AgendaItem])] {
        let grouped = Dictionary(grouping: snapshot.events) { calendar.startOfDay(for: $0.start) }
        return grouped.keys.sorted().prefix(2).map { ($0, grouped[$0] ?? []) }
    }

    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: snapshot.date) else {
            return Array(repeating: nil, count: 35)
        }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: snapshot.date)?.count ?? 31
        let cellCount = ((leading + count + 6) / 7) * 7
        return (0..<cellCount).map { index in
            let day = index - leading
            return (0..<count).contains(day) ? calendar.date(byAdding: .day, value: day, to: interval.start) : nil
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    private var lunarDay: String {
        let lunarCalendar = Calendar(identifier: .chinese)
        let formatter = DateFormatter()
        formatter.calendar = lunarCalendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MMMM"
        let dayNames = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十", "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十", "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
        let day = lunarCalendar.component(.day, from: snapshot.date)
        return formatter.string(from: snapshot.date) + (dayNames.indices.contains(day - 1) ? dayNames[day - 1] : "")
    }

    private func dayHeading(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: day)
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
