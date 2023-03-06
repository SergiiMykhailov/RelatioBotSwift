import Foundation
import App
import ArgumentParser
import Logging

let sharedLogger = Logger(label: "relatio=bot")

struct Runner: ParsableCommand {
    @Option var isStaging: Bool = false

    func run() {
        guard let databaseConnection = SQLiteDefaultConnectionProvider.instance.connection else {
            return
        }

        sharedLogger.info("Starting build: \(type(of: self).buildVersion)")

        let bot = Bot(
            withUsersRepository: SQLiteUsersRepository(withConnection: databaseConnection),
            activitiesRepository: SQLiteActivitiesRepository(withConnection: databaseConnection),
            isStaging: isStaging
        )

        bot.run()
    }

    // MARK: - Internal fields

    private static let buildVersion = "Staging - 1"

}

Runner.main()


