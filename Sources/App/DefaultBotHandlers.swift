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
        self.usersRepository = usersRepository
        self.activitiesRepository = activitiesRepository
        self.bot = bot

        setupStartHandler(app: app, bot: bot)
        setupHelpHandler(app: app, bot: bot)
        setupDailyProgressHandler(app: app, bot: bot)
        setupWeeklyProgressHandler(app: app, bot: bot)
        setupMonthlyProgressHandler(app: app, bot: bot)

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
                    message: "Приветствую, я буду помогать тебе следить за качеством отношений с твоей женщиной.\n- Я буду напоминать о ежедневных, еженедельных и ежемесячных вещах, которые ты должен делать, чтобы проявлять о ней заботу и чтобы она чувствовала себя защищенной\n- Я буду проводить опрос о том, что ты сделал за день, неделю, месяц\n- На основании этих опросов мы будем следить насколько ты был плох или хорош, прогессируют ли ваши отношения или ухудшаются\n- Ты будешь набирать баллы (тактико-технические действие, ТТД, как у Лобановского в футболе)\n- Также я буду периодически присылать обучающий конент, чтобы ты понимал почему делать те или иные вещи важно, что чувствуют мужчины и женщины при тех или иных событиях и как себя более правильно вести\n- Все будет хорошо, но нужно немного поработать, результат зависит от тебя"
                )
            }
        }

        bot.connection.dispatcher.add(handler)
    }

    /// add handler for command "/help"
    private static func setupHelpHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Commands.start]) { update, bot in
            sendMessage(
                toUserWithId: update.message!.chat.id,
                message: "/dailyProgress - Показать динамику по дням\n/weeklyProgress - Показать динамику по неделям\n/monthlyProgress - Показать динамику по месяцам"
            )
        }

        bot.connection.dispatcher.add(handler)
    }

    /// add handler for command "/dailyProgress"
    private static func setupDailyProgressHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Commands.start]) { update, bot in
            _Concurrency.Task {
                let dailyProgress = await calculateDailyProgressScore(ofUserWithId: update.message!.chat.id)
                let formattedDailyProgress = formatProgress(dailyProgress)

                let message = "Динамика по дням: \(formattedDailyProgress) ТТД"

                sendMessage(
                    toUserWithId: update.message!.chat.id,
                    message: message
                )
            }
        }

        bot.connection.dispatcher.add(handler)
    }

    /// add handler for command "/weeklyProgress"
    private static func setupWeeklyProgressHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Commands.start]) { update, bot in
            _Concurrency.Task {
                let weeklyProgress = await calculateWeeklyProgressScore(ofUserWithId: update.message!.chat.id)
                let formattedWeeklyProgress = formatProgress(weeklyProgress)

                let message = "Динамика по неделям: \(formattedWeeklyProgress) ТТД"

                sendMessage(
                    toUserWithId: update.message!.chat.id,
                    message: message
                )
            }
        }

        bot.connection.dispatcher.add(handler)
    }

    /// add handler for command "/monthlyProgress"
    private static func setupMonthlyProgressHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Commands.start]) { update, bot in
            _Concurrency.Task {
                let monthlyProgress = await calculateMonthlyProgressScore(ofUserWithId: update.message!.chat.id)
                let formattedMonthlyProgress = formatProgress(monthlyProgress)

                let message = "Динамика по месяцам: \(formattedMonthlyProgress) ТТД"

                sendMessage(
                    toUserWithId: update.message!.chat.id,
                    message: message
                )
            }
        }

        bot.connection.dispatcher.add(handler)
    }

    /// add callbacks for buttons
    private static func setupButtonsActionHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        bot.connection.dispatcher.add(makeDailyMorningActivityYesButtonHandler())
        bot.connection.dispatcher.add(makeDailyMorningActivityNoButtonHandler())
        bot.connection.dispatcher.add(makeDailyLunchActivityYesButtonHandler())
        bot.connection.dispatcher.add(makeDailyLunchActivityNoButtonHandler())
        bot.connection.dispatcher.add(makeDailyEveningActivityYesButtonHandler())
        bot.connection.dispatcher.add(makeDailyEveningActivityNoButtonHandler())
        bot.connection.dispatcher.add(makeWeeklyActivityYesButtonHandler())
        bot.connection.dispatcher.add(makeWeeklyActivityNoButtonHandler())
        bot.connection.dispatcher.add(makeMonthlyActivityYesButtonHandler())
        bot.connection.dispatcher.add(makeMonthlyActivityNoButtonHandler())
        bot.connection.dispatcher.add(makeHeroActivityYesButtonHandler())
        bot.connection.dispatcher.add(makeHeroActivityNoButtonHandler())
    }

    private static func makeDailyMorningActivityYesButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
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
    }

    private static func makeDailyMorningActivityNoButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
            pattern: Constants.dailyReportMorningActivityNo) { update, bot in
                _Concurrency.Task {
                    let userId = update.callbackQuery!.message!.chat.id
                    askAboutDailyLunchActivity(ofUserWithId: userId)
                }
        }
    }

    private static func makeDailyLunchActivityYesButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
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
    }

    private static func makeDailyLunchActivityNoButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
            pattern: Constants.dailyReportLunchActivityNo) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id
                askAboutDailyEveningActivity(ofUserWithId: userId)
        }
    }

    private static func makeDailyEveningActivityYesButtonHandler() -> TGCallbackQueryHandler {
        TGCallbackQueryHandler(
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

                askAboutWeeklyActivity(ofUserWithId: userId)
        }
    }

    private static func makeDailyEveningActivityNoButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
            pattern: Constants.dailyReportEveningActivityNo) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id
                askAboutWeeklyActivity(ofUserWithId: userId)
        }
    }

    private static func makeWeeklyActivityYesButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
            pattern: Constants.weeklyActivityYes) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id

                _Concurrency.Task {
                    _ = await activitiesRepository?.registerActivity(
                        Activity(
                            withUserId: "\(userId)",
                            type: .weeklyActivity,
                            data: "1",
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                    )
                }

                askAboutMonthlyActivity(ofUserWithId: userId)
        }
    }

    private static func makeWeeklyActivityNoButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
            pattern: Constants.weeklyActivityNo) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id
                askAboutMonthlyActivity(ofUserWithId: userId)
        }
    }

    private static func makeMonthlyActivityYesButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
            pattern: Constants.monthlyActivityYes) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id

                _Concurrency.Task {
                    _ = await activitiesRepository?.registerActivity(
                        Activity(
                            withUserId: "\(userId)",
                            type: .monthlyActivity,
                            data: "1",
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                    )
                }

                askAboutHeroActivity(ofUserWithId: userId)
        }
    }

    private static func makeMonthlyActivityNoButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
            pattern: Constants.monthlyActivityNo) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id
                askAboutHeroActivity(ofUserWithId: userId)
        }
    }

    private static func makeHeroActivityYesButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
            pattern: Constants.heroActivityYes) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id

                _Concurrency.Task {
                    _ = await activitiesRepository?.registerActivity(
                        Activity(
                            withUserId: "\(userId)",
                            type: .heroActivity,
                            data: "1",
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                    )
                }

                sendReport(toUserWithId: userId)
        }
    }

    private static func makeHeroActivityNoButtonHandler() -> TGCallbackQueryHandler {
        return TGCallbackQueryHandler(
            pattern: Constants.heroActivityNo) { update, bot in
                let userId = update.callbackQuery!.message!.chat.id
                sendReport(toUserWithId: userId)
        }
    }

    private static func setupActivities() {
        setupDailyActivities()
    }

    private static func setupDailyActivities() {
        dailyMorningActivityTask = Plan.every(
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday)
            .at(Constants.morningReminderTime)
            .do(queue: .global()) {
            handleDailyMorningActivity()
        }

        dailyLunchActivityTask = Plan.every(
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday)
            .at(Constants.lunchReminderTime)
            .do(queue: .global()) {
            handleDailyLunchActivity()
        }

        dailyEveningActivityTask = Plan.every(
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday)
            .at(Constants.eveningReminderTime)
            .do(queue: .global()) {
            handleDailyEveningActivity()
        }

        dailyReportTask = Plan.every(
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday)
            .at(Constants.surveyTime)
            .do(queue: .global()) {
            handleReport()
        }
    }

    private static func handleDailyMorningActivity() {
        log("[ACTIVITY] - Sending morning activities reminders")
        sendMessageToAllUsers("Доброе утро, \n - не забудь спросить о самочувствии и планах день (+\(Constants.dailyActivityScore) ТТД)")
    }

    private static func handleDailyLunchActivity() {
        log("[ACTIVITY] - Sending lunch activities reminders")
        sendMessageToAllUsers("Добрый день, \n - не забудь позвонить или отправить сообщение \n - узнать как дела \n какие планы на вечер (+\(Constants.dailyActivityScore) ТТД)")
    }

    private static func handleDailyEveningActivity() {
        log("[ACTIVITY] - Sending evening activities reminders")
        sendMessageToAllUsers("Добрый вечер,\n - не забудь забудь узнать как прошел день \n - как настроение, не устала ли \n - возможно были какие-то беспокойства (родственник заболел, конфликт на работе), уточни все ли в порядке, уладилось ли, возможно нужна помощь (+\(Constants.dailyActivityScore) ТТД) \n - возможно сегодня неплохой момент, чтобы выполнить недельный ритуал (подарить цветы, принести любимое блюдо на ужин, пригласить на ужин в ресторан ...) (+\(Constants.weeklyActivityScore) ТТД) \n - подумай над месячным ритуалом, возможно сегодня тоже можно его выполнить (выделить \"карманные\", купить подарок (драгоценность, сертификат в СПА, билет на концерт)) (+\(Constants.monthlyActivityScore) ТТД)")
    }

    private static func handleReport() {
        log("[ACTIVITY] - Handling daily reports")
        foreachUser { userId in
            askAboutDailyMorningActivity(ofUserWithId: userId)
        }
    }

    private static func askAboutDailyMorningActivity(ofUserWithId userId: Int64) {
        log("[ACTIVITY] - Asking about morning activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Добрый вечер, время проверить сколько было уделено внимания\nБыли ли выполнены утренние ритуалы?\n(узнал как самочувствие и планах?) (+\(Constants.dailyActivityScore) ТТД)",
            yesButtonId: Constants.dailyReportMorningActivityYes,
            noButtonId: Constants.dailyReportMorningActivityNo
        )
    }

    private static func askAboutDailyLunchActivity(ofUserWithId userId: Int64) {
        log("[ACTIVITY] - Asking about daily activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены дневные ритуалы?\n(Узнал про планы на вечер, как проходит день?) (+\(Constants.dailyActivityScore) ТТД)",
            yesButtonId: Constants.dailyReportLunchActivityYes,
            noButtonId: Constants.dailyReportLunchActivityNo
        )
    }

    private static func askAboutDailyEveningActivity(ofUserWithId userId: Int64) {
        log("[ACTIVITY] - Asking about evening activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены вечерние ритуалы?\n(Узнал нет ли проблем на работе, все ли в порядке с родственниками, нужна ли твоя помощь в каком-то вопросе?) (+\(Constants.dailyActivityScore) ТТД)",
            yesButtonId: Constants.dailyReportEveningActivityYes,
            noButtonId: Constants.dailyReportEveningActivityNo
        )
    }

    private static func askAboutWeeklyActivity(ofUserWithId userId: Int64) {
        log("[ACTIVITY] - Asking about weekly activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены недельные ритуалы?\n(Подарил цветы? Любимое блюдо принес? В ресторан пригласил?) (+\(Constants.weeklyActivityScore) ТТД)",
            yesButtonId: Constants.weeklyActivityYes,
            noButtonId: Constants.weeklyActivityNo
        )
    }

    private static func askAboutMonthlyActivity(ofUserWithId userId: Int64) {
        log("[ACTIVITY] - Asking about monthly activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены месячные ритуалы?\n(Выделил \"карманные\"? Купил подарок (драгоценность, сертификат в СПА, билет на концерт)?) (+\(Constants.monthlyActivityScore) ТТД)",
            yesButtonId: Constants.monthlyActivityYes,
            noButtonId: Constants.monthlyActivityNo
        )
    }

    private static func askAboutHeroActivity(ofUserWithId userId: Int64) {
        log("[ACTIVITY] - Asking about monthly activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Возможно сегодня ты сделал что-то очень выдающееся?\n(Она попала в ДТП, разбила машину, а ты успокоил, уладил и починил машину или у нее украли телефон, а ты купил новый...) (+\(Constants.heroActivityScore) ТТД)",
            yesButtonId: Constants.heroActivityYes,
            noButtonId: Constants.heroActivityNo
        )
    }

    private static func askAboutActivity(
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

    private static func sendReport(toUserWithId userId: Int64) {
        log("[ACTIVITY] - Sending daily report to user [\(userId)]")

        _Concurrency.Task {
            let dailyScore = await calculateDailyScore(ofUserWithId: userId)

            var message = "За сегодня было набрано \(dailyScore) ТТД"

            let dailyProgress = await calculateDailyProgressScore(ofUserWithId: userId)
            let formattedDailyProgress = formatProgress(dailyProgress)
            message += "\nДинамика по дням: \(formattedDailyProgress) ТТД"

            if let weeklyScore = await calculateWeeklyScoreIfNeeded(ofUserWithId: userId) {
                message += "\n\nНа этой неделе было набрано \(weeklyScore) ТТД"

                let weeklyProgress = await calculateWeeklyProgressScore(ofUserWithId: userId)
                let formattedWeeklyProgress = formatProgress(weeklyProgress)
                message += "\nДинамика по неделям: \(formattedWeeklyProgress) ТТД"
            }

            if let monthlyScore = await calculateMonthlyScoreIfNeeded(ofUserWithId: userId) {
                message += "\nВ этом месяце было набрано \(monthlyScore) ТТД"
            }

            message += "\nЧтобы просмотреть список всех доступных команд, введите /help"

            sendMessage(toUserWithId: userId, message: message)

            log(" [ACTIVITY] - Sent report to user [\(userId)]")
        }
    }

    private static func calculateScore(
        ofUserWithId userId: Int64,
        fromStartTimestamp startTimestamp: TimeInterval,
        toTimestamp endTimestamp: TimeInterval,
        ofActivities activities: [ActivityType],
        withActivityScore activityScore: Int
    ) async -> Int {
        let userActivities = await activitiesRepository!.loadActivities(
            ofUserWithId: "\(userId)",
            fromTimestamp: Int(startTimestamp),
            toTimestamp: Int(endTimestamp)
        )

        var score = 0
        for activity in userActivities {
            if activities.contains(activity.type),
               activity.data == "1" {
                score += activityScore
            }
        }

        return score
    }

    private static func calculateAllActivitiesScore(
        ofUserWithId userId: Int64,
        fromTimestamp startTimestamp: TimeInterval,
        toTimestamp endTimestamp: TimeInterval
    ) async -> Int {
        let dailyActivitiesScore = await calculateScore(
            ofUserWithId: userId,
            fromStartTimestamp: startTimestamp,
            toTimestamp: endTimestamp,
            ofActivities: [
                .dailyMorningActivity,
                .dailyLunchActivity,
                .dailyEveningActivity
            ],
            withActivityScore: Constants.dailyActivityScore
        )

        let weeklyActivitiesScore = await calculateScore(
            ofUserWithId: userId,
            fromStartTimestamp: startTimestamp,
            toTimestamp: endTimestamp,
            ofActivities: [.weeklyActivity],
            withActivityScore: Constants.weeklyActivityScore
        )

        let monthlyActivitiesScore = await calculateScore(
            ofUserWithId: userId,
            fromStartTimestamp: startTimestamp,
            toTimestamp: endTimestamp,
            ofActivities: [.monthlyActivity],
            withActivityScore: Constants.monthlyActivityScore
        )

        let heroActivitiesScore = await calculateScore(
            ofUserWithId: userId,
            fromStartTimestamp: startTimestamp,
            toTimestamp: endTimestamp,
            ofActivities: [.heroActivity],
            withActivityScore: Constants.heroActivityScore
        )

        let result = dailyActivitiesScore
            + weeklyActivitiesScore
            + monthlyActivitiesScore
            + heroActivitiesScore

        return result
    }

    private static func calculateDailyScore(
        ofUserWithId userId: Int64
    ) async -> Int {
        let result = await calculateAllActivitiesScore(
            ofUserWithId: userId,
            fromTimestamp: Date().startOfDay.timeIntervalSince1970,
            toTimestamp: Date().endOfDay.timeIntervalSince1970
        )

        return result
    }

    private static func calculateDailyProgressScore(
        ofUserWithId userId: Int64
    ) async -> [Int] {
        var result = [Int]()

        for itemIndex in 0..<Constants.dailyProgressItemsCount {
            let daysOffset = -itemIndex
            let referenceDay = Date.today().dayByOffsetting(numberOfDays: daysOffset)

            let referenceDayResult = await calculateAllActivitiesScore(
                ofUserWithId: userId,
                fromTimestamp: referenceDay.startOfDay.timeIntervalSince1970,
                toTimestamp: referenceDay.endOfDay.timeIntervalSince1970
            )

            result.append(referenceDayResult)
        }

        result = trimEmptyEntries(from: result)

        return result
    }

    private static func calculateWeeklyProgressScore(
        ofUserWithId userId: Int64
    ) async -> [Int] {
        var result = [Int]()

        for itemIndex in 0..<Constants.weeklyProgressItemsCount {
            let daysOffset = -itemIndex * Constants.daysPerWeek
            let referenceWeekDay = Date.today().dayByOffsetting(numberOfDays: daysOffset)

            let referenceDayResult = await calculateAllActivitiesScore(
                ofUserWithId: userId,
                fromTimestamp: referenceWeekDay.startOfWeek.timeIntervalSince1970,
                toTimestamp: referenceWeekDay.endOfWeek.timeIntervalSince1970
            )

            result.append(referenceDayResult)
        }

        result = trimEmptyEntries(from: result)

        return result
    }

    private static func calculateMonthlyProgressScore(
        ofUserWithId userId: Int64
    ) async -> [Int] {
        var result = [Int]()

        for itemIndex in 0..<Constants.monthlyProgressItemsCount {
            let monthsOffset = -itemIndex
            let referenceMonthDay = Date.today().dayByOffsetting(numberOfMonths: monthsOffset)

            let referenceMonthResult = await calculateAllActivitiesScore(
                ofUserWithId: userId,
                fromTimestamp: referenceMonthDay.startOfMonth.timeIntervalSince1970,
                toTimestamp: referenceMonthDay.endOfMonth.timeIntervalSince1970
            )

            result.append(referenceMonthResult)
        }

        result = trimEmptyEntries(from: result)

        return result
    }

    private static func trimEmptyEntries(
        from sourceEntries: [Int]
    ) -> [Int] {
        var result = [Int]()

        for outerLoopIndex in 0..<sourceEntries.count {
            let currentItem = sourceEntries[outerLoopIndex]

            if currentItem != 0 {
                result.append(currentItem)
                continue
            }

            // Check if all succeeding items are zero.
            // If they are then do not add current item and terminate the process.
            // Otherwise add current item and continue.
            var areAllSucceedingItemsZero = true
            for innerLoopIndex in (outerLoopIndex + 1)..<sourceEntries.count {
                let remainingItem = sourceEntries[innerLoopIndex]
                if remainingItem != 0 {
                    areAllSucceedingItemsZero = false
                    break
                }
            }

            if areAllSucceedingItemsZero {
                break
            }

            result.append(currentItem)
        }

        return result
    }

    private static func formatProgress(_ progressItems: [Int]) -> String {
        var result = ""

        for itemIndex in 0..<progressItems.count {
            let currentItem = progressItems[itemIndex]

            result += "\(currentItem)"

            if (itemIndex < progressItems.count - 1) {
                result += " - "
            }
        }

        return result
    }

    private static func calculateWeeklyScoreIfNeeded(
        ofUserWithId userId: Int64
    ) async -> Int? {
        if Date.today().dayOfWeek != .sunday {
            return nil
        }

        let result = await calculateAllActivitiesScore(
            ofUserWithId: userId,
            fromTimestamp: Date().startOfWeek.timeIntervalSince1970,
            toTimestamp: Date().endOfWeek.timeIntervalSince1970
        )

        return result
    }

    private static func calculateMonthlyScoreIfNeeded(
        ofUserWithId userId: Int64
    ) async -> Int? {
        if !Date.today().isLastDayOfMonth {
            return nil
        }

        let result = await calculateAllActivitiesScore(
            ofUserWithId: userId,
            fromTimestamp: Date().startOfMonth.timeIntervalSince1970,
            toTimestamp: Date().endOfMonth.timeIntervalSince1970
        )

        return result
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
        static let weeklyActivityYes = "weeklyActivityYes"
        static let weeklyActivityNo = "weeklyActivityNo"
        static let monthlyActivityYes = "monthlyActivityYes"
        static let monthlyActivityNo = "monthlyActivityNo"
        static let heroActivityYes = "heroActivityYes"
        static let heroActivityNo = "heroActivityNo"

        static let morningReminderTime = "10:00"
        static let lunchReminderTime = "14:00"
        static let eveningReminderTime = "19:00"
        static let surveyTime = "22:00"

        static let dailyActivityScore = 1
        static let weeklyActivityScore = 5
        static let monthlyActivityScore = 15
        static let heroActivityScore = 50

        static let dailyProgressItemsCount = 10
        static let weeklyProgressItemsCount = 10
        static let monthlyProgressItemsCount = 10
        static let daysPerWeek = 7
    }
}
