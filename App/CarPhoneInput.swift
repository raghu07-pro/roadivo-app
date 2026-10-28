#if DEBUG
    import Observation

    /// Phone Input, as CarTV's: the car's search page asks, and PlayCarTV on the iPhone shows a sheet with the iPhone's
    /// own keyboard whose text appears in the car's field as it's typed (owner, 2026-10-26; DECISIONS 163). One for
    /// the app, shared by the car's screen and the iPhone's.
    @Observable
    @MainActor
    final class CarPhoneInput {
        struct Request: Equatable {
            /// The car field's label or what it searches.
            let title: String
            /// The iPhone keyboard's return key searches.
            let isSearch: Bool
            /// A password: the iPhone shows a secure field, the car dots.
            let isSecure: Bool
        }

        static let shared = CarPhoneInput()

        private(set) var request: Request?
        /// What's typed on the iPhone; the car's field follows it.
        var text = "" {
            didSet {
                if text != oldValue {
                    onText?(text)
                }
            }
        }

        @ObservationIgnored private var onText: ((String) -> Void)?
        @ObservationIgnored private var onSubmit: (() -> Void)?

        func begin(
            _ request: Request,
            text: String,
            onText: @escaping (String) -> Void,
            onSubmit: @escaping () -> Void
        ) {
            self.onText = nil
            self.text = text
            self.request = request
            self.onText = onText
            self.onSubmit = onSubmit
        }

        /// The iPhone keyboard's return key: the car searches, or fills the field.
        func submit() {
            let submit = onSubmit
            end()
            submit?()
        }

        /// The sheet closed, or the car's page did.
        func end() {
            request = nil
            onText = nil
            onSubmit = nil
        }
    }
#endif
