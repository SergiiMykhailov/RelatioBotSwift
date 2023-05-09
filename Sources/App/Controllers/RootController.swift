import TelegramBotSDK
import Schedule
import Foundation
import Logging

public final class RootController {

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

        self.maleController = MaleController(
            withBot: self.bot,
            router: self.router,
            usersRepository: self.usersRepository,
            activitiesRepository: self.activitiesRepository
        )

        self.femaleController = FemaleController(
            withBot: self.bot,
            router: self.router,
            usersRepository: usersRepository
        )

        setupRoutes()
        setupButtons()
    }

    public func run() {
        if isRunning {
            return
        }

        isRunning = true

        maleController.run()
        femaleController.run()

        while let update = bot.nextUpdateSync() {
            _ = try? router.process(update: update)
        }
    }

    // MARK: - Internal methods

    private func setupButtons() {
        router.registerButton(
            withId: ButtonsIdentifiers.registerMaleUser) { [weak self] context in
                self?.handleRegisteringMaleUser(withContext: context)
            }
        router.registerButton(
            withId: ButtonsIdentifiers.registerFemaleUser) { [weak self] context in
                self?.handleRegisteringFemaleUser(withContext: context)
            }
    }

    private func setupRoutes() {
        router.registerRoute(
            withName: Commands.start) { [weak self] context in
                self?.handleStart(withContext: context)
            }
        router.registerRoute(
            withName: Commands.totalUsersCount) { [weak self] context in
                self?.handleTotalUsersCount(withContext: context)
            }

        // Debugging
        router.registerRoute(withName: Commands.ping) { [weak self] context in
            self?.handlePing(withContext: context)
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

            for itemIndex in 0..<ReportingUtils.Constants.dailyProgressItemsCount {
                let daysOffset = -itemIndex
                let referenceDay = Date.today().dayByOffsetting(numberOfDays: daysOffset)

                let referenceDayResult = await calculateActiveUsers(
                    fromTimestamp: referenceDay.startOfDay.timeIntervalSince1970,
                    toTimestamp: referenceDay.endOfDay.timeIntervalSince1970
                )

                result.append(referenceDayResult)
            }

            result = ReportingUtils.trimEmptyEntries(from: result)

            let message = ReportingUtils.formatSequence(
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

            for itemIndex in 0..<ReportingUtils.Constants.weeklyProgressItemsCount {
                let daysOffset = -itemIndex * ReportingUtils.Constants.daysPerWeek
                let referenceWeekDay = Date.today().dayByOffsetting(numberOfDays: daysOffset)

                let referenceWeekResult = await calculateActiveUsers(
                    fromTimestamp: referenceWeekDay.startOfWeek.timeIntervalSince1970,
                    toTimestamp: referenceWeekDay.endOfWeek.timeIntervalSince1970
                )

                result.append(referenceWeekResult)
            }

            result = ReportingUtils.trimEmptyEntries(from: result)

            let message = ReportingUtils.formatSequence(
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

            for itemIndex in 0..<ReportingUtils.Constants.monthlyProgressItemsCount {
                let monthsOffset = -itemIndex
                let referenceMonthDay = Date.today().dayByOffsetting(numberOfMonths: monthsOffset)

                let referenceMonthResult = await calculateActiveUsers(
                    fromTimestamp: referenceMonthDay.startOfMonth.timeIntervalSince1970,
                    toTimestamp: referenceMonthDay.endOfMonth.timeIntervalSince1970
                )

                result.append(referenceMonthResult)
            }

            result = ReportingUtils.trimEmptyEntries(from: result)

            let message = ReportingUtils.formatSequence(
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

    private func handlePing(withContext context: Context) {
        guard let userId = context.fromId else {
            return
        }

        bot.sendMessageAsync(
            chatId: .chat(userId),
            text: "pong"
        )
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

    // MARK: - Internal fields

    private let usersRepository: UsersRepository
    private let activitiesRepository: ActivitiesRepository
    private let bot: TelegramBot
    private let router: Router
    private let maleController: MaleController
    private let femaleController: FemaleController
    private var isRunning = false

    private enum Commands {
        static let start = "start"

        static let totalUsersCount = "totalUsersCount"
        static let dailyActiveUsers = "dau"
        static let weeklyActiveUsers = "wau"
        static let monthlyActiveUsers = "mau"

        static let ping = "ping"
    }

    private enum Constants {
        static let productionToken = "5455319702:AAGIpKMjUdPsXW7rZOe5phxV492E5LrHnvg"
        static let stagingToken = "6163360177:AAHzaxJG8vMoZ5r85ynHDBddGkNV9i9UMEE"
    }

    private enum ButtonsIdentifiers {
        static let registerMaleUser = "registerMaleUser"
        static let registerFemaleUser = "registerFemaleUser"
    }

}
