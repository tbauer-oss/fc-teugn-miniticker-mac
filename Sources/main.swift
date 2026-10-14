import AppKit
import WebKit

final class TickerApp: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, NSMenuItemValidation {
    private var window: NSWindow!
    private var web: WKWebView!
    private var statusItem: NSStatusItem!
    private var modeControl: NSSegmentedControl!
    private var pinButton: NSButton!
    private var statusText: NSTextField!
    private var timer: Timer?
    private let defaults: UserDefaults = {
        #if CI_SMOKE_TEST
        return UserDefaults(suiteName: "de.fc-teugn.miniticker.smoke.\(UUID().uuidString)")!
        #else
        return .standard
        #endif
    }()
    private var ready = false
    private var failed = false
    private var refreshing = false
    private var quitting = false
    private var nextRefresh = Date().addingTimeInterval(300)
    #if CI_SMOKE_TEST
    private var smokePhase = "fixture"
    #endif
    private var selectedView: String { TickerPolicy.view(defaults.string(forKey: "view")) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["view": "score", "alwaysOnTop": true, "closeToMenu": true])
        createMenu()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.add(self, name: "fctNative")
        // Compatibility bridge for the existing first-party Windows display. Only
        // main-frame messages from the exact trusted display route are accepted below.
        configuration.userContentController.addUserScript(WKUserScript(source: """
          if (location.origin === '\(TickerPolicy.origin)' && location.pathname === '/desktop-ticker/') {
            window.chrome = {webview: {postMessage: message => window.webkit.messageHandlers.fctNative.postMessage(message)}};
          }
          """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = false
        web.allowsLinkPreview = false

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "FC Teugn · Miniticker"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 155)
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.level = defaults.bool(forKey: "alwaysOnTop") ? .floating : .normal
        window.setFrameAutosaveName("FCTeugnTickerWindow")
        if !window.setFrameUsingName("FCTeugnTickerWindow") { window.center() }

        let root = NSView()
        window.contentView = root
        modeControl = NSSegmentedControl(labels: ["Ergebnis", "Ticker"], trackingMode: .selectOne, target: self, action: #selector(modeChanged))
        modeControl.setAccessibilityLabel("Tickeransicht")
        modeControl.isEnabled = false
        pinButton = NSButton(checkboxWithTitle: "Vorn", target: self, action: #selector(togglePin))
        pinButton.toolTip = "Immer im Vordergrund"
        pinButton.state = defaults.bool(forKey: "alwaysOnTop") ? .on : .off
        let reload = NSButton(title: "↻", target: self, action: #selector(reconnect))
        reload.setAccessibilityLabel("Neu verbinden")
        let hide = NSButton(title: "−", target: self, action: #selector(hideWindow))
        hide.setAccessibilityLabel("In der Menüleiste weiterlaufen")
        let bar = NSStackView(views: [modeControl, pinButton, reload, hide])
        bar.orientation = .horizontal
        bar.spacing = 7
        bar.distribution = .fill
        statusText = NSTextField(wrappingLabelWithString: "")
        statusText.alignment = .center
        statusText.font = .systemFont(ofSize: 13)
        statusText.isHidden = true
        for view in [bar, web!, statusText!] as [NSView] { view.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(view) }
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 7),
            bar.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -7),
            bar.topAnchor.constraint(equalTo: root.topAnchor, constant: 5), bar.heightAnchor.constraint(equalToConstant: 26),
            web.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 5), web.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            web.leadingAnchor.constraint(equalTo: root.leadingAnchor), web.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            statusText.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16), statusText.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            statusText.centerYAnchor.constraint(equalTo: web.centerYAnchor)
        ])
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sportscourt.fill", accessibilityDescription: "FC Teugn Miniticker")
        statusItem.button?.toolTip = "FC Teugn · Miniticker"
        statusItem.menu = tickerMenu()
        clampWindow()
        #if CI_SMOKE_TEST
        smokeTest()
        return
        #endif
        showWindow()
        reconnect()
        timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.heartbeat() }
        RunLoop.main.add(timer!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wokeUp), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func createMenu() {
        let menu = NSMenu()
        let appMenu = NSMenuItem()
        appMenu.submenu = tickerMenu()
        menu.addItem(appMenu)
        let edit = NSMenuItem(title: "Bearbeiten", action: nil, keyEquivalent: "")
        edit.submenu = NSMenu(title: "Bearbeiten")
        for (title, action, key) in [("Ausschneiden", "cut:", "x"), ("Kopieren", "copy:", "c"), ("Einfügen", "paste:", "v"), ("Alles auswählen", "selectAll:", "a")] {
            edit.submenu?.addItem(NSMenuItem(title: title, action: Selector(action), keyEquivalent: key))
        }
        menu.addItem(edit)
        NSApplication.shared.mainMenu = menu
    }
    #if CI_SMOKE_TEST
    private func smokeTest() {
        // In-process integration test, not remote desktop automation. The test
        // executable uses isolated preferences and never receives authentication data.
        precondition(window.level == .floating)
        precondition(pinButton.state == .on)
        precondition(!modeControl.isEnabled)
        precondition(window.contentView!.subviews.count == 3)
        precondition(statusItem.menu!.items.count >= 9)
        togglePin(); precondition(window.level == .normal && pinButton.state == .off)
        togglePin(); precondition(window.level == .floating && pinButton.state == .on)
        toggleClose(); precondition(!defaults.bool(forKey: "closeToMenu"))
        toggleClose(); precondition(defaults.bool(forKey: "closeToMenu"))
        modeControl.selectedSegment = 1; modeChanged(); precondition(selectedView == "ticker")
        modeControl.selectedSegment = 0; modeChanged(); precondition(selectedView == "score")
        connectionFailed(); precondition(!statusText.isHidden && web.isHidden && failed)
        web.isHidden = false; statusText.isHidden = true
        window.makeKeyAndOrderFront(nil)
        web.loadHTMLString("<!doctype html><meta charset=utf-8><p id=fixture>Mac-WebKit-Test</p>", baseURL: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { fatalError("Mac WebKit/login smoke test timed out") }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard smokePhase == "fixture" else { return }
        webView.evaluateJavaScript("document.getElementById('fixture').textContent") { value, error in
            precondition(error == nil && value as? String == "Mac-WebKit-Test")
            print("Native Mac window, menu, topmost, controls, error state and WebKit startup passed.")
            fflush(stdout)
            self.smokePhase = "login"
            self.reconnect()
        }
    }
    #endif
    private func tickerMenu() -> NSMenu {
        let menu = NSMenu(title: "FC Teugn Miniticker")
        func item(_ title: String, _ action: Selector, _ key: String = "") {
            let value = NSMenuItem(title: title, action: action, keyEquivalent: key); value.target = self; menu.addItem(value)
        }
        item("Miniticker anzeigen", #selector(showWindow))
        item("Nur Ergebnis & Wappen", #selector(scoreView))
        item("Ergebnis & Tickertexte", #selector(tickerView))
        item("Immer im Vordergrund", #selector(togglePin))
        item("Beim Schließen in der Menüleiste weiterlaufen", #selector(toggleClose))
        menu.addItem(.separator())
        item("Neu verbinden", #selector(reconnect), "r")
        item("Vereinswebsite öffnen", #selector(openWebsite))
        item("Über den Miniticker", #selector(about))
        menu.addItem(.separator())
        item("Miniticker beenden", #selector(quit), "q")
        return menu
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePin) { menuItem.state = defaults.bool(forKey: "alwaysOnTop") ? .on : .off }
        if menuItem.action == #selector(toggleClose) { menuItem.state = defaults.bool(forKey: "closeToMenu") ? .on : .off }
        if menuItem.action == #selector(scoreView) { menuItem.state = selectedView == "score" ? .on : .off }
        if menuItem.action == #selector(tickerView) { menuItem.state = selectedView == "ticker" ? .on : .off }
        return true
    }
    @objc private func showWindow() { window?.makeKeyAndOrderFront(nil); NSApplication.shared.activate(ignoringOtherApps: true); clampWindow() }
    @objc private func hideWindow() { window.orderOut(nil) }
    @objc private func togglePin() {
        let value = !defaults.bool(forKey: "alwaysOnTop")
        defaults.set(value, forKey: "alwaysOnTop"); window.level = value ? .floating : .normal; pinButton.state = value ? .on : .off
    }
    @objc private func toggleClose() { defaults.set(!defaults.bool(forKey: "closeToMenu"), forKey: "closeToMenu") }
    @objc private func modeChanged() { setView(modeControl.selectedSegment == 1 ? "ticker" : "score") }
    @objc private func scoreView() { setView("score"); showWindow() }
    @objc private func tickerView() { setView("ticker"); showWindow() }
    private func setView(_ view: String) {
        let value = TickerPolicy.view(view); defaults.set(value, forKey: "view"); modeControl.selectedSegment = value == "ticker" ? 1 : 0
        guard ready, TickerPolicy.bridgeSource(web.url) else { return }
        web.evaluateJavaScript("window.fctDesktop?.setView('\(value)')", completionHandler: nil)
        window.setContentSize(value == "score" ? NSSize(width: 320, height: 139) : NSSize(width: 400, height: 600)); clampWindow()
    }
    @objc private func reconnect() {
        guard web != nil else { return }
        ready = false; failed = false; statusText.isHidden = true; web.isHidden = false; modeControl.isEnabled = false
        nextRefresh = Date().addingTimeInterval(300)
        web.load(URLRequest(url: TickerPolicy.displayURL))
    }
    private func heartbeat() {
        guard Date() >= nextRefresh else { return }
        if failed { reconnect(); return }
        guard ready, !refreshing, TickerPolicy.bridgeSource(web.url) else { return }
        refreshing = true; nextRefresh = Date().addingTimeInterval(300)
        web.evaluateJavaScript("window.fctDesktop?.refresh()") { [weak self] _, error in
            self?.refreshing = false
            if error != nil { self?.connectionFailed() }
        }
    }
    @objc private func wokeUp() { nextRefresh = .distantPast; heartbeat() }
    @objc private func screenChanged() { clampWindow() }
    private func clampWindow() {
        guard let window else { return }
        let rect = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        var frame = window.frame
        frame.size.width = min(frame.width, rect.width); frame.size.height = min(frame.height, rect.height)
        frame.origin.x = max(rect.minX, min(frame.minX, rect.maxX - frame.width))
        frame.origin.y = max(rect.minY, min(frame.minY, rect.maxY - frame.height))
        window.setFrame(frame, display: true)
    }
    private func connectionFailed() {
        ready = false; failed = true; refreshing = false; modeControl.isEnabled = false
        web.isHidden = true; statusText.stringValue = "Keine Verbindung. Neuer Versuch in einer Minute. Über ↻ kannst du direkt neu verbinden."; statusText.isHidden = false
        nextRefresh = Date().addingTimeInterval(60)
    }
    @objc private func openWebsite() { NSWorkspace.shared.open(URL(string: TickerPolicy.origin + "/#/liveticker")!) }
    @objc private func about() {
        let alert = NSAlert(); alert.messageText = "FC Teugn · Miniticker 0.1.0"
        alert.informativeText = "Mac-Testversion. Original-BFV-Widget: Ergebnis mit Wappen oder vollständiger Ticker. Der letzte Ticker kann ein beendetes Spiel sein.\n\nDas Programm muss laufen; bei schlafendem oder ausgeschaltetem Mac gibt es keine Aktualisierung. Zusätzlicher Verbindungsaufbau alle fünf Minuten.\n\nAutomatische Tor-/Ereignisbenachrichtigungen sind nicht enthalten.\n\nDesigned by Tobias Bauer"; alert.runModal()
    }
    @objc private func quit() { quitting = true; NSApplication.shared.terminate(nil) }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if !quitting && defaults.bool(forKey: "closeToMenu") { hideWindow(); return false }
        quit(); return true
    }
    func windowDidEndLiveResize(_ notification: Notification) { clampWindow() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); web.configuration.userContentController.removeScriptMessageHandler(forName: "fctNative") }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, TickerPolicy.bridgeSource(message.frameInfo.request.url),
              let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready": ready = true; failed = false; web.isHidden = false; statusText.isHidden = true; modeControl.isEnabled = true; setView(selectedView)
        case "login":
            ready = false; failed = false; statusText.isHidden = true; web.isHidden = false; modeControl.isEnabled = false
            window.setContentSize(NSSize(width: 440, height: 620)); clampWindow()
            #if CI_SMOKE_TEST
            if smokePhase == "login" {
                precondition(!ready && !web.isHidden && !modeControl.isEnabled)
                precondition(window.contentView!.bounds.width == 440)
                print("Protected demo login and trusted WebKit message bridge passed. No credentials submitted.")
                fflush(stdout)
                NSApplication.shared.terminate(nil)
            }
            #endif
        case "error": connectionFailed()
        default: break
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        #if CI_SMOKE_TEST
        if action.request.url?.absoluteString == "about:blank" { decisionHandler(.allow); return }
        #endif
        guard let url = action.request.url, !action.shouldPerformDownload else { decisionHandler(.cancel); return }
        if action.targetFrame?.isMainFrame == false { decisionHandler(url.scheme == "https" || url.absoluteString == "about:blank" ? .allow : .cancel); return }
        if action.targetFrame == nil || !TickerPolicy.sameSite(url) {
            if action.navigationType == .linkActivated && TickerPolicy.external(url) { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel); return
        }
        ready = false; modeControl.isEnabled = false; decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { connectionFailed() }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { connectionFailed() }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { connectionFailed() }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.deny) }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) { completionHandler(nil) }
}

let app = NSApplication.shared
let delegate = TickerApp()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
