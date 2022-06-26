import Vapor
import telegram_vapor_bot
import Schedule

final class DefaultBotHandlers {

    // MARK: - Public methods and properties

    public static func addHandlers(
        app: Vapor.Application,
        bot: TGBotPrtcl,
        usersRepository: UsersRepository
    ) {
        self.usersRepository = usersRepository
        self.bot = bot

        setupDefaultHandler(app: app, bot: bot)
        setupStartHandler(app: app, bot: bot)

        commandShowButtonsHandler(app: app, bot: bot)
        buttonsActionHandler(app: app, bot: bot)

        setupActivities()
    }

    // MARK: - Internal methods

    /// add handler for all messages unless command "/start"
    private static func setupDefaultHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGMessageHandler(filters: (.all && !.command.names([Commands.start]))) { update, bot in
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: "Success")
            try bot.sendMessage(params: params)
        }

        bot.connection.dispatcher.add(handler)
    }

    /// add handler for command "/start"
    private static func setupStartHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Commands.start]) { update, bot in
            let userId = "\(update.message!.chat.id)"
            let registeredAtTimestamp = Int(Date().timeIntervalSince1970)

            let userToRegister = User(withId: userId, registeredAtTimestamp: registeredAtTimestamp)

            _Concurrency.Task {
                await usersRepository?.registerUser(userToRegister)
            }
        }

        bot.connection.dispatcher.add(handler)
    }

    /// add handler for command "/show_buttons" - show message with buttons
    private static func commandShowButtonsHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: ["/show_buttons"]) { update, bot in
            guard let userId = update.message?.from?.id else { fatalError("user id not found") }
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Button 1", callbackData: "press 1"), .init(text: "Button 2", callbackData: "press 2")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Keyboard activ",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try bot.sendMessage(params: params)
        }

        bot.connection.dispatcher.add(handler)
    }

    /// add two handlers for callbacks buttons
    private static func buttonsActionHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCallbackQueryHandler(pattern: "press 1") { update, bot in
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: update.callbackQuery?.data  ?? "data not exist",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try bot.answerCallbackQuery(params: params)
        }

        let handler2 = TGCallbackQueryHandler(pattern: "press 2") { update, bot in
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: update.callbackQuery?.data  ?? "data not exist",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try bot.answerCallbackQuery(params: params)
        }

        bot.connection.dispatcher.add(handler)
        bot.connection.dispatcher.add(handler2)
    }

    private static func setupActivities() {
        setupDailyActivities()
    }

    private static func setupDailyActivities() {
        dailyMorningActivityTask = Plan.every(
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday)
            .at("10:00")
            .do(queue: .global()) {
            handleDailyMorningActivity()
        }

        dailyLunchActivityTask = Plan.every(
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday)
            .at("14:00")
            .do(queue: .global()) {
            handleDailyLunchActivity()
        }

        dailyEveningActivityTask = Plan.every(
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday)
            .at("19:00")
            .do(queue: .global()) {
            handleDailyEveningActivity()
        }

        dailyReportTask = Plan.every(
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday)
            .at("22:00")
            .do(queue: .global()) {
            handleDailyReport()
        }
    }

    private static func handleDailyMorningActivity() {
        _Concurrency.Task {
            let registeredUsers = await usersRepository!.loadUsers()

            for user in registeredUsers {
                if let chatId = Int64(user.id) {
                    let message = TGSendMessageParams(
                        chatId: .chat(chatId),
                        text: "Good morning"
                    )

                    _ = try? bot?.sendMessage(params: message)
                }
            }
        }
    }

    private static func handleDailyLunchActivity() {

    }

    private static func handleDailyEveningActivity() {

    }

    private static func handleDailyReport() {

    }

    // MARK: - Internal fields

    private static var usersRepository: UsersRepository?
    private static var bot: TGBotPrtcl?

    private static var dailyMorningActivityTask: Schedule.Task!
    private static var dailyLunchActivityTask: Schedule.Task!
    private static var dailyEveningActivityTask: Schedule.Task!
    private static var dailyReportTask: Schedule.Task!

    private enum Commands {
        static let start = "/start"
    }
}
