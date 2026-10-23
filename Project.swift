import ProjectDescription

// Roadivo, an IPTV / M3U and local video player for iPhone (brief: CLAUDE.md, features: Docs/PRODUCT.md).
// Never hand-edit the generated .pbxproj: change this manifest and run `tuist generate`.

// Registered for D.I. Solutions (DECISIONS 2). Never change it once a build is uploaded.
private let bundleID = "com.disolutions.roadivo"
private let deploymentTarget = "17.0"
private let marketingVersion = "1.0.0"
// One higher for every upload: App Store Connect refuses a build number it has seen (1 and 2 are on TestFlight).
private let buildNumber = "3"

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
        // Only the Roadivo scheme below: an extension's own scheme has no StoreKit file and archives the wrong way.
        automaticSchemesOptions: .disabled,
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
                "Resources/Fonts/OverpassMono-SemiBold.ttf",
                // The privacy page: the one file hosted for the App Store is also shown in the app.
                "Docs/Website/roadivo.html"
            ],
            // Screen Broadcast: Apple's screen recording, streamed to a car screen's browser (DECISIONS 124).
            dependencies: [.target(name: "RoadivoBroadcast")],
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
            name: "RoadivoBroadcast",
            destinations: [.iPhone],
            product: .appExtension,
            bundleId: "\(bundleID).broadcast",
            deploymentTargets: .iOS(deploymentTarget),
            infoPlist: .extendingDefault(with: [
                // The name in Apple's Start Broadcast sheet.
                "CFBundleDisplayName": "Roadivo",
                // An extension's versions must match the app's, or the upload is refused.
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.broadcast-services-upload",
                    "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).SampleHandler",
                    "RPBroadcastProcessMode": "RPBroadcastProcessModeSampleBuffer"
                ]
            ]),
            sources: ["Broadcast/**", "Core/Broadcast/BroadcastHTTP.swift"],
            // The app's catalog, for the message shown when the broadcast can't start.
            resources: ["Resources/Localizable.xcstrings"],
            dependencies: [],
            // Installed inside the app only, so the archive stays an iOS App Archive Organizer can upload.
            settings: .settings(base: ["SKIP_INSTALL": "YES"])
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
                // Debug `-car-parked`: CarPlay video at a desk; moving GPS still stops it (DECISIONS 154).
                arguments: .arguments(launchArguments: [.launchArgument(name: "-car-parked", isEnabled: true)]),
                options: .options(storeKitConfigurationPath: "StoreKit/Roadivo.storekit")
            )
        )
    ]
)
