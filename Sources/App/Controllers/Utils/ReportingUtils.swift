import Foundation

class ReportingUtils {

    // MARK: - Public methods and properties

    public enum Constants {
        static let dailyProgressItemsCount = 10
        static let weeklyProgressItemsCount = 10
        static let monthlyProgressItemsCount = 10
        static let daysPerWeek = 7
    }

    public static func trimEmptyEntries(
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

    public static func formatSequence(
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

}
