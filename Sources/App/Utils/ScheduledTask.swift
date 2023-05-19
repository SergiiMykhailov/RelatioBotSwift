import Foundation

enum RepeatType {
    case daily
    case weekly
    case monthly
    case hourly

    var interval: TimeInterval {
        switch self {
        case .daily:
            return 24 * 60 * 60
        case .weekly:
            return 7 * 24 * 60 * 60
        case .monthly:
            return 30 * 24 * 60 * 60
        case .hourly:
            return 60 * 60
        }
    }
}

struct Schedule {
    let time: DateComponents
    let repeatType: RepeatType
}

class ScheduledTask {

    // MARK: - Public methods and properties

    init(schedule: Schedule, taskBlock: @escaping () -> Void) {
        self.schedule = schedule
        self.taskBlock = taskBlock
    }

    public func start() {
        let timer = DispatchSource.makeTimerSource()

        let startDate = calculateStartDate()
        let timeoutToStart = startDate.timeIntervalSinceNow
        let interval = schedule.repeatType.interval

        timer.schedule(
            deadline: .now() + timeoutToStart,
            repeating: interval,
            leeway: .seconds(60)
        )
        timer.setEventHandler { [weak self] in
            self?.executeTask()
        }

        timer.resume()

        self.timer = timer
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Internal methods

    private func calculateStartDate() -> Date {
        let calendar = Calendar.current
        guard let nextDate = calendar.nextDate(
            after: Date(),
            matching: schedule.time,
            matchingPolicy: .nextTime
        ) else {
            fatalError("Failed to calculate next date for schedule.")
        }

        return nextDate
    }

    private func executeTask() {
        taskBlock()
    }

    // MARK: - Internal fields

    private let schedule: Schedule
    private let taskBlock: () -> Void
    private var timer: DispatchSourceTimer?
}
