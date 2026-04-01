import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "MenuBarIcon" asset catalog image resource.
    static let menuBarIcon = DeveloperToolsSupport.ImageResource(name: "MenuBarIcon", bundle: resourceBundle)

    /// The "chatgpt" asset catalog image resource.
    static let chatgpt = DeveloperToolsSupport.ImageResource(name: "chatgpt", bundle: resourceBundle)

    /// The "claude" asset catalog image resource.
    static let claude = DeveloperToolsSupport.ImageResource(name: "claude", bundle: resourceBundle)

    /// The "duckduckgo" asset catalog image resource.
    static let duckduckgo = DeveloperToolsSupport.ImageResource(name: "duckduckgo", bundle: resourceBundle)

    /// The "gemini" asset catalog image resource.
    static let gemini = DeveloperToolsSupport.ImageResource(name: "gemini", bundle: resourceBundle)

    /// The "google" asset catalog image resource.
    static let google = DeveloperToolsSupport.ImageResource(name: "google", bundle: resourceBundle)

    /// The "kagi" asset catalog image resource.
    static let kagi = DeveloperToolsSupport.ImageResource(name: "kagi", bundle: resourceBundle)

    /// The "perplexity" asset catalog image resource.
    static let perplexity = DeveloperToolsSupport.ImageResource(name: "perplexity", bundle: resourceBundle)

}

