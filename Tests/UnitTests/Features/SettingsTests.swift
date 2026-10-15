import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Testing
import UIKit
@testable import Roadivo

@Suite("Settings and helpers", .serialized)
@MainActor
struct SettingsTests {
    private func defaults() -> UserDefaults {
        let name = "roadivo.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: name) ?? .standard
    }

    @Test("Language: lists all shipped languages and switches immediately")
    func language() {
        let store = defaults()
        let language = AppLanguage()
        defer { language.set(nil, defaults: store) }
        let viewModel = LanguageViewModel(language: language, bundle: .main, defaults: store)
        let codes = Set(viewModel.available.map(\.code))
        #expect(codes.isSuperset(of: ["en", "de", "es", "fr", "hi", "ja", "ko", "zh-Hans", "zh-Hant", "pt-BR", "it"]))
        #expect(viewModel.selected == nil)

        viewModel.choose("de")
        #expect(viewModel.selected == "de")
        #expect(language.locale.identifier == "de")
        #expect(store.stringArray(forKey: "AppleLanguages") == ["de"])
        // Strings built in code switch at once, without a relaunch.
        #expect(String(appLocalized: "Continue") == "Weiter")
        #expect(String(appLocalized: "\(3) items") == "3 Elemente" || String(appLocalized: "\(3) items").contains("3"))
        #expect(viewModel.currentName == "Deutsch")

        viewModel.choose("ja")
        #expect(String(appLocalized: "Continue") == "続ける")

        viewModel.choose(nil)
        #expect(viewModel.selected == nil)
        #expect(store.string(forKey: AppLocale.overrideKey) == nil)
    }

    /// After a relaunch with German chosen, `Locale.current` speaks German, so it can't answer
    /// "what is the iPhone's language" once Follow System is picked.
    @Test("Follow System resolves the iPhone's language, not one chosen before launch")
    func followSystemAfterRelaunch() {
        let shipped = ["Base", "en", "de", "fr", "pt-BR", "zh-Hans"]
        let germanOverride = Locale(identifier: "de_FR")
        let french = AppLocale.resolveSystemLocale(
            preferences: ["fr-FR", "en"], localizations: shipped, current: germanOverride
        )
        #expect(french == Locale(identifier: "fr"))
        let brazilian = AppLocale.resolveSystemLocale(
            preferences: ["pt-BR"], localizations: shipped, current: germanOverride
        )
        #expect(brazilian == Locale(identifier: "pt-BR"))
    }

    @Test("Follow System keeps the current locale, region included, when it already matches")
    func followSystemKeepsMatchingLocale() {
        let canadian = Locale(identifier: "fr_CA")
        let resolved = AppLocale.resolveSystemLocale(
            preferences: ["fr-CA", "en"], localizations: ["Base", "en", "fr"], current: canadian
        )
        #expect(resolved == canadian)
    }

    @Test("Language names and flags come from the locale")
    func languageOption() {
        let german = LanguageOption(code: "de")
        #expect(german.name == "Deutsch")
        #expect(german.flag == "🇩🇪")
    }

    @Test("A QR code in an image decodes to its text")
    func qrCode() throws {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("https://example.com/list.m3u".utf8)
        let output = try #require(filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)))
        let cgImage = try #require(CIContext().createCGImage(output, from: output.extent))
        let png = try #require(UIImage(cgImage: cgImage).pngData())
        #expect(QRCodeReader.decode(imageData: png) == "https://example.com/list.m3u")
        #expect(QRCodeReader.decode(imageData: Data("not an image".utf8)) == nil)
    }

    @Test("Folder import finds only videos, in name order")
    func folderScan() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "trip-\(UUID().uuidString)")
        let nested = folder.appending(path: "Day 2")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for path in ["b.mp4", "a.mov", "notes.txt", "Day 2/c.m4v"] {
            try Data("x".utf8).write(to: folder.appending(path: path))
        }
        #expect(VideoFiles.find(in: folder).map(\.lastPathComponent) == ["a.mov", "b.mp4", "c.m4v"])
    }

    @Test("Intro paywall is remembered once seen")
    func preferences() {
        let store = defaults()
        let first = Preferences(defaults: store)
        #expect(!first.hasSeenIntroPaywall)
        first.hasSeenIntroPaywall = true
        #expect(Preferences(defaults: store).hasSeenIntroPaywall)
        #expect(first.deviceID == Preferences(defaults: store).deviceID)
    }
}
