import ProjectDescription

/// Marks this folder as the Tuist root. No "Generate Project" scheme, so Xcode's scheme menu
/// offers only PlayCarTV, the one wired to the local StoreKit prices.
let tuist = Tuist(generationOptions: .options(includeGenerateScheme: false))
