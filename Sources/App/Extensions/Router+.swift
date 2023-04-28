import Foundation
import TelegramBotSDK

extension Router {

    // MARK: - Public methods and functions

    public typealias RouteHandlingCallback = (Context) -> Void
    public func registerRoute(
        withName routeName: String,
        andHandler handler: @escaping RouteHandlingCallback
    ) {
        self[routeName, .slashRequired] = { context in
            handler(context)
            return true
        }
    }

    public typealias ButtonHandlingCallback = (Context) -> Void
    public func registerButton(
        withId buttonId: String,
        andHandler handler: @escaping ButtonHandlingCallback
    ) {
        self[.callback_query(data: buttonId)] = { context in
            handler(context)
            return true
        }
    }

}
