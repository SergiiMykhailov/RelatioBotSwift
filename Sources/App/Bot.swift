import TelegramBotSDK
import Schedule
import Foundation
import Logging

public final class Bot {

    // MARK: - Public methods and properties

    public init(
        withUsersRepository usersRepository: UsersRepository,
        activitiesRepository: ActivitiesRepository,
        isStaging: Bool = false
    ) {
        self.usersRepository = usersRepository
        self.activitiesRepository = activitiesRepository

        let token = isStaging ? Constants.stagingToken : Constants.productionToken
        self.bot = TelegramBot(token: token)
        self.router = Router(bot: bot)

        setupRoutes()
        setupButtons()
    }

    public func run() {
        if isRunning {
            return
        }

        isRunning = true

        setupActivities()

        while let update = bot.nextUpdateSync() {
            _ = try? router.process(update: update)
        }
    }

    // MARK: - Internal methods

    private func setupRoutes() {
        registerRoute(
            withName: Commands.start) { [weak self] context in
                self?.handleStart(withContext: context)
            }
        registerRoute(
            withName: Commands.help) { [weak self] context in
                self?.handleHelp(withContext: context)
            }
        registerRoute(
            withName: Commands.dailyProgress) { [weak self] context in
                self?.handleDailyProgress(withContext: context)
            }
        registerRoute(
            withName: Commands.weeklyProgress) { [weak self] context in
                self?.handleWeeklyProgress(withContext: context)
            }
        registerRoute(
            withName: Commands.monthlyProgress) { [weak self] context in
                self?.handleMonthlyProgress(withContext: context)
            }
        registerRoute(
            withName: Commands.totalUsersCount) { [weak self] context in
                self?.handleTotalUsersCount(withContext: context)
            }

        // Debugging

        registerRoute(
            withName: Commands.debugReport) { [weak self] context in
                self?.handleReport()
            }
        registerRoute(withName: Commands.ping) { [weak self] context in
            self?.handlePing(withContext: context)
        }
    }

    private func setupButtons() {
        registerButton(
            withId: ButtonsIdentifiers.registerMaleUser) { [weak self] context in
                self?.handleRegisteringMaleUser(withContext: context)
            }
        registerButton(
            withId: ButtonsIdentifiers.registerFemaleUser) { [weak self] context in
                self?.handleRegisteringFemaleUser(withContext: context)
            }

        registerButton(
            withId: ButtonsIdentifiers.dailyReportMorningActivityYes) { [weak self] context in
                self?.handleDailyMorningActivityYesButton(withContext: context)
            }
        registerButton(
            withId: ButtonsIdentifiers.dailyReportMorningActivityNo) { [weak self] context in
                self?.handleDailyMorningActivityNoButton(withContext: context)
            }

        registerButton(
            withId: ButtonsIdentifiers.dailyReportLunchActivityYes) { [weak self] context in
                self?.handleDailyLunchActivityYesButton(withContext: context)
            }
        registerButton(
            withId: ButtonsIdentifiers.dailyReportLunchActivityNo) { [weak self] context in
                self?.handleDailyLunchActivityNoButton(withContext: context)
            }

        registerButton(
            withId: ButtonsIdentifiers.dailyReportEveningActivityYes) { [weak self] context in
                self?.handleDailyEveningActivityYesButton(withContext: context)
            }
        registerButton(
            withId: ButtonsIdentifiers.dailyReportEveningActivityNo) { [weak self] context in
                self?.handleDailyEveningActivityNoButton(withContext: context)
            }

        registerButton(
            withId: ButtonsIdentifiers.weeklyActivityYes) { [weak self] context in
                self?.handleWeeklyActivityYesButton(withContext: context)
            }
        registerButton(
            withId: ButtonsIdentifiers.weeklyActivityNo) { [weak self] context in
                self?.handleWeeklyActivityNoButton(withContext: context)
            }

        registerButton(
            withId: ButtonsIdentifiers.monthlyActivityYes) { [weak self] context in
                self?.handleMonthlyActivityYesButton(withContext: context)
            }
        registerButton(
            withId: ButtonsIdentifiers.monthlyActivityNo) { [weak self] context in
                self?.handleMonthlyActivityNoButton(withContext: context)
            }

        registerButton(
            withId: ButtonsIdentifiers.heroActivityYes) { [weak self] context in
                self?.handleHeroActivityYesButton(withContext: context)
            }
        registerButton(
            withId: ButtonsIdentifiers.heroActivityNo) { [weak self] context in
                self?.handleHeroActivityNoButton(withContext: context)
            }
    }

    typealias RouteHandlingCallback = (Context) -> Void
    private func registerRoute(
        withName routeName: String,
        andHandler handler: @escaping RouteHandlingCallback
    ) {
        router[routeName, .slashRequired] = { context in
            handler(context)
            return true
        }
    }

    typealias ButtonHandlingCallback = (Context) -> Void
    private func registerButton(
        withId buttonId: String,
        andHandler handler: @escaping ButtonHandlingCallback
    ) {
        router[.callback_query(data: buttonId)] = { context in
            handler(context)
            return true
        }
    }

    private func setupActivities() {
        type(of: self).log("Setting up activities")

        dailyReportTask = Plan.every(
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday)
            .at(Constants.surveyTime)
            .do(queue: .global()) { [weak self] in
                self?.handleReport()
        }
    }

    typealias ForeachUserCallback = (Int64) -> Void
    private func foreachUser(do action: @escaping ForeachUserCallback) {
        _Concurrency.Task {
            let registeredUsers = await usersRepository.loadUsers()

            for user in registeredUsers {
                if let chatId = Int64(user.id) {
                    action(chatId)
                }
            }
        }
    }

    // MARK: - Command handlers

    private func handleStart(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        let markup = InlineKeyboardMarkup(
            inlineKeyboard: [
                [
                    InlineKeyboardButton(text: "Женский", callbackData: ButtonsIdentifiers.registerFemaleUser),
                    InlineKeyboardButton(text: "Мужской", callbackData: ButtonsIdentifiers.registerMaleUser)
                ]
            ]
        )

        let message = "Приветствую, я помогаю мужчинам и женщинам работать над качеством их отношений, чтобы сделать их счастливыми.\nПоскольку мужчинам и женщинам нужны разные вещи, чтобы чувствовать себя счастливыми, я буду присылать разные инструкции.\nДля этого мне нужно знать твой пол."

        bot.sendMessageAsync(
            chatId: .chat(userId),
            text: message,
            replyMarkup: ReplyMarkup.inlineKeyboardMarkup(markup)
        )
    }

    private func handleHelp(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        bot.sendMessageAsync(
            chatId: .chat(userId),
            text: "\(Commands.dailyProgress) - Показать динамику по дням\n\(Commands.weeklyProgress) - Показать динамику по неделям\n\(Commands.monthlyProgress) - Показать динамику по месяцам"
        )
    }

    private func handleDailyProgress(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            let dailyProgress = await calculateDailyProgressScore(ofUserWithId: userId)

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: formatDailyProgress(dailyProgress)
            )
        }
    }

    private func handleWeeklyProgress(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            let weeklyProgress = await calculateWeeklyProgressScore(ofUserWithId: userId)

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: formatWeeklyProgress(weeklyProgress)
            )
        }
    }

    private func handleMonthlyProgress(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            let monthlyProgress = await calculateMonthlyProgressScore(ofUserWithId: userId)

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: formatMonthlyProgress(monthlyProgress)
            )
        }
    }

    private func handleTotalUsersCount(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            let registeredUsers = await usersRepository.loadUsers()

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: "Всего зарегистрировано пользователей: \(registeredUsers.count)"
            )
        }
    }

    private func handleDailyActiveUsers(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            var result = [Int]()

            for itemIndex in 0..<Constants.dailyProgressItemsCount {
                let daysOffset = -itemIndex
                let referenceDay = Date.today().dayByOffsetting(numberOfDays: daysOffset)

                let referenceDayResult = await calculateActiveUsers(
                    fromTimestamp: referenceDay.startOfDay.timeIntervalSince1970,
                    toTimestamp: referenceDay.endOfDay.timeIntervalSince1970
                )

                result.append(referenceDayResult)
            }

            result = trimEmptyEntries(from: result)

            let message = formatSequence(
                withPrefix: "Активные пользователи по дням (от текущего и назад): ",
                result,
                suffix: ""
            )

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: message
            )
        }
    }

    private func handleWeeklyActiveUsers(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            var result = [Int]()

            for itemIndex in 0..<Constants.weeklyProgressItemsCount {
                let daysOffset = -itemIndex * Constants.daysPerWeek
                let referenceWeekDay = Date.today().dayByOffsetting(numberOfDays: daysOffset)

                let referenceWeekResult = await calculateActiveUsers(
                    fromTimestamp: referenceWeekDay.startOfWeek.timeIntervalSince1970,
                    toTimestamp: referenceWeekDay.endOfWeek.timeIntervalSince1970
                )

                result.append(referenceWeekResult)
            }

            result = trimEmptyEntries(from: result)

            let message = formatSequence(
                withPrefix: "Активные пользователи по неделям (от текущей и назад): ",
                result,
                suffix: ""
            )

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: message
            )
        }
    }

    private func handleMonthlyActiveUsers(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            var result = [Int]()

            for itemIndex in 0..<Constants.monthlyProgressItemsCount {
                let monthsOffset = -itemIndex
                let referenceMonthDay = Date.today().dayByOffsetting(numberOfMonths: monthsOffset)

                let referenceMonthResult = await calculateActiveUsers(
                    fromTimestamp: referenceMonthDay.startOfMonth.timeIntervalSince1970,
                    toTimestamp: referenceMonthDay.endOfMonth.timeIntervalSince1970
                )

                result.append(referenceMonthResult)
            }

            result = trimEmptyEntries(from: result)

            let message = formatSequence(
                withPrefix: "Активные пользователи по месяцам (от текущего и назад): ",
                result,
                suffix: ""
            )

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: message
            )
        }
    }

    // MARK: - Button handlers

    private func handleRegisteringMaleUser(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        let registeredAtTimestamp = Int(Date().timeIntervalSince1970)
        let userToRegister = User(
            withId: "\(userId)",
            gender: .male,
            registeredAtTimestamp: registeredAtTimestamp
        )

        _Concurrency.Task {
            _ = await usersRepository.registerUser(userToRegister)

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: "Приветствую, я буду помогать тебе следить за качеством отношений с твоей женщиной.\n- Я буду напоминать о ежедневных, еженедельных и ежемесячных вещах, которые ты должен делать, чтобы проявлять о ней заботу и чтобы она чувствовала себя защищенной\n- Я буду проводить опрос о том, что ты сделал за день, неделю, месяц\n- На основании этих опросов мы будем следить насколько ты был плох или хорош, прогрессируют ли ваши отношения или ухудшаются\n- Ты будешь набирать баллы (тактико-технические действия, ТТД, как у Лобановского в футболе)\n- Также я буду периодически присылать обучающий контент, чтобы ты понимал почему делать те или иные вещи важно, что чувствуют мужчины и женщины при тех или иных событиях и как себя более правильно вести\n- Все будет хорошо, но нужно немного поработать, результат зависит только от тебя"
            )
        }
    }

    private func handleRegisteringFemaleUser(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        let registeredAtTimestamp = Int(Date().timeIntervalSince1970)
        let userToRegister = User(
            withId: "\(userId)",
            gender: .female,
            registeredAtTimestamp: registeredAtTimestamp
        )

        _Concurrency.Task {
            _ = await usersRepository.registerUser(userToRegister)

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: "Приветствую, я буду помогать тебе следить за твоим самочувствием и качеством отношений с твоим мужчиной.\n- Я буду напоминать о ежедневных вещах, на которые нужно обращать внимание, чтобы чувствовать себя хорошо.\n- Я буду проводить опрос о том, хорошо ли прошел твой день, позаботился ли твой мужчина о тебе, беспокоит ли тебя что-то\n- На основании этих опросов мы будем следить прогрессируют ли ваши отношения или ухудшаются, а также отслеживать твое эмоциональное состояние\n- Ты будешь набирать баллы (тактико-технические действия, ТТД, как у Лобановского в футболе)\n- Также я буду периодически присылать обучающий контент, чтобы ты понимала почему делать те или иные вещи важно, что чувствуют мужчины и женщины при тех или иных событиях и как себя более правильно вести\n- Все будет хорошо, но нужно немного поработать, результат зависит только от тебя"
            )
        }
    }

    private func handleDailyMorningActivityYesButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            _ = await activitiesRepository.registerActivity(
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

    private func handleDailyMorningActivityNoButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        askAboutDailyLunchActivity(ofUserWithId: userId)
    }

    private func handleDailyLunchActivityYesButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            _ = await activitiesRepository.registerActivity(
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

    private func handleDailyLunchActivityNoButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }
        
        askAboutDailyEveningActivity(ofUserWithId: userId)
    }

    private func handleDailyEveningActivityYesButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            _ = await activitiesRepository.registerActivity(
                Activity(
                    withUserId: "\(userId)",
                    type: .dailyLunchActivity,
                    data: "1",
                    timestamp: Int(Date().timeIntervalSince1970)
                )
            )

            askAboutWeeklyActivity(ofUserWithId: userId)
        }
    }

    private func handleDailyEveningActivityNoButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }
        
        askAboutWeeklyActivity(ofUserWithId: userId)
    }

    private func handleWeeklyActivityYesButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            _ = await activitiesRepository.registerActivity(
                Activity(
                    withUserId: "\(userId)",
                    type: .weeklyActivity,
                    data: "1",
                    timestamp: Int(Date().timeIntervalSince1970)
                )
            )

            askAboutMonthlyActivity(ofUserWithId: userId)
        }
    }

    private func handleWeeklyActivityNoButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }
        
        askAboutMonthlyActivity(ofUserWithId: userId)
    }

    private func handleMonthlyActivityYesButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            _ = await activitiesRepository.registerActivity(
                Activity(
                    withUserId: "\(userId)",
                    type: .monthlyActivity,
                    data: "1",
                    timestamp: Int(Date().timeIntervalSince1970)
                )
            )

            askAboutHeroActivity(ofUserWithId: userId)
        }
    }

    private func handleMonthlyActivityNoButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }
        
        askAboutHeroActivity(ofUserWithId: userId)
    }

    private func handleHeroActivityYesButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        _Concurrency.Task {
            _ = await activitiesRepository.registerActivity(
                Activity(
                    withUserId: "\(userId)",
                    type: .heroActivity,
                    data: "1",
                    timestamp: Int(Date().timeIntervalSince1970)
                )
            )

            sendReport(toUserWithId: userId)
        }
    }

    private func handleHeroActivityNoButton(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }
        
        sendReport(toUserWithId: userId)
    }

    // MARK: - Routine

    private func handleReport() {
        type(of: self).log("[ACTIVITY] - Handling daily reports")

        foreachUser { [weak self] userId in
            guard let self = self else {
                return
            }

            type(of: self).log("[ACTIVITY] - Start processing report of user [\(userId)]")
            self.askAboutDailyMorningActivity(ofUserWithId: userId)
        }
    }

    private func handlePing(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        bot.sendMessageAsync(
            chatId: .chat(userId),
            text: "pong"
        )
    }

    private func askAboutDailyMorningActivity(ofUserWithId userId: Int64) {
        type(of: self).log("[ACTIVITY] - Asking about morning activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Добрый вечер, время проверить сколько было уделено внимания\nБыли ли выполнены утренние ритуалы?\n(узнал как самочувствие и планах?) (+\(Constants.dailyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.dailyReportMorningActivityYes,
            noButtonId: ButtonsIdentifiers.dailyReportMorningActivityNo
        )
    }

    private func askAboutDailyLunchActivity(ofUserWithId userId: Int64) {
        type(of: self).log("[ACTIVITY] - Asking about daily activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены дневные ритуалы?\n(Узнал про планы на вечер, как проходит день?) (+\(Constants.dailyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.dailyReportLunchActivityYes,
            noButtonId: ButtonsIdentifiers.dailyReportLunchActivityNo
        )
    }

    private func askAboutDailyEveningActivity(ofUserWithId userId: Int64) {
        type(of: self).log("[ACTIVITY] - Asking about evening activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены вечерние ритуалы?\n(Узнал нет ли проблем на работе, все ли в порядке с родственниками, нужна ли твоя помощь в каком-то вопросе?) (+\(Constants.dailyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.dailyReportEveningActivityYes,
            noButtonId: ButtonsIdentifiers.dailyReportEveningActivityNo
        )
    }

    private func askAboutWeeklyActivity(ofUserWithId userId: Int64) {
        type(of: self).log("[ACTIVITY] - Asking about weekly activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены недельные ритуалы?\n(Подарил цветы? Любимое блюдо принес? В ресторан пригласил?) (+\(Constants.weeklyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.weeklyActivityYes,
            noButtonId: ButtonsIdentifiers.weeklyActivityNo
        )
    }

    private func askAboutMonthlyActivity(ofUserWithId userId: Int64) {
        type(of: self).log("[ACTIVITY] - Asking about monthly activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены месячные ритуалы?\n(Выделил \"карманные\"? Купил подарок (драгоценность, сертификат в СПА, билет на концерт)?) (+\(Constants.monthlyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.monthlyActivityYes,
            noButtonId: ButtonsIdentifiers.monthlyActivityNo
        )
    }

    private func askAboutHeroActivity(ofUserWithId userId: Int64) {
        type(of: self).log("[ACTIVITY] - Asking about monthly activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Возможно сегодня ты сделал что-то очень выдающееся?\n(Она попала в ДТП, разбила машину, а ты успокоил, уладил и починил машину или у нее украли телефон, а ты купил новый...) (+\(Constants.heroActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.heroActivityYes,
            noButtonId: ButtonsIdentifiers.heroActivityNo
        )
    }

    private func askAboutActivity(
        ofUserWithId userId: Int64,
        withMessage message: String,
        yesButtonId: String,
        noButtonId: String
    ) {
        let markup = InlineKeyboardMarkup(
            inlineKeyboard: [
                [
                    InlineKeyboardButton(text: "Да", callbackData: yesButtonId),
                    InlineKeyboardButton(text: "Нет", callbackData: noButtonId)
                ]
            ]
        )

        bot.sendMessageAsync(
            chatId: .chat(userId),
            text: message,
            replyMarkup: ReplyMarkup.inlineKeyboardMarkup(markup)
        )
    }

    private func sendReport(toUserWithId userId: Int64) {
        type(of: self).log("[ACTIVITY] - Sending daily report to user [\(userId)]")

        _Concurrency.Task {
            let dailyScore = await calculateDailyScore(ofUserWithId: userId)

            var message = "За сегодня было набрано \(dailyScore) ТТД"

            let dailyProgress = await calculateDailyProgressScore(ofUserWithId: userId)
            message += "\n\(formatDailyProgress(dailyProgress))"

            if let weeklyScore = await calculateWeeklyScoreIfNeeded(ofUserWithId: userId) {
                message += "\n\nНа этой неделе было набрано \(weeklyScore) ТТД"

                let weeklyProgress = await calculateWeeklyProgressScore(ofUserWithId: userId)
                message += "\n\(formatWeeklyProgress(weeklyProgress))"
            }

            if let monthlyScore = await calculateMonthlyScoreIfNeeded(ofUserWithId: userId) {
                message += "\nВ этом месяце было набрано \(monthlyScore) ТТД"

                let monthlyProgress = await calculateMonthlyProgressScore(ofUserWithId: userId)
                message += "\n\(formatMonthlyProgress(monthlyProgress))"
            }

            message += "\n\nЧтобы просмотреть список всех доступных команд, введите /help"

            let videoOfTheDayUrl = Constants.videos[Int.random(in: 0..<Constants.videos.count)]
            message += "\n\nВидео дня: \(videoOfTheDayUrl)"

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: message
            )

            type(of: self).log("[ACTIVITY] - Sent report to user [\(userId)]")
        }
    }

    private func calculateScore(
        ofUserWithId userId: Int64,
        fromStartTimestamp startTimestamp: TimeInterval,
        toTimestamp endTimestamp: TimeInterval,
        ofActivities activities: [ActivityType],
        withActivityScore activityScore: Int
    ) async -> Int {
        let userActivities = await activitiesRepository.loadActivities(
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

    private func calculateAllActivitiesScore(
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

    private func calculateDailyScore(
        ofUserWithId userId: Int64
    ) async -> Int {
        let result = await calculateAllActivitiesScore(
            ofUserWithId: userId,
            fromTimestamp: Date().startOfDay.timeIntervalSince1970,
            toTimestamp: Date().endOfDay.timeIntervalSince1970
        )

        return result
    }

    private func calculateDailyProgressScore(
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

    private func calculateWeeklyProgressScore(
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

    private func calculateMonthlyProgressScore(
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

    private func trimEmptyEntries(
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

    private func calculateActiveUsers(
        fromTimestamp: TimeInterval,
        toTimestamp: TimeInterval
    ) async -> Int {
        var result = 0

        let registeredUsers = await usersRepository.loadUsers()

        for user in registeredUsers {
            if let chatId = Int64(user.id) {
                let userActivities = await activitiesRepository.loadActivities(
                    ofUserWithId: "\(chatId)",
                    fromTimestamp: Int(fromTimestamp),
                    toTimestamp: Int(toTimestamp)
                )

                if !userActivities.isEmpty {
                    result += 1
                }
            }
        }

        return result
    }

    private func formatDailyProgress(_ progressItems: [Int]) -> String {
        return formatSequence(
            withPrefix: "Динамика по дням (от сегодняшнего и назад): ",
            progressItems,
            suffix: " ТТД"
        )
    }

    private func formatWeeklyProgress(_ progressItems: [Int]) -> String {
        return formatSequence(
            withPrefix: "Динамика по неделям (от текущей и назад): ",
            progressItems,
            suffix: " ТТД"
        )
    }

    private func formatMonthlyProgress(_ progressItems: [Int]) -> String {
        return formatSequence(
            withPrefix: "Динамика по месяцам (от текущего и назад): ",
            progressItems,
            suffix: " ТТД"
        )
    }

    private func formatSequence(
        withPrefix prefix: String,
        _ progressItems: [Int],
        suffix: String
    ) -> String {
        var result = prefix

        for itemIndex in 0..<progressItems.count {
            let currentItem = progressItems[itemIndex]

            result += "\(currentItem)"

            if (itemIndex < progressItems.count - 1) {
                result += " - "
            }
        }

        result += suffix

        return result
    }

    private func calculateWeeklyScoreIfNeeded(
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

    private func calculateMonthlyScoreIfNeeded(
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

    private static func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: Date())

        logger.info("\(dateString): \(message)")
    }

    // MARK: - Internal fields

    private let usersRepository: UsersRepository
    private let activitiesRepository: ActivitiesRepository
    private let bot: TelegramBot
    private let router: Router
    private var isRunning = false
    private var dailyReportTask: Schedule.Task?

    private static let logger = Logger(label: "relatio-bot")

    private enum Commands {
        static let start = "start"
        static let help = "help"

        static let dailyProgress = "dailyProgress"
        static let weeklyProgress = "weeklyProgress"
        static let monthlyProgress = "monthlyProgress"

        static let totalUsersCount = "totalUsersCount"
        static let dailyActiveUsers = "dau"
        static let weeklyActiveUsers = "wau"
        static let monthlyActiveUsers = "mau"

        static let debugReport = "debugReport"
        static let ping = "ping"
    }

    private enum ButtonsIdentifiers {
        static let registerMaleUser = "registerMaleUser"
        static let registerFemaleUser = "registerFemaleUser"
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
    }

    private enum Constants {
        static let productionToken = "5455319702:AAGIpKMjUdPsXW7rZOe5phxV492E5LrHnvg"
        static let stagingToken = "6163360177:AAHzaxJG8vMoZ5r85ynHDBddGkNV9i9UMEE"

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

        static let videos: [String] = [
            "https://youtu.be/7O0sX4qKUEI",
            "https://youtu.be/o8IEiVYX0ho",
            "https://youtu.be/bNf20tloKok",
            "https://youtu.be/YnGetAmNxAY",
            "https://youtu.be/NJ9KBM1J0T8",
            "https://youtu.be/Yoq17zrLWv8",
            "https://youtu.be/GFpAMjXC6gI",
            "https://youtu.be/0ciNBkyUSpw",
            "https://youtu.be/lF26e1KgK_8",
            "https://youtu.be/DG0RMDpjypk",
            "https://youtu.be/Wr6Gs2QcV_g",
            "https://youtu.be/7mngcjDkqks",
            "https://youtu.be/e4iqYhZma3A",
            "https://youtu.be/lxf0wCM5TAg",
            "https://youtu.be/OzTdYEd-aaE",
            "https://youtu.be/-YqiuRrokr8",
            "https://youtu.be/b9_Vfw7tL3M",
            "https://youtu.be/tLfs6PMDKeU",
            "https://youtu.be/l8IxXMXmyJ8",
            "https://youtu.be/F6i32sk-kp4",
            "https://youtu.be/cM7R0fZm628",
            "https://youtu.be/egwAuZGSXPk",
            "https://youtu.be/mxr9Q052t2o",
            "https://youtu.be/KrIXOqjyHu0",
            "https://youtu.be/qpgEzA8HfC8",
            "https://youtu.be/Ni5QsCzZ-lQ",
            "https://youtu.be/v83FxNd7aCA",
            "https://youtu.be/T9lIM1x2tnE",
            "https://youtu.be/zo2PzGkW9PQ",
            "https://youtu.be/GYwsz1PcHMg",
            "https://youtu.be/zzEb-v2RmrQ",
            "https://youtu.be/jgGQnZkvdBs",
            "https://youtu.be/TTv4gG0MhYQ",
            "https://youtu.be/SNawAbFqWZk",
            "https://youtu.be/QnjUV2wQ3Yc",
            "https://youtu.be/WKN6TgCg_Ss",
            "https://youtu.be/wCICc1b_lIE",
            "https://youtu.be/wCpQM-5peRY",
            "https://youtu.be/5Ba23vxyoZY",
            "https://youtu.be/H_a-HflDMsc",
            "https://youtu.be/kxRD0u7JosE",
            "https://youtu.be/kIBmXaVeG9g",
            "https://youtu.be/VGkNYwX7D38",
            "https://youtu.be/U4NS8k5BakY",
            "https://youtu.be/YX4yOAeo928",
            "https://youtu.be/IEU4BAms_tc",
            "https://youtu.be/t0Zqlz4CCS8",
            "https://youtu.be/0T7iitubunk",
            "https://youtu.be/TgDAoCINsSE",
            "https://youtu.be/snTC0Wn75HU",
            "https://youtu.be/GHdL1QBwfo0",
            "https://youtu.be/v1hHCYyExgU",
            "https://youtu.be/PIHFV-XETHk",
            "https://youtu.be/mGQDM1cQ_bs",
            "https://youtu.be/DsLlztjHgys",
            "https://youtu.be/8zoyiTuFenU",
            "https://youtu.be/VLjlljREgvE",
            "https://youtu.be/dDToO_kKkw4",
            "https://youtu.be/iz843xOVmgU",
            "https://youtu.be/EKhp-C6CFjM",
            "https://youtu.be/VZx2eqAiq64",
            "https://youtu.be/xPMiK1ksBbs",
            "https://youtu.be/oCt92DJflHc",
            "https://youtu.be/5E8FYriAJTE",
            "https://youtu.be/HPtt7mgdPs0",
            "https://youtu.be/JlTnMh40BQ4",
            "https://youtu.be/heT88OD0fNY",
            "https://youtu.be/xwwoAHJm5Rk",
            "https://youtu.be/IOUOQf2gof8",
            "https://youtu.be/xwMRRHkb9fo",
            "https://youtu.be/V_rAvdwZKTA",
            "https://youtu.be/ktsg7kJjBio",
            "https://youtu.be/6uG4-DbYtJQ",
            "https://youtu.be/FgWohARdd1Q",
            "https://youtu.be/K0OSdjTORuU",
            "https://youtu.be/_mCoc_fwJcw",
            "https://youtu.be/JfYxO2msUTA",
            "https://youtu.be/kmrMiQ5RO30",
            "https://youtu.be/mjdS_LaQ-Ug",
            "https://youtu.be/I1kcv3MSCks",
            "https://youtu.be/VXo0HT4108c",
            "https://youtu.be/527BLIm7Oqg",
            "https://youtu.be/3x1wPuHszLQ",
            "https://youtu.be/AlEU2sQrEto",
            "https://youtu.be/7a6029gpUs8",
            "https://youtu.be/hm74EcjAcOg",
            "https://youtu.be/uhaJ69-kiLo",
            "https://youtu.be/UV2D0g8DksU",
            "https://youtu.be/XF6Cl9MnlNE",
            "https://youtu.be/ojw-eC5lpXM",
            "https://youtu.be/nkuDhU7sJ8c",
            "https://youtu.be/ol9fcIbAKJc",
            "https://youtu.be/bqNa0IuVoiU",
            "https://youtu.be/bNHql8u9Iws",
            "https://youtu.be/A2TyuzeR6No",
            "https://youtu.be/e6VtxFQoruU",
            "https://youtu.be/0QL8otuf7Ig",
            "https://youtu.be/zZoejoMwt80",
            "https://youtu.be/zpNYR9q6xiM",
            "https://youtu.be/KW_bf9XVMfk",
            "https://youtu.be/FFO0qFH9m2s",
            "https://youtu.be/CZOYHppZh_A",
            "https://youtu.be/tZT9Ub7qGlA",
            "https://youtu.be/BTmXUvwbvtI",
            "https://youtu.be/HEYd2Jxqdk4",
            "https://youtu.be/AQT-GG2cqtI",
            "https://youtu.be/tylH7W2BKN8",
            "https://youtu.be/37JeZNol2QY",
            "https://youtu.be/ImqBVv7JMx8",
            "https://youtu.be/afWba2qgWqE",
            "https://youtu.be/XvDEoe1zyjE",
            "https://youtu.be/VSEHIqHeWKQ",
            "https://youtu.be/6Y6S2X8UipA",
            "https://youtu.be/lH8APLAl3fI",
            "https://youtu.be/w0Q6sgfsNko",
            "https://youtu.be/CS2V8IJb21s",
            "https://youtu.be/MHl8wHp_t3U",
            "https://youtu.be/VZVEV9l-vIo",
            "https://youtu.be/832MY0Na9Is",
            "https://youtu.be/sDvW2L2WwDs",
            "https://youtu.be/l3CnmHXGAIw",
            "https://youtu.be/Pxd3NCVhIg0",
            "https://youtu.be/6y17VNRYr9A",
            "https://youtu.be/JOVOXEqoIb4",
            "https://youtu.be/Su8EB02jXM0",
            "https://youtu.be/PuyVASMAMXc",
            "https://youtu.be/0-1Wh8BacX8",
            "https://youtu.be/99MjstRls3s",
            "https://youtu.be/WDFq-KVl0eA",
            "https://youtu.be/mMCBlcxfVuE",
            "https://youtu.be/h2ujbxkYEDM",
            "https://youtu.be/i2G-nLwuh1c",
            "https://youtu.be/YZ4RGbVj67M",
            "https://youtu.be/yeWyyhvPed0",
            "https://youtu.be/hczeBV_mJuc",
            "https://youtu.be/H6cTbUBQTbM",
            "https://youtu.be/Lr7ftfBvXIg",
            "https://youtu.be/fP8rrZbetP0",
            "https://youtu.be/ICnPL-J9J2M",
            "https://youtu.be/_3SsMc2Wih4",
            "https://youtu.be/Q-_X33KDmck",
            "https://youtu.be/Qtybw4RlTvU",
            "https://youtu.be/mm-Nd5-Z06A",
            "https://youtu.be/n1wAJ8XU4Ak",
            "https://youtu.be/n0luKX63Vs8",
            "https://youtu.be/eX12XVuhFeI",
            "https://youtu.be/tWEvUM6mzIM",
            "https://youtu.be/vcDJ8BfXfCg",
            "https://youtu.be/NsOdy9rZBR0",
            "https://youtu.be/qQ4Sk3OTZV8",
            "https://youtu.be/QDLwmIZmy4Y",
            "https://youtu.be/09353VyPvH8",
            "https://youtu.be/Ud-kBX9sEAk",
            "https://youtu.be/z5mkAmkhrJY",
            "https://youtu.be/_xYvV7-dZNo",
            "https://youtu.be/f9NxGDjo9hc",
            "https://youtu.be/-DTU6SSu_JU",
            "https://youtu.be/YzRaCe2WDFk",
            "https://youtu.be/R1CXKjj4vs8",
            "https://youtu.be/LQfJOjphJSE",
            "https://youtu.be/_b2pTuzcrPs",
            "https://youtu.be/qi49kQ1vX3I",
            "https://youtu.be/vWcKs_QD6PM",
            "https://youtu.be/vC6Ii9j8jRU",
            "https://youtu.be/bkvcEHt3hFI",
            "https://youtu.be/rgwinxkudnc",
            "https://youtu.be/G_EhdA9rVPs",
            "https://youtu.be/_aquRicAX8U",
            "https://youtu.be/vcJI-fQmTKM",
            "https://youtu.be/MkigNYPtS-Q",
            "https://youtu.be/rs197xbPt9g",
            "https://youtu.be/bLx_7mY_U_s",
            "https://youtu.be/pHCShZaKQ0Y",
            "https://youtu.be/2Pyj-ZjPKf0",
            "https://youtu.be/n9EvvISEUe8",
            "https://youtu.be/SAY0vYEyAng",
            "https://youtu.be/ZwTEX7tc8sM",
            "https://youtu.be/MWJmrK8S6dM",
            "https://youtu.be/bJYjRbyijy0",
            "https://youtu.be/FNPP-INMz_Y",
            "https://youtu.be/0Duz5UWx3b8",
            "https://youtu.be/VynLpzfn9bQ",
            "https://youtu.be/szdDMgh3eFI",
            "https://youtu.be/OHqsNkzGxUA",
            "https://youtu.be/RvDBfYOrT5E",
            "https://youtu.be/PBu9Gi2SwXs",
            "https://youtu.be/tWMMxwXXjbM",
            "https://youtu.be/aItyTE_BzLU",
            "https://youtu.be/dGXoYoLJDpQ",
            "https://youtu.be/UP5-0HaqmVQ",
            "https://youtu.be/AqMLZCxpW9E",
            "https://youtu.be/XP8C10makp4",
            "https://youtu.be/7jEaN4Qt-fU",
            "https://youtu.be/AN425TRveZU",
            "https://youtu.be/ZBIFNQHJ2oA",
            "https://youtu.be/gnX8GK5ZHAA",
            "https://youtu.be/Am3s8XCEarE",
            "https://youtu.be/qwI0GRqv_Yc",
            "https://youtu.be/vdaT9TUFaxA",
            "https://youtu.be/Xt6YdhWCmOs",
            "https://youtu.be/5IzxdL24WzU",
            "https://youtu.be/5IzxdL24WzU",
            "https://youtu.be/NAD3VBguE84",
            "https://youtu.be/J_iAaFbmppM",
            "https://youtu.be/wnaCNxGKcDg",
            "https://youtu.be/6ulsFRDtIzw",
            "https://youtu.be/R9qSf1hobEU",
            "https://youtu.be/klvNJKOUHTI",
            "https://youtu.be/PweQBER7UC4",
            "https://youtu.be/QDLDTIW7tZg",
            "https://youtu.be/ldcA50RcJxQ",
            "https://youtu.be/eknvINiN1_E",
            "https://youtu.be/WOg-5spIBcA",
            "https://youtu.be/AkPTCz8zqCc",
            "https://youtu.be/H_HmFvj9tjA",
            "https://youtu.be/W9LXILq4PN4",
            "https://youtu.be/j_SlcgxcW6Y",
            "https://youtu.be/NSN1cw8CoqQ",
            "https://youtu.be/3iH68pGsoLU",
            "https://youtu.be/VyH_mqrVnSI",
            "https://youtu.be/cB_g3podQKc",
            "https://youtu.be/g4subPOiw-E"
        ]
    }

}
