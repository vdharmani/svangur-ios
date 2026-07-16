import Foundation

// Keys are injected at build time from DebugSecret.xcconfig / releaseSecret.xcconfig
// (gitignored) via Info.plist. See Svangur/Secret.xcconfig.example for setup.
enum APIKeys {
    static var googlePlaces: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String,
              !key.isEmpty else {
            fatalError("GOOGLE_PLACES_API_KEY not configured — copy Secret.xcconfig.example to DebugSecret.xcconfig / releaseSecret.xcconfig and set the key")
        }
        return key
    }
}
