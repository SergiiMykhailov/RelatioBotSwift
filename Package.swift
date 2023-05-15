// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "RelatioBot",
    platforms: [
       .macOS(.v12)
    ],
    dependencies: [
        .package(name: "TelegramBotSDK", url: "https://github.com/zmeyc/telegram-bot-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.3"),
        .package(url: "https://github.com/vapor-community/cron.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "TelegramBotSDK", package: "TelegramBotSDK"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Cron", package: "cron"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
    ]
)
