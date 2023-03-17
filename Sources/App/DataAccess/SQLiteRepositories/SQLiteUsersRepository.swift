import SQLite

public class SQLiteUsersRepository {

    // MARK: - Public methods and properties

    public init(withConnection connection: Connection) {
        self.connection = connection
    }

    // MARK: - Internal methods

    private func setupTableIfNeeded() -> Table {
        if table == nil {
            table = Table(Constants.tableName)

            // If database structure changes only columns adding/removing
            // is allowed in order to keep existing data

            do {
                try connection.run(table!.create(
                    ifNotExists: true,
                    withoutRowid: true) { builder in
                        builder.column(idColumn, primaryKey: true)
                        builder.column(registeredAtColumn)
                    }
                )
            }
            catch { }

            do {
                try connection.run(
                    table!.addColumn(genderColumn, defaultValue: Constants.maleColumnData)
                )
            }
            catch {
                print(error)
            }
        }

        return table!
    }

    // MARK: - Internal fields

    private let connection: Connection

    private var table: Table?
    private let idColumn = Expression<String>(Constants.idColumnName)
    private let genderColumn = Expression<Int>(Constants.gender)
    private let registeredAtColumn = Expression<Int>(Constants.registeredAtColumnName)

    private enum Constants {
        static let tableName = "users"

        static let idColumnName = "id"
        static let gender = "gender"
        static let registeredAtColumnName = "registeredAt"

        public static let maleColumnData = 0
        public static let femaleColumnData = 1
    }
}

extension SQLiteUsersRepository : UsersRepository {

    public func registerUser(_ user: User) async -> Bool {
        let table = setupTableIfNeeded()

        do {
            let genderData = user.gender == .female
                ? Constants.femaleColumnData
                : Constants.maleColumnData

            try connection.run(
                table.insert(
                    or: .rollback,
                    idColumn <- user.id,
                    registeredAtColumn <- user.registeredAtTimestamp,
                    genderColumn <- genderData
                )
            )

            return true
        }
        catch {
            print(error)
            return false
        }
    }

    public func loadUsers() async -> [User] {
        let table = setupTableIfNeeded()

        var result = [User]()

        do {
            let query = try connection.prepare(table)
            for entry in query {
                let id = entry[idColumn]
                let genderData = entry[genderColumn]
                let registeredAt = entry[registeredAtColumn]

                let gender = genderData == Constants.femaleColumnData ? Gender.female : Gender.male

                result.append(User(
                    withId: id,
                    gender: gender,
                    registeredAtTimestamp: registeredAt)
                )
            }
        }
        catch { }

        return result
    }

}
