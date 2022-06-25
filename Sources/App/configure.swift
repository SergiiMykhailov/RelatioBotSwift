import Vapor
import telegram_vapor_bot

// configures your application
let tgApi: String = "5455319702:AAGIpKMjUdPsXW7rZOe5phxV492E5LrHnvg"

public func configure(_ app: Application) throws {
    let connection: TGConnectionPrtcl = TGLongPollingConnection()
    TGBot.configure(connection: connection, botId: tgApi, vaporClient: app.client)
    try TGBot.shared.start()

    /// set level of debug if you needed
    TGBot.log.logLevel = .error

    DefaultBotHandlers.addHandlers(app: app, bot: TGBot.shared)

    // register routes
    try routes(app)
}
