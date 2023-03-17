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

extension SQLiteUsersRepository : UsersRepository {

    public func registerUser(_ user: User) async -> Bool {
        let table = setupTableIfNeeded()

        do {
            try connection.run(
                table.insert(or: .rollback, idColumn <- user.id, registeredAtColumn <- user.registeredAtTimestamp)
            )

            return true
        }
        catch {
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

}
