import TelegramBotSDK
import SwiftCron
import Foundation
import Logging

final class MaleController {

    // MARK: - Public methods and properties

    public init(
        withBot bot: TelegramBot,
        router: Router,
        usersRepository: UsersRepository,
        activitiesRepository: ActivitiesRepository
    ) {
        self.bot = bot
        self.router = router
        self.usersRepository = usersRepository
        self.activitiesRepository = activitiesRepository

        setupRoutes()
        setupButtons()
    }

    public func run() {
        if isRunning {
            return
        }

        setupActivities()
    }

    // MARK: - Internal methods

    private func setupActivities() {
        Logger.log("MaleController: Setting up activities")

        dailyReportTask = ScheduledTask(
            schedule: Schedule(
                time: DateComponents(hour: 18),
                repeatType: .daily
            ),
            taskBlock: { [weak self] in
                self?.handleReport()
            }
        )
        dailyReportTask?.start()
    }

    private func setupRoutes() {
        router.registerRoute(
            withName: Commands.help) { [weak self] context in
                self?.handleHelp(withContext: context)
            }

        router.registerRoute(
            withName: Commands.dailyProgress) { [weak self] context in
                self?.handleDailyProgress(withContext: context)
            }
        router.registerRoute(
            withName: Commands.weeklyProgress) { [weak self] context in
                self?.handleWeeklyProgress(withContext: context)
            }
        router.registerRoute(
            withName: Commands.monthlyProgress) { [weak self] context in
                self?.handleMonthlyProgress(withContext: context)
            }

        // Debugging
        router.registerRoute(
            withName: Commands.debugReport) { [weak self] context in
                self?.handleReport()
            }
    }

    private func setupButtons() {
        router.registerButton(
            withId: ButtonsIdentifiers.dailyReportMorningActivityYes) { [weak self] context in
                self?.handleDailyMorningActivityYesButton(withContext: context)
            }
        router.registerButton(
            withId: ButtonsIdentifiers.dailyReportMorningActivityNo) { [weak self] context in
                self?.handleDailyMorningActivityNoButton(withContext: context)
            }

        router.registerButton(
            withId: ButtonsIdentifiers.dailyReportLunchActivityYes) { [weak self] context in
                self?.handleDailyLunchActivityYesButton(withContext: context)
            }
        router.registerButton(
            withId: ButtonsIdentifiers.dailyReportLunchActivityNo) { [weak self] context in
                self?.handleDailyLunchActivityNoButton(withContext: context)
            }

        router.registerButton(
            withId: ButtonsIdentifiers.dailyReportEveningActivityYes) { [weak self] context in
                self?.handleDailyEveningActivityYesButton(withContext: context)
            }
        router.registerButton(
            withId: ButtonsIdentifiers.dailyReportEveningActivityNo) { [weak self] context in
                self?.handleDailyEveningActivityNoButton(withContext: context)
            }

        router.registerButton(
            withId: ButtonsIdentifiers.weeklyActivityYes) { [weak self] context in
                self?.handleWeeklyActivityYesButton(withContext: context)
            }
        router.registerButton(
            withId: ButtonsIdentifiers.weeklyActivityNo) { [weak self] context in
                self?.handleWeeklyActivityNoButton(withContext: context)
            }

        router.registerButton(
            withId: ButtonsIdentifiers.monthlyActivityYes) { [weak self] context in
                self?.handleMonthlyActivityYesButton(withContext: context)
            }
        router.registerButton(
            withId: ButtonsIdentifiers.monthlyActivityNo) { [weak self] context in
                self?.handleMonthlyActivityNoButton(withContext: context)
            }

        router.registerButton(
            withId: ButtonsIdentifiers.heroActivityYes) { [weak self] context in
                self?.handleHeroActivityYesButton(withContext: context)
            }
        router.registerButton(
            withId: ButtonsIdentifiers.heroActivityNo) { [weak self] context in
                self?.handleHeroActivityNoButton(withContext: context)
            }
    }

    typealias ForeachUserCallback = (Int64) -> Void
    private func foreachUser(do action: @escaping ForeachUserCallback) {
        _Concurrency.Task {
            let registeredUsers = await usersRepository.loadUsers()

            for user in registeredUsers {
                if user.gender == .male, let chatId = Int64(user.id) {
                    action(chatId)
                }
            }
        }
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

    // MARK: - Button handlers

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
        Logger.log("[ACTIVITY] - Handling daily reports")

        foreachUser { [weak self] userId in
            guard let self = self else {
                return
            }

            Logger.log("[ACTIVITY] - Start processing report of user [\(userId)]")
            self.askAboutDailyMorningActivity(ofUserWithId: userId)
        }
    }

    private func askAboutDailyMorningActivity(ofUserWithId userId: Int64) {
        Logger.log("[ACTIVITY] - Asking about morning activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Добрый вечер, время проверить сколько было уделено внимания\nБыли ли выполнены утренние ритуалы?\n(узнал как самочувствие и планах?) (+\(Constants.dailyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.dailyReportMorningActivityYes,
            noButtonId: ButtonsIdentifiers.dailyReportMorningActivityNo
        )
    }

    private func askAboutDailyLunchActivity(ofUserWithId userId: Int64) {
        Logger.log("[ACTIVITY] - Asking about daily activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены дневные ритуалы?\n(Узнал про планы на вечер, как проходит день?) (+\(Constants.dailyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.dailyReportLunchActivityYes,
            noButtonId: ButtonsIdentifiers.dailyReportLunchActivityNo
        )
    }

    private func askAboutDailyEveningActivity(ofUserWithId userId: Int64) {
        Logger.log("[ACTIVITY] - Asking about evening activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены вечерние ритуалы?\n(Узнал нет ли проблем на работе, все ли в порядке с родственниками, нужна ли твоя помощь в каком-то вопросе?) (+\(Constants.dailyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.dailyReportEveningActivityYes,
            noButtonId: ButtonsIdentifiers.dailyReportEveningActivityNo
        )
    }

    private func askAboutWeeklyActivity(ofUserWithId userId: Int64) {
        Logger.log("[ACTIVITY] - Asking about weekly activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены недельные ритуалы?\n(Подарил цветы? Любимое блюдо принес? В ресторан пригласил?) (+\(Constants.weeklyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.weeklyActivityYes,
            noButtonId: ButtonsIdentifiers.weeklyActivityNo
        )
    }

    private func askAboutMonthlyActivity(ofUserWithId userId: Int64) {
        Logger.log("[ACTIVITY] - Asking about monthly activity of user [\(userId)]")

        askAboutActivity(
            ofUserWithId: userId,
            withMessage: "Были ли выполнены месячные ритуалы?\n(Выделил \"карманные\"? Купил подарок (драгоценность, сертификат в СПА, билет на концерт)?) (+\(Constants.monthlyActivityScore) ТТД)",
            yesButtonId: ButtonsIdentifiers.monthlyActivityYes,
            noButtonId: ButtonsIdentifiers.monthlyActivityNo
        )
    }

    private func askAboutHeroActivity(ofUserWithId userId: Int64) {
        Logger.log("[ACTIVITY] - Asking about monthly activity of user [\(userId)]")

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
        Logger.log("[ACTIVITY] - Sending daily report to user [\(userId)]")

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

            let videoOfTheDayUrl = Content.videos[Int.random(in: 0..<Content.videos.count)]
            message += "\n\nВидео дня: \(videoOfTheDayUrl)"

            bot.sendMessageAsync(
                chatId: .chat(userId),
                text: message
            )

            Logger.log("[ACTIVITY] - Sent report to user [\(userId)]")
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

        for itemIndex in 0..<ReportingUtils.Constants.dailyProgressItemsCount {
            let daysOffset = -itemIndex
            let referenceDay = Date.today().dayByOffsetting(numberOfDays: daysOffset)

            let referenceDayResult = await calculateAllActivitiesScore(
                ofUserWithId: userId,
                fromTimestamp: referenceDay.startOfDay.timeIntervalSince1970,
                toTimestamp: referenceDay.endOfDay.timeIntervalSince1970
            )

            result.append(referenceDayResult)
        }

        result = ReportingUtils.trimEmptyEntries(from: result)

        return result
    }

    private func calculateWeeklyProgressScore(
        ofUserWithId userId: Int64
    ) async -> [Int] {
        var result = [Int]()

        for itemIndex in 0..<ReportingUtils.Constants.weeklyProgressItemsCount {
            let daysOffset = -itemIndex * ReportingUtils.Constants.daysPerWeek
            let referenceWeekDay = Date.today().dayByOffsetting(numberOfDays: daysOffset)

            let referenceDayResult = await calculateAllActivitiesScore(
                ofUserWithId: userId,
                fromTimestamp: referenceWeekDay.startOfWeek.timeIntervalSince1970,
                toTimestamp: referenceWeekDay.endOfWeek.timeIntervalSince1970
            )

            result.append(referenceDayResult)
        }

        result = ReportingUtils.trimEmptyEntries(from: result)

        return result
    }

    private func calculateMonthlyProgressScore(
        ofUserWithId userId: Int64
    ) async -> [Int] {
        var result = [Int]()

        for itemIndex in 0..<ReportingUtils.Constants.monthlyProgressItemsCount {
            let monthsOffset = -itemIndex
            let referenceMonthDay = Date.today().dayByOffsetting(numberOfMonths: monthsOffset)

            let referenceMonthResult = await calculateAllActivitiesScore(
                ofUserWithId: userId,
                fromTimestamp: referenceMonthDay.startOfMonth.timeIntervalSince1970,
                toTimestamp: referenceMonthDay.endOfMonth.timeIntervalSince1970
            )

            result.append(referenceMonthResult)
        }

        result = ReportingUtils.trimEmptyEntries(from: result)

        return result
    }

    private func formatDailyProgress(_ progressItems: [Int]) -> String {
        return ReportingUtils.formatSequence(
            withPrefix: "Динамика по дням (от сегодняшнего и назад): ",
            progressItems,
            suffix: " ТТД"
        )
    }

    private func formatWeeklyProgress(_ progressItems: [Int]) -> String {
        return ReportingUtils.formatSequence(
            withPrefix: "Динамика по неделям (от текущей и назад): ",
            progressItems,
            suffix: " ТТД"
        )
    }

    private func formatMonthlyProgress(_ progressItems: [Int]) -> String {
        return ReportingUtils.formatSequence(
            withPrefix: "Динамика по месяцам (от текущего и назад): ",
            progressItems,
            suffix: " ТТД"
        )
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

    // MARK: - Internal fields

    private let bot: TelegramBot
    private let router: Router
    private let usersRepository: UsersRepository
    private let activitiesRepository: ActivitiesRepository

    private var isRunning = false

    private var dailyReportTask: ScheduledTask?

    private enum Constants {
        static let morningReminderTime = "10:00"
        static let lunchReminderTime = "14:00"
        static let eveningReminderTime = "19:00"
        static let surveyTime = "18:00"

        static let dailyActivityScore = 1
        static let weeklyActivityScore = 5
        static let monthlyActivityScore = 15
        static let heroActivityScore = 50
    }

    private enum Commands {
        static let help = "help"

        static let debugReport = "debugMaleReport"

        static let dailyProgress = "dailyProgress"
        static let weeklyProgress = "weeklyProgress"
        static let monthlyProgress = "monthlyProgress"
    }

    private enum ButtonsIdentifiers {
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

}
