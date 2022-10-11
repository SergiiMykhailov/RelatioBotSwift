import Foundation

extension Date {
    static func today() -> Date {
        return Date()
    }

    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }

    var startOfWeek: Date {
        let result = previous(.monday, considerToday: true)
        return result
    }

    var endOfWeek: Date {
        let result = next(.sunday, considerToday: true)
        return result
    }

    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: startOfDay)
        return Calendar.current.date(from: components)!
    }

    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
    }

    var isLastDayOfMonth: Bool {
        let endOfMonthDayComponents = Calendar.current.dateComponents([.day], from: endOfMonth)
        let currentDayComponents = Calendar.current.dateComponents([.day], from: self)

        let result = endOfMonthDayComponents.day == currentDayComponents.day
        return result
    }

    func next(_ weekday: Weekday, considerToday: Bool = false) -> Date {
        return get(.next,
                   weekday,
                   considerToday: considerToday)
    }

    func previous(_ weekday: Weekday, considerToday: Bool = false) -> Date {
        return get(.previous,
                   weekday,
                   considerToday: considerToday)
    }

    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }

    func dayByOffsetting(numberOfDays: Int) -> Date {
        return Calendar.current.date(
            byAdding: .day,
            value: numberOfDays,
            to: noon
        )!
    }

    func dayByOffsetting(numberOfMonths: Int) -> Date {
        return Calendar.current.date(
            byAdding: .month,
            value: numberOfMonths,
            to: noon
        )!
    }

    func get(
        _ direction: SearchDirection,
        _ weekDay: Weekday,
        considerToday consider: Bool = false
    ) -> Date {
        let dayName = weekDay.rawValue
        let weekdaysName = getWeekDaysInEnglish().map { $0.lowercased() }
        assert(weekdaysName.contains(dayName), "weekday symbol should be in form \(weekdaysName)")
        let searchWeekdayIndex = weekdaysName.firstIndex(of: dayName)! + 1
        let calendar = Calendar(identifier: .gregorian)
        if consider && calendar.component(.weekday, from: self) == searchWeekdayIndex {
            return self
        }
        var nextDateComponent = calendar.dateComponents([.hour, .minute, .second], from: self)
        nextDateComponent.weekday = searchWeekdayIndex
        let date = calendar.nextDate(after: self,
                                     matching: nextDateComponent,
                                     matchingPolicy: .nextTime,
                                     direction: direction.calendarSearchDirection)
        return date!
    }
}

// MARK: - Helper methods
extension Date {
    func getWeekDaysInEnglish() -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar.weekdaySymbols
    }

    var dayOfWeek: Weekday? {
        let calendar = Calendar.current
        let weekDay = calendar.component(Calendar.Component.weekday, from: self)
        let result = Date.dayOfWeek(fromDayIndex: weekDay)

        return result
    }

    static func dayOfWeek(fromDayIndex dayIndex: Int) -> Weekday? {
        switch (dayIndex) {
            case 1: return .sunday
            case 2: return .monday
            case 3: return .tuesday
            case 4: return .wednesday
            case 5: return .thursday
            case 6: return .friday
            case 7: return .saturday
            default: return nil
        }
    }

    enum Weekday: String {
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    }

    enum SearchDirection {
        case next
        case previous
        var calendarSearchDirection: Calendar.SearchDirection {
            switch self {
                case .next:
                    return .forward
                case .previous:
                    return .backward
            }
        }
    }
}
