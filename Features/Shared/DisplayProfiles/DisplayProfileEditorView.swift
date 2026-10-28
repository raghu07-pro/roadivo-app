import SwiftUI

/// One profile: the picture, playback and subtitles for a car or display, or This iPhone's defaults.
/// Changes apply at once when that screen is connected.
struct DisplayProfileEditorView: View {
    /// Kept in `@State`: the parent hands over a new one on every redraw, and only the first is kept.
    @State var viewModel: DisplayProfileEditorViewModel
    let isPro: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    var body: some View {
        @Bindable var viewModel = viewModel
        let receiver = viewModel.profile.receiver
        // A list like Settings' other pages; a Form's section headers didn't grow with Dynamic Type.
        List {
            if let receiver {
                Section {
                    // Labelled, as the Screen row under it: on its own the name didn't read as editable.
                    LabeledContent("Name") {
                        TextField("Name", text: $viewModel.name)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("profile.name")
                    }
                    LabeledContent("Screen") {
                        // "CarPlay · CarPlay" says nothing twice: iOS names every car after its kind.
                        let kind = String(appLocalized: receiver.kind.title)
                        Text(receiver.name == kind ? kind : "\(receiver.name) · \(kind)")
                    }
                } footer: {
                    if receiver.kind == .carPlay {
                        SectionFooter(
                            "iOS calls every car “CarPlay”, so this profile is used in any car connected with CarPlay."
                        )
                    }
                }
            }
            Section {
                Picker("Aspect Ratio", selection: $viewModel.aspect) {
                    ForEach(VideoAspect.allCases, id: \.self) { aspect in
                        Text(app: aspect.title).tag(aspect)
                    }
                }
                // Rows with a checkmark: a segmented control's labels stop growing at large text sizes.
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("profile.aspect")
            } header: {
                SectionHeader("Picture")
            } footer: {
                SectionFooter("""
                Fit shows the whole picture. Fill crops it to cover the screen. Stretch fills the screen \
                without cropping.
                """)
            }
            Section {
                Toggle("Play Next Automatically", isOn: $viewModel.playsNextAutomatically)
                    .accessibilityIdentifier("profile.playsNext")
                if receiver != nil {
                    Picker("Preferred Source", selection: $viewModel.preferredSourceID) {
                        Text("Any Source").tag(UUID?.none)
                        ForEach(viewModel.sources) { source in
                            Text(source.name).tag(UUID?.some(source.id))
                        }
                    }
                    .accessibilityIdentifier("profile.source")
                    Toggle(isOn: $viewModel.opensCarMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open Car Mode When Connected")
                            if !isPro {
                                Text("Included with PlayCarTV Pro").font(Typography.caption).foregroundStyle(.roadMuted)
                            }
                        }
                    }
                    .disabled(!isPro)
                    .accessibilityIdentifier("profile.carMode")
                }
            } header: {
                SectionHeader("Playback")
            } footer: {
                if receiver != nil {
                    SectionFooter("""
                    When \(viewModel.title) connects, Home switches to the preferred source, and Car Mode \
                    opens if something is playing.
                    """)
                }
            }
            Section {
                Picker("Subtitles", selection: $viewModel.subtitleSetting) {
                    Text("Automatic").tag(DisplayProfileEditorViewModel.SubtitleSetting.automatic)
                    Text("Off").tag(DisplayProfileEditorViewModel.SubtitleSetting.off)
                    Text("On").tag(DisplayProfileEditorViewModel.SubtitleSetting.on)
                }
                .accessibilityIdentifier("profile.subtitles")
                if viewModel.subtitleSetting == .on {
                    Picker("Language", selection: $viewModel.subtitleLanguage) {
                        ForEach(viewModel.subtitleLanguages, id: \.self) { code in
                            Text(Self.languageName(code)).tag(code)
                        }
                    }
                    .accessibilityIdentifier("profile.subtitleLanguage")
                }
            } header: {
                SectionHeader("Subtitles")
            } footer: {
                SectionFooter("""
                Automatic follows Subtitles & Captioning in your iPhone's Accessibility settings. On shows \
                this language when the video has it, otherwise its first subtitles.
                """)
            }
            if receiver != nil {
                Section {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Text("Delete Profile")
                    }
                    .accessibilityIdentifier("profile.delete")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle(receiver == nil ? String(appLocalized: "This iPhone") : viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.loadSources() }
        .alert(Text("Delete \(viewModel.title)?"), isPresented: $isConfirmingDelete) {
            Button("Delete Profile", role: .destructive) {
                viewModel.delete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("When it connects again, PlayCarTV uses This iPhone's settings.")
        }
    }

    /// "English", "日本語"… in the app's language.
    private static func languageName(_ code: String) -> String {
        let locale = AppLanguage.shared.locale
        return locale.localizedString(forLanguageCode: code)?.capitalized(with: locale) ?? code
    }
}
