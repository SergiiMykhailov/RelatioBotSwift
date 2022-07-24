import SQLite

class SQLiteActivitiesRepository {

    // MARK: - Public methods and properties

    init(withConnection connection: Connection) {
        self.connection = connection
    }

    // MARK: - Internal methods

    private func setupTableIfNeeded() -> Table {
        if table == nil {
            table = Table(Constants.tableName)

            do {
                try connection.run(table!.create(
                    ifNotExists: true
                ) { builder in
                        builder.column(userIdColumn)
                        builder.column(activityTypeColumn)
                        builder.column(activityDataColumn)
                        builder.column(timestampColumn)
                    }
                )
            }
            catch { }
        }

        return table!
    }

    // MARK: - Internal fields

    private let connection: Connection

    private var table: Table?
    private let userIdColumn = Expression<String>(Constants.userIdColumnName)
    private let activityTypeColumn = Expression<Int>(Constants.activityTypeColumnName)
    private let activityDataColumn = Expression<String>(Constants.activityDataColumnName)
    private let timestampColumn = Expression<Int>(Constants.timestampColumnName)

    private enum Constants {
        static let tableName = "activities"

        static let userIdColumnName = "userId"
        static let activityTypeColumnName = "activityType"
        static let activityDataColumnName = "data"
        static let timestampColumnName = "timestamp"
    }

}

extension SQLiteActivitiesRepository : ActivitiesRepository {

    func registerActivity(_ activity: Activity) async -> Bool {
        let table = setupTableIfNeeded()

        do {
            try connection.run(
                table.insert(
                    userIdColumn <- activity.userId,
                    activityTypeColumn <- activity.type.rawValue,
                    activityDataColumn <- activity.data,
                    timestampColumn <- activity.timestamp
                )
            )

            return true
        }
        catch {
            return false
        }
    }

    func loadActivities(
        ofUserWithId userId: String,
        fromTimestamp: Int,
        toTimestamp: Int
    ) async -> [Activity] {
        let table = setupTableIfNeeded()

        let query = table.filter(
            userIdColumn == userId &&
            timestampColumn >= fromTimestamp &&
            timestampColumn <= toTimestamp
        )

        var result = [Activity]()

        if let records = try? connection.prepare(query) {
            for record in records {
                let userId = record[userIdColumn]
                let activityTypeData = record[activityTypeColumn]
                let activityData = record[activityDataColumn]
                let timestamp = record[timestampColumn]

                result.append(
                    Activity(
                        withUserId: userId,
                        type: ActivityType(rawValue: activityTypeData) ?? .unknown,
                        data: activityData,
                        timestamp: timestamp
                    )
                )
            }
        }

        return result
    }

}
