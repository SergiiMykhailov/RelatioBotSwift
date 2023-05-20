import Foundation
import TelegramBotSDK
import Logging

final class FemaleController {

    // MARK: - Public methods and properties

    public init(
        withBot bot: TelegramBot,
        router: Router,
        usersRepository: UsersRepository
    ) {
        self.bot = bot
        self.router = router
        self.usersRepository = usersRepository

        setupButtons()
        setupDailyHandlers()
    }

    public func run() {
        if isRunning {
            return
        }

        isRunning = true

        setupActivities()
    }

    // MARK: - Internal methods

    private func setupButtons() {

    }

    private func setupActivities() {
        Logger.log("FemaleController: Setting up activities")

        morningSetupTask = ScheduledTask(
            schedule: Schedule(
                time: DateComponents(hour: 8),
                repeatType: .daily
            ),
            taskBlock: { [weak self] in
                self?.handleMorningSetup()
            }
        )
        morningSetupTask?.start()

        eveningSurveyTask = ScheduledTask(
            schedule: Schedule(
                time: DateComponents(hour: 18),
                repeatType: .daily
            ),
            taskBlock: { [weak self] in
                self?.handleEveningSurvey()()
            }
        )
        eveningSurveyTask?.start()
    }

    private func setupDailyHandlers() {
        dailyRoutinesMap.removeAll()

        dailyRoutinesMap[.sunday] = FemaleDailyRoutine(
            withMorningSetupMessage: Constants.selfEstimateSundayMessage,
            eveningHandler: { [weak self] userId in
                self?.startSundaySurvey(ofUserWithId: userId)
            }
        )
        dailyRoutinesMap[.monday] = FemaleDailyRoutine(
            withMorningSetupMessage: Constants.selfEstimateMondayMessage,
            eveningHandler: { [weak self] userId in
                self?.startMondaySurvey(ofUserWithId: userId)
            }
        )
        dailyRoutinesMap[.tuesday] = FemaleDailyRoutine(
            withMorningSetupMessage: Constants.selfEstimateTuesdayMessage,
            eveningHandler: { [weak self] userId in
                self?.startTuesdaySurvey(ofUserWithId: userId)
            }
        )
        dailyRoutinesMap[.wednesday] = FemaleDailyRoutine(
            withMorningSetupMessage: Constants.selfEstimateWednesdayMessage,
            eveningHandler: { [weak self] userId in
                self?.startWednesdaySurvey(ofUserWithId: userId)
            }
        )
        dailyRoutinesMap[.thursday] = FemaleDailyRoutine(
            withMorningSetupMessage: Constants.selfEstimateThursdayMessage,
            eveningHandler: { [weak self] userId in
                self?.startThursdaySurvey(ofUserWithId: userId)
            }
        )
        dailyRoutinesMap[.friday] = FemaleDailyRoutine(
            withMorningSetupMessage: Constants.selfEstimateFridayMessage,
            eveningHandler: { [weak self] userId in
                self?.startFridaySurvey(ofUserWithId: userId)
            }
        )
        dailyRoutinesMap[.saturday] = FemaleDailyRoutine(
            withMorningSetupMessage: Constants.selfEstimateSaturdayMessage,
            eveningHandler: { [weak self] userId in
                self?.startSaturdaySurvey(ofUserWithId: userId)
            }
        )
    }

    private static func makeSurveyOf5Replies(
        withMessage message: String
    ) -> EveningActivityInfo {
        return EveningActivityInfo(
            message: message,
            buttons: [
                SurveyButtonInfo(text: "❤️"),
                SurveyButtonInfo(text: "❤️❤️"),
                SurveyButtonInfo(text: "❤️❤️❤️"),
                SurveyButtonInfo(text: "❤️❤️❤️❤️"),
                SurveyButtonInfo(text: "❤️❤️❤️❤️❤️")
            ]
        )
    }

    private func startSundaySurvey(ofUserWithId userId: Int64) {
        let eveningActivitySurvey = type(of: self).makeSurveyOf5Replies(
            withMessage: Constants.selfEstimateSundaySurvey
        )

        askAboutActivity(
            ofUserWithId: userId,
            eveneningActivity: eveningActivitySurvey
        )
    }

    private func startMondaySurvey(ofUserWithId userId: Int64) {
        let eveningActivitySurvey = type(of: self).makeSurveyOf5Replies(
            withMessage: Constants.selfEstimateMondaySurvey
        )

        askAboutActivity(
            ofUserWithId: userId,
            eveneningActivity: eveningActivitySurvey
        )
    }

    private func startTuesdaySurvey(ofUserWithId userId: Int64) {
        let eveningActivitySurvey = type(of: self).makeSurveyOf5Replies(
            withMessage: Constants.selfEstimateTuesdaySurvey
        )

        askAboutActivity(
            ofUserWithId: userId,
            eveneningActivity: eveningActivitySurvey
        )
    }

    private func startWednesdaySurvey(ofUserWithId userId: Int64) {
        let eveningActivitySurvey = type(of: self).makeSurveyOf5Replies(
            withMessage: Constants.selfEstimateWednesdaySurvey
        )

        askAboutActivity(
            ofUserWithId: userId,
            eveneningActivity: eveningActivitySurvey
        )
    }

    private func startThursdaySurvey(ofUserWithId userId: Int64) {
        let eveningActivitySurvey = type(of: self).makeSurveyOf5Replies(
            withMessage: Constants.selfEstimateThursdaySurvey
        )

        askAboutActivity(
            ofUserWithId: userId,
            eveneningActivity: eveningActivitySurvey
        )
    }

    private func startFridaySurvey(ofUserWithId userId: Int64) {
        let eveningActivitySurvey = EveningActivityInfo(
            message: Constants.selfEstimateFridaySurvey,
            buttons: [
                SurveyButtonInfo(text: "Да"),
                SurveyButtonInfo(text: "Нет"),
                SurveyButtonInfo(text: "Покинула место")
            ]
        )

        askAboutActivity(
            ofUserWithId: userId,
            eveneningActivity: eveningActivitySurvey
        )
    }

    private func startSaturdaySurvey(ofUserWithId userId: Int64) {
        let eveningActivitySurvey = EveningActivityInfo(
            message: Constants.selfEstimateSaturdaySurvey,
            buttons: [
                SurveyButtonInfo(text: "Встретились"),
                SurveyButtonInfo(text: "Не было таких")
            ]
        )

        askAboutActivity(
            ofUserWithId: userId,
            eveneningActivity: eveningActivitySurvey
        )
    }

    private func askAboutActivity(
        ofUserWithId userId: Int64,
        eveneningActivity: EveningActivityInfo
    ) {
        var keyboardButtons = [InlineKeyboardButton]()

        for button in eveneningActivity.buttons {
            keyboardButtons.append(
                InlineKeyboardButton(
                    text: button.text,
                    callbackData: button.commandId
                )
            )
        }

        let markup = InlineKeyboardMarkup(
            inlineKeyboard: [keyboardButtons]
        )

        bot.sendMessageAsync(
            chatId: .chat(userId),
            text: eveneningActivity.message,
            replyMarkup: ReplyMarkup.inlineKeyboardMarkup(markup)
        )
    }

    typealias ForeachUserCallback = (Int64) -> Void
    private func foreachUser(do action: @escaping ForeachUserCallback) {
        _Concurrency.Task {
            let registeredUsers = await usersRepository.loadUsers()

            for user in registeredUsers {
                if user.gender == .female, let chatId = Int64(user.id) {
                    action(chatId)
                }
            }
        }
    }

    // MARK: - Routine

    private func handleMorningSetup() {
        Logger.log("FemaleController: handling morning setup")

        guard let today = Date().dayOfWeek,
              let todayRoutine = dailyRoutinesMap[today] else {
            return
        }

        foreachUser { [weak self] userId in
            Logger.log("MaleController: handling morning setup for user (\(userId)")

            self?.bot.sendMessageAsync(
                chatId: .chat(userId),
                text: todayRoutine.morningSetupMessage
            )
        }
    }

    private func handleEveningSurvey() {
        Logger.log("FemaleController: handling evening survey")

        guard let today = Date().dayOfWeek else {
            return
        }

        let todayRoutine = dailyRoutinesMap[today]

        foreachUser { userId in
            Logger.log("FemaleController: handling evening survey for user (\(userId)")

            todayRoutine?.eveningHandler(userId)
        }
    }

    // MARK: - Internal fields

    private let bot: TelegramBot
    private let router: Router
    private let usersRepository: UsersRepository

    private var isRunning = false

    var morningSetupTask: ScheduledTask?
    var eveningSurveyTask: ScheduledTask?

    private var dailyRoutinesMap = [DayOfWeek : FemaleDailyRoutine]()

    private enum Constants {
        static let dailyActivityScore = 1
        static let weeklyActivityScore = 5
        static let monthlyActivityScore = 15
        static let heroActivityScore = 50

        static let selfEstimateSundayMessage = "Тема: развитие самооценки.\n\nЯ думаю о себе, о том как сделать себя счастливой.\n\nЖенщинам легко думать о нуждах и потребностях других, но тяжело думать о своих нуждах и потребностях, поэтому она должна думать о том , как сделать себя более счастливой.\nВсё, что с женщиной происходит, она этим поделится с другими, если у меня будет плохое настроение то я буду делится своим плохим настроением с другими, если я буду счастливой, то я поделюсь этим счастьем с окружающими.\n\nПоэтому думай в первую очередь о своём счастье, как сделать себя счастливой."
        static let selfEstimateSundaySurvey = "О ком ты больше думала, о себе или о других? Оцени..."

        static let selfEstimateMondayMessage = "Тема: развитие самооценки.\n\nЯ разрешаю себе желать и озвучивать свои желания.\n\nЯ достойна чтобы все мои желания осуществлялись, озвучивай свои желания сразу, после того как они появились, не жди подходящего момента, места или времени \"Я хочу...\". Если ты сама то озвучивай свои желания Богу вселенной и они будут исполнятся. Не жди что родные и близкие должны догадаться или угадать твои желания, не намекай, а говори прямо \"Я хочу...\", \"Я была бы очень рада, если бы...\", \"Я была бы очень счастлива, если бы...\", \"Я была бы очень рада если бы...\". Если ты сама, то начни удовлетворять свои желания по мере возможности, и Вселенная начнёт расширять твои возможности.\n\nПойди в театр, на массаж, в кино с подружками, сделай новую причёску или макияж, спа-процедуры, съезди на природу в лес, пройдись по магазинам, купи себе цветы и т.д."
        static let selfEstimateMondaySurvey = "Сколько раз ты отказала себе в своих желаниях и сколько раз ты разрешила себе желать и озвучить своё желание? Как ощущения?"

        static let selfEstimateTuesdayMessage = "Тема: развитие самооценки.\n\nЯ достойна получить всё что я хочу, просто так.\n\nНе сравнивай себя с другими, у всех есть свои слабые и сильные стороны, но ты уникальная, единственная и неповторимая, ты достойна быть счастливой, второй такой нет.\nЖенщину наполняют и делают удовлетворённой, те вещи и поступки окружающих по отношению к ней, которые она получает просто так, а не когда она заслуживает или зарабатывает их, поэтому учись принимать ухаживание, заботу, знаки внимания, подарки, комплименты и т.д. просто так, потому что ты уникальная и неповторимая.\n\nВыпиши свои достоинства и вспоминай о них, не верь тем, кто говорит о твоих недостатках, они просто хотят причинить тебе боль, не разрешай им этого сделать, то что они называют твоими недостатками - это просто \"ты другая\""
        static let selfEstimateTuesdaySurvey = "Вспоминала ли ты о своих достоинствах сегодня? Думала ли о своих недостатках? Тебе понравилось?"

        static let selfEstimateWednesdayMessage = "Тема: развитие самооценки.\n\nОбо мне всегда есть кому позаботиться.\n\nЖенщина всегда должна находится под защитой отца, мужа или взрослого сына, если же таковых нет или они о тебе не заботятся, то о тебе позаботиться Бог, мать Земля, Вселенная, доверься им. Женщина должна следить за своим эмоциональным состоянием, если тебе плохо или что-то не нравится или даже просто грустно, озвучь своё состояние и получи поддержку. Поэтому начни доверять Вселенной и получи новый опыт, ты не одна, ты достойна чтобы о тебе позаботились."
        static let selfEstimateWednesdaySurvey = "Получилось ли у тебя сегодня доверять другим людям и миру в целом? Оцени..."

        static let selfEstimateThursdayMessage = "Тема: развитие самооценки.\n\nЯ разрешаю себе отказывать другим и не чувствовать себя при этом виноватой.\n\nЕсли Женщина делает вещи которые не хочет (из страха, из дефицита, или чувства вины), то она опустошается, разочаровывается, становиться неудовлетворённой, резкой и грубой, и не кому от этого не будет хорошо. Скажи: \"Нет\"; \"Не хочу\"; \"Не буду\"\n\nДля этого возьми паузу чтобы подумать, оцени ситуацию \"Хочу...\" или \"Не хочу...\" и озвучь своё решение, не чувствуй себя виноватой, потому-что ты отказала ради блага всех."
        static let selfEstimateThursdaySurvey = "Сколько раз ты сказала \"нет\"? Чувствовала ли ты вину? Оцени..."

        static let selfEstimateFridayMessage = "Тема: развитие самооценки.\n\nИзбегайте общества людей которые вам завидуют, критикуют, оскорбляют, унижают, манипулируют Вами или эксплуатируют Вас, даже если это Ваши родные и близкие.\n\nВы не обязаны терпеть к себе такое отношение и не обязаны общаться с этими людьми. Если вы вынуждены общаться с такими людьми то не позволяйте вас оскорблять, унижать, критиковать и т.д. Остановите их сразу: \"Стоп\"; \"Мне не нравиться когда со мной разговаривают в таком тоне\"; \"Мне очень больно слышать эти вещи\"; и сразу удалитесь с этого места, или положите трубку."
        static let selfEstimateFridaySurvey = "Получилось ли у тебя остановить проявления неуважения к себе?"

        static let selfEstimateSaturdayMessage = "Тема: развитие самооценки.\n\nИщите общество людей, которые Вас уважают, ценят, заботятся о Вас, дарят Вам подарки и комплименты, поддерживают Вас, и любят Вас просто так.\n\nБудьте благодарны этим людям и дорожите их обществом, и помните, Вы достойны быть счастливой."
        static let selfEstimateSaturdaySurvey = "Встретились ли сегодня на Вашем пути люди, которые были добры к Вам, заботились о Вас, проявляли интерес к вам? Дайте им знать, что для Вас это ценно."
    }

    private struct FemaleDailyRoutine {
        let morningSetupMessage: String
        let eveningHandler: ForeachUserCallback

        init(
            withMorningSetupMessage morningSetupMessage: String,
            eveningHandler: @escaping ForeachUserCallback
        ) {
            self.morningSetupMessage = morningSetupMessage
            self.eveningHandler = eveningHandler
        }
    }

    private struct SurveyButtonInfo {
        let text: String
        let commandId: String? = nil
    }

    private struct EveningActivityInfo {
        let message: String
        let buttons: [SurveyButtonInfo]
    }
}
