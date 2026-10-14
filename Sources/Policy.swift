import Foundation

enum TickerPolicy {
    static let origin = "https://fc-teugn-demo.75.119.147.66.sslip.io"
    static let host = "fc-teugn-demo.75.119.147.66.sslip.io"
    static let displayURL = URL(string: origin + "/desktop-ticker/")!

    static func secureURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "https" && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
    }
    static func sameSite(_ url: URL?) -> Bool { secureURL(url) && url?.host?.lowercased() == host }
    static func bridgeSource(_ url: URL?) -> Bool {
        sameSite(url) && (url?.path == "/desktop-ticker" || url?.path == "/desktop-ticker/")
    }
    static func external(_ url: URL?) -> Bool {
        guard secureURL(url), let host = url?.host?.lowercased() else { return false }
        return sameSite(url) || host == "bfv.de" || host.hasSuffix(".bfv.de")
    }
    static func view(_ value: String?) -> String { value == "ticker" ? "ticker" : "score" }
}
