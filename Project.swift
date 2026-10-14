import ProjectDescription

// Roadivo, an IPTV / M3U and local video player for iPhone (brief: CLAUDE.md, features: Docs/PRODUCT.md).
// Never hand-edit the generated .pbxproj: change this manifest and run `tuist generate`.

// Placeholder bundle ID (DECISIONS 2): change before the first App Store Connect upload.
private let bundleID = "com.example.roadivo"
private let deploymentTarget = "17.0"
private let marketingVersion = "1.0.0"
private let buildNumber = "1"

private let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "CODE_SIGN_STYLE": "Automatic",
    "MARKETING_VERSION": .string(marketingVersion),
    "CURRENT_PROJECT_VERSION": .string(buildNumber),
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES"
]

let project = Project(
    name: "Roadivo",
    organizationName: "Roadivo",
    options: .options(
        // English plus the 10 shipped translations (DECISIONS 33).
        defaultKnownRegions: ["en", "es", "fr", "de", "it", "pt-BR", "ja", "ko", "zh-Hans", "zh-Hant", "hi"],
        developmentRegion: "en"
    ),
    packages: [
        .remote(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            requirement: .upToNextMajor(from: "1.17.0")
        )
    ],
    settings: .settings(
        base: baseSettings,
        configurations: [
            .debug(name: "Debug", xcconfig: "Config/Debug.xcconfig"),
            .release(name: "Release", xcconfig: "Config/Release.xcconfig")
        ]
    ),
    targets: [
        .target(
            name: "Roadivo",
            destinations: [.iPhone],
            product: .app,
            bundleId: bundleID,
            deploymentTargets: .iOS(deploymentTarget),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["App/**", "Core/**", "DesignSystem/**", "Features/**"],
            resources: [
                "Resources/Assets.xcassets",
                "Resources/Localizable.xcstrings",
                "Resources/InfoPlist.xcstrings",
                "Resources/PrivacyInfo.xcprivacy",
                "Resources/Fonts/Overpass-Bold.ttf",
                "Resources/Fonts/Overpass-ExtraBold.ttf",
                "Resources/Fonts/Overpass-Black.ttf",
                "Resources/Fonts/OverpassMono-SemiBold.ttf"
            ],
            dependencies: [],
            settings: .settings(base: [
                // Follows the CarPlay switch in Config/Shared.xcconfig.
                "CODE_SIGN_ENTITLEMENTS": "$(ROADIVO_CARPLAY_ENTITLEMENTS_$(ROADIVO_CARPLAY))",
                // Primary icon: AppIcon (the car on the road); AppIcon-Classic ships as an alternate,
                // set with UIApplication.setAlternateIconName("AppIcon-Classic").
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES": "AppIcon-Classic",
                "ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "YES"
            ])
        ),
        .target(
            name: "RoadivoTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "\(bundleID).tests",
            deploymentTargets: .iOS(deploymentTarget),
            infoPlist: .default,
            sources: ["Tests/UnitTests/**", "Tests/SnapshotTests/**"],
            // For the SKTestSession suite: proves the local StoreKit file loads.
            resources: ["StoreKit/Roadivo.storekit"],
            dependencies: [
                .target(name: "Roadivo"),
                .package(product: "SnapshotTesting")
            ]
        ),
        .target(
            name: "RoadivoUITests",
            destinations: [.iPhone],
            product: .uiTests,
            bundleId: "\(bundleID).uitests",
            deploymentTargets: .iOS(deploymentTarget),
            infoPlist: .default,
            sources: ["Tests/UITests/**"],
            dependencies: [.target(name: "Roadivo")]
        )
    ],
    schemes: [
        .scheme(
            name: "Roadivo",
            shared: true,
            buildAction: .buildAction(targets: ["Roadivo"]),
            testAction: .targets(
                ["RoadivoTests", "RoadivoUITests"],
                configuration: "Debug",
                options: .options(coverage: true, codeCoverageTargets: ["Roadivo"])
            ),
            // Simulator runs buy Pro from the LOCAL StoreKit file: no account,
            // no money. App Store Connect products are the owner's to create.
            runAction: .runAction(
                configuration: "Debug",
                executable: "Roadivo",
                options: .options(storeKitConfigurationPath: "StoreKit/Roadivo.storekit")
            )
        )
    ]
)
