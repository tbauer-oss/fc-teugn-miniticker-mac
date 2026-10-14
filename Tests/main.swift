import Foundation

var checks = 0
func check(_ value: Bool, _ description: String) {
    guard value else { fatalError(description) }; checks += 1
}
check(TickerPolicy.sameSite(TickerPolicy.displayURL), "Own HTTPS display must load")
check(TickerPolicy.bridgeSource(TickerPolicy.displayURL), "Own display must send bridge messages")
for path in ["/", "/redaktion", "/desktop-ticker/fake", "/desktop-ticker/index.html"] {
    check(!TickerPolicy.bridgeSource(URL(string: TickerPolicy.origin + path)), "Bridge must be exact: \(path)")
}
for value in ["http://\(TickerPolicy.host)/desktop-ticker/", "https://\(TickerPolicy.host).evil.invalid/desktop-ticker/", "https://\(TickerPolicy.host):444/desktop-ticker/", "https://user@\(TickerPolicy.host)/desktop-ticker/", "file:///desktop-ticker/", "javascript:alert(1)"] {
    check(!TickerPolicy.sameSite(URL(string: value)), "Unexpected main navigation must be blocked")
    check(!TickerPolicy.bridgeSource(URL(string: value)), "Unexpected bridge source must be blocked")
}
for value in ["https://www.bfv.de/", "https://widget-prod.bfv.de/", TickerPolicy.origin] {
    check(TickerPolicy.external(URL(string: value)), "Allowed external link: \(value)")
}
for value in ["https://bfv.de.evil.invalid", "https://evilbfv.de", "https://www.bfv.de:444", "https://user@www.bfv.de", "http://www.bfv.de", "file:///tmp/file"] {
    check(!TickerPolicy.external(URL(string: value)), "Unsafe external link must be blocked")
}
check(TickerPolicy.view(nil) == "score", "Default view")
check(TickerPolicy.view("unexpected") == "score", "Invalid preference")
check(TickerPolicy.view("ticker") == "ticker", "Full ticker")
print("\(checks) Mac policy checks passed.")
