import Foundation
import Logging

extension Logger {

    // MARK: - Public methods and properties

    public static func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: Date())

        let logger = Logger(label: Constants.loggerLabel)
        logger.info("\(dateString): \(message)")
    }

    // MARK: - Internal fields

    private enum Constants {
        static let loggerLabel = "relatio-bot"
    }

}
