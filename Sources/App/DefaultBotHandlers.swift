import Vapor
import Logging
import telegram_vapor_bot
import Schedule
import SQLite

final class DefaultBotHandlers {

    // MARK: - Public methods and properties

    public static func addHandlers(
        app: Vapor.Application,
        bot: TGBotPrtcl,
        usersRepository: UsersRepository,
        activitiesRepository: ActivitiesRepository
    ) {
        log("Initializing bot...")

        self.usersRepository = usersRepository
        self.activitiesRepository = activitiesRepository
        self.bot = bot

        setupStartHandler(app: app, bot: bot)

        setupButtonsActionHandler(app: app, bot: bot)

        setupActivities()
    }

    // MARK: - Internal methods

    /// add handler for command "/start"
    private static func setupStartHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Commands.start]) { update, bot in
            let userId = "\(update.message!.chat.id)"
            let registeredAtTimestamp = Int(Date().timeIntervalSince1970)

            let userToRegister = User(withId: userId, registeredAtTimestamp: registeredAtTimestamp)

            _Concurrency.Task {
                _ = await usersRepository?.registerUser(userToRegister)

                sendMessage(
                    toUserWithId: update.message!.chat.id,
                    message: "Приветствую, я буду помогать тебе следить за качеством отношений с твоей женщиной.\n - Я буду напоминать о ежедневных, еженедельных и ежемесячных вещах, которые ты должен делать, чтобы проявлять о ней заботу и чтобы она чувствовала себя защищенной\n- Я буду проводить опрос о том, что ты сделал за день, неделю, месяц\n - На основании этих опросов мы будем следить насколько ты был плох или хорош, прогессируют ли ваши отношения или ухудшаются\n - Также я буду периодически присылать обучающий конент, чтобы ты понимал почему делать те или иные вещи важно, что чувствуют мужчины и женщины при тех или иных событиях и как себя более правильно вести\n - Все будет хорошо, но нужно немного поработать, результат зависит от тебя"
                )
            }
        }

        bot.connection.dispatcher.add(handler)
    }

    /// add callbacks for buttons
    private static func setupButtonsActionHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        // Handle morning activities replies
        let dailyMorningActivityYesButtonHandler = TGCallbackQueryHandler(
            pattern: Constants.dailyReportMorningActivityYes) { update, bot in
                _Concurrency.Task {
                    let userId = update.callbackQuery!.message!.chat.id

                    _ = await activitiesRepository?.registerActivity(
                        Activity(
                            withUserId: "\(userId)",
                            type: .dailyMorningActivity,
                            data: "1",
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                    )

                    askAboutDailyLunchActivity(ofUserWithId: userId)
                }
        }

        let dailyMorningActivityNoButtonHandler = TGCallbackQueryHandler(
            pattern: Constants.dailyReportMorningActivityNo) { update, bot in
                _Concurrency.Task {
                    let userId = update.callbackQuery!.message!.chat.id

                    _ = await activitiesRepository?.registerActivity(
                        Activity(
                            withUserId: "\(userId)",
                            type: .dailyMorningActivity,
                            data: "0",
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                    )

                    askAboutDailyLunchActivity(ofUserWithId: userId)
                }
        }

        // Handle lunch activities reply

        let dailyLunchActivityYesButtonHandler = TGCallbackQueryHandler(
            pattern: Constants.dailyReportLunchActivityYes) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id

                _Concurrency.Task {
                    _ = await activitiesRepository?.registerActivity(
                        Activity(
                            withUserId: "\(userId)",
                            type: .dailyLunchActivity,
                            data: "1",
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                    )

                    askAboutDailyEveningActivity(ofUserWithId: userId)
                }
        }

        let dailyLunchActivityNoButtonHandler = TGCallbackQueryHandler(
            pattern: Constants.dailyReportLunchActivityNo) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id

                _Concurrency.Task {
                    _ = await activitiesRepository?.registerActivity(
                        Activity(
                            withUserId: "\(userId)",
                            type: .dailyLunchActivity,
                            data: "0",
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                    )

                    askAboutDailyEveningActivity(ofUserWithId: userId)
                }
        }

        // Handle evening activities reply

        let dailyEveningActivityYesButtonHandler = TGCallbackQueryHandler(
            pattern: Constants.dailyReportEveningActivityYes) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id

                _Concurrency.Task {
                    _ = await activitiesRepository?.registerActivity(
                        Activity(
                            withUserId: "\(userId)",
                            type: .dailyLunchActivity,
                            data: "1",
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                    )
                }

                sendDailyReport(toUserWithId: userId)
        }

        let dailyEveningActivityNoButtonHandler = TGCallbackQueryHandler(
            pattern: Constants.dailyReportEveningActivityNo) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id

                _Concurrency.Task {
                    _ = await activitiesRepository?.registerActivity(
                        Activity(
                            withUserId: "\(userId)",
                            type: .dailyEveningActivity,
                            data: "0",
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                    )
                }

                sendDailyReport(toUserWithId: userId)
        }

        bot.connection.dispatcher.add(dailyMorningActivityYesButtonHandler)
        bot.connection.dispatcher.add(dailyMorningActivityNoButtonHandler)
        bot.connection.dispatcher.add(dailyLunchActivityYesButtonHandler)
        bot.connection.dispatcher.add(dailyLunchActivityNoButtonHandler)
        bot.connection.dispatcher.add(dailyEveningActivityYesButtonHandler)
        bot.connection.dispatcher.add(dailyEveningActivityNoButtonHandler)
    }

    private static func setupActivities() {
        log("Setting up activities...")

        setupStatusLogging()
        setupDailyActivities()

        log("Activities setup complected")
    }

    private static func setupStatusLogging() {
        statusLoggingTask = Plan.every(1.minute).do(queue: .global()) {
            log("[STATUS] - Alive")
        }
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
        log(" [ACTIVITY] - Sending morning activities reminders")
        sendMessageToAllUsers("Доброе утро, \n - не забудь спросить о самочувствии и планах день")
    }

    private static func handleDailyLunchActivity() {
        log(" [ACTIVITY] - Sending lunch activities reminders")
        sendMessageToAllUsers("Добрый день, \n - не забудь позвонить или отправить сообщение \n - узнать как дела \n какие планы на вечер")
    }

    private static func handleDailyEveningActivity() {
        log(" [ACTIVITY] - Sending evening activities reminders")
        sendMessageToAllUsers("Добрый вечер, \n - не забудь забудь узнать как прошел день \n - как настроение, не устала ли \n - возможно были какие-то беспокойства (родственник заболел, конфликт на работе), уточни все ли в порядке, уладилось ли, возможно нужна помощь \n - возможно сегодня неплохой момент, чтобы выполнить недельный ритуал (подарить цветы, принести любимое блюдо на ужин ...)")
    }

    private static func handleDailyReport() {
        log(" [ACTIVITY] - Handling daily reports")
        foreachUser { userId in
            askAboutDailyMorningActivity(ofUserWithId: userId)
        }
    }

    private static func askAboutDailyMorningActivity(ofUserWithId userId: Int64) {
        log(" [ACTIVITY] - Asking about morning activity of user [\(userId)]")

        askAboutDailyActivity(
            ofUserWithId: userId,
            withMessage: "Добрый вечер, время проверить сколько было уделено внимания\nБыли ли выполнены утренние ритуалы?",
            yesButtonId: Constants.dailyReportMorningActivityYes,
            noButtonId: Constants.dailyReportMorningActivityNo
        )
    }

    private static func askAboutDailyLunchActivity(ofUserWithId userId: Int64) {
        log(" [ACTIVITY] - Asking about daily activity of user [\(userId)]")

        askAboutDailyActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены дневные ритуалы?",
            yesButtonId: Constants.dailyReportLunchActivityYes,
            noButtonId: Constants.dailyReportLunchActivityNo
        )
    }

    private static func askAboutDailyEveningActivity(ofUserWithId userId: Int64) {
        log(" [ACTIVITY] - Asking about evening activity of user [\(userId)]")

        askAboutDailyActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены вечерние ритуалы?",
            yesButtonId: Constants.dailyReportEveningActivityYes,
            noButtonId: Constants.dailyReportEveningActivityNo
        )
    }

    private static func askAboutDailyActivity(
        ofUserWithId userId: Int64,
        withMessage message: String,
        yesButtonId: String,
        noButtonId: String
    ) {
        let buttons: [[TGInlineKeyboardButton]] = [[
            .init(
                text: "Нет",
                callbackData: noButtonId
            ),
            .init(
                text: "Да",
                callbackData: yesButtonId
            )
        ]]

        let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
        let params: TGSendMessageParams = .init(
            chatId: .chat(userId),
            text: message,
            replyMarkup: .inlineKeyboardMarkup(keyboard)
        )

        _ = try? bot?.sendMessage(params: params)
    }

    private static func sendMessageToAllUsers(_ message: String) {
        foreachUser { userId in
            sendMessage(toUserWithId: userId, message: message)
        }
    }

    private static func sendMessage(toUserWithId userId: Int64, message: String) {
        let message = TGSendMessageParams(
            chatId: .chat(userId),
            text: message
        )

        _ = try? bot?.sendMessage(params: message)
    }

    private static func sendDailyReport(toUserWithId userId: Int64) {
        log(" [ACTIVITY] - Sending daily report to user [\(userId)]")

        _Concurrency.Task {
            let startOfDayTimestamp = Date().startOfDay.timeIntervalSince1970
            let endOfDayTimestamp = Date().endOfDay.timeIntervalSince1970

            let userDailyActivities = await activitiesRepository!.loadActivities(
                ofUserWithId: "\(userId)",
                fromTimestamp: Int(startOfDayTimestamp),
                toTimestamp: Int(endOfDayTimestamp)
            )

            var score = 0
            for activity in userDailyActivities {
                if [ActivityType.dailyMorningActivity,
                    ActivityType.dailyLunchActivity,
                    ActivityType.dailyEveningActivity
                ].contains(activity.type),
                   activity.data == "1" {
                    score += Constants.dailyActivityScore
                }
            }

            let message = "За сегодня было набрано \(score) балл(а)"

            sendMessage(toUserWithId: userId, message: message)

            log(" [ACTIVITY] - Sent daily report to user [\(userId)]")
        }
    }

    typealias ForeachUserCallback = (Int64) -> Void

    private static func foreachUser(do action: @escaping ForeachUserCallback) {
        _Concurrency.Task {
            let registeredUsers = await usersRepository!.loadUsers()

            for user in registeredUsers {
                if let chatId = Int64(user.id) {
                    action(chatId)
                }
            }
        }
    }

    private static func log(_ message: String) {
        let logger = Logger(label: "RelatioBotSwift")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: Date())
        logger.info("\(dateString): \(message)")
    }

    // MARK: - Internal fields

    private static var usersRepository: UsersRepository?
    private static var activitiesRepository: ActivitiesRepository?
    private static var bot: TGBotPrtcl?

    private static var statusLoggingTask: Schedule.Task!

    private static var dailyMorningActivityTask: Schedule.Task!
    private static var dailyLunchActivityTask: Schedule.Task!
    private static var dailyEveningActivityTask: Schedule.Task!
    private static var dailyReportTask: Schedule.Task!

    private enum Commands {
        static let start = "/start"
    }

    private enum Constants {
        static let dailyReportMorningActivityYes = "dailyReportMorningActivityYes"
        static let dailyReportMorningActivityNo = "dailyReportMorningActivityNo"
        static let dailyReportLunchActivityYes = "dailyReportLunchActivityYes"
        static let dailyReportLunchActivityNo = "dailyReportLunchActivityNo"
        static let dailyReportEveningActivityYes = "dailyReportEveningActivityYes"
        static let dailyReportEveningActivityNo = "dailyReportEveningActivityNo"

        static let dailyActivityScore = 1
    }
}
