public enum ActivityType : Int {
    case unknown = 0
    case dailyMorningActivity = 1
    case dailyLunchActivity = 2
    case dailyEveningActivity = 3
    case weeklyActivity = 4
    case monthlyActivity = 5
    case heroActivity = 6

    static var allActivities: [ActivityType] = [
        .dailyMorningActivity,
        .dailyLunchActivity,
        .dailyEveningActivity,
        .weeklyActivity,
        .monthlyActivity
    ]
}

public final class Activity {

    // MARK: - Public methods and properties

    public let userId: String
    public let type: ActivityType
    public let data: String
    public let timestamp: Int

    init(
        withUserId userId: String,
        type: ActivityType,
        data: String,
        timestamp: Int
    ) {
        self.userId = userId
        self.type = type
        self.data = data
        self.timestamp = timestamp
    }

}
