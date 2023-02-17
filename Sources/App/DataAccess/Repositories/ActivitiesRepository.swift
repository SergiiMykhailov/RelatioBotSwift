public protocol ActivitiesRepository {

    func registerActivity(_ activity: Activity) async -> Bool
    func loadActivities(
        ofUserWithId userId: String,
        fromTimestamp: Int,
        toTimestamp: Int
    ) async -> [Activity]

}
