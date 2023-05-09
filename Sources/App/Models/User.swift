public enum Gender {
    case male
    case female
}

public final class User {

    // MARK: - Public methods and properties

    public let id: String
    public let gender: Gender
    public let registeredAtTimestamp: Int

    init(
        withId id: String,
        gender: Gender,
        registeredAtTimestamp: Int
    ) {
        self.id = id
        self.gender = gender
        self.registeredAtTimestamp = registeredAtTimestamp
    }

}
