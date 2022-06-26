class User {

    // MARK: - Public methods and properties

    public let id: String
    public let registeredAtTimestamp: Int

    init(withId id: String, registeredAtTimestamp: Int) {
        self.id = id
        self.registeredAtTimestamp = registeredAtTimestamp
    }

}
