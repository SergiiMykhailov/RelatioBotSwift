import Foundation
import App

guard let databaseConnection = SQLiteDefaultConnectionProvider.instance.connection else {
    exit(1)
}

let bot = Bot(
    withUsersRepository: SQLiteUsersRepository(withConnection: databaseConnection),
    activitiesRepository: SQLiteActivitiesRepository(withConnection: databaseConnection)
)

bot.run()
