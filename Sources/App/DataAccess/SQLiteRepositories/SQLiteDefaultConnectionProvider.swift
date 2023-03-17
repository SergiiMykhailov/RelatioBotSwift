import SQLite

public class SQLiteDefaultConnectionProvider {

    // MARK: - Public methods and properties

    public static let instance = SQLiteDefaultConnectionProvider()
    public let connection: Connection!

    // MARK: - Internal methods

    private init() {
        do {
            self.connection = try Connection(Constants.fileName)
        }
        catch {
            self.connection = nil
        }
    }

    // MARK: - Internal fields

    private enum Constants {
        static let fileName = "data.db"
    }
}
