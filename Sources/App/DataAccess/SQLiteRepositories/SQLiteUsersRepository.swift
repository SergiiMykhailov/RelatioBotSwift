import SQLite

class SQLiteUsersRepository : UsersRepository {

    // MARK: - Public methods and properties

    init(withConnection connection: Connection) {
        self.connection = connection
    }

    // MARK: - Overridden methods

    func registerUser(_ user: User) async -> Bool {
        let table = setupTableIfNeeded()

        do {
            try connection.run(
                table.insert(or: .replace, idColumn <- user.id, registeredAtColumn <- user.registeredAtTimestamp)
            )

            return true
        }
        catch {
            return false
        }
    }

    func loadUsers() async -> [User] {
        let table = setupTableIfNeeded()

        var result = [User]()

        do {
            let query = try connection.prepare(table)
            for entry in query {
                let id = entry[idColumn]
                let registeredAt = entry[registeredAtColumn]

                result.append(User(
                    withId: id,
                    registeredAtTimestamp: registeredAt)
                )
            }
        }
        catch { }

        return result
    }

    // MARK: - Internal methods

    private func setupTableIfNeeded() -> Table {
        if table == nil {
            table = Table(Constants.tableName)

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
        }

        return table!
    }

    // MARK: - Internal fields

    private let connection: Connection

    private var table: Table?
    private let idColumn = Expression<String>(Constants.idColumnName)
    private let registeredAtColumn = Expression<Int>(Constants.registeredAtColumnName)

    private enum Constants {
        static let tableName = "users"

        static let idColumnName = "id"
        static let registeredAtColumnName = "registeredAt"
    }
}
