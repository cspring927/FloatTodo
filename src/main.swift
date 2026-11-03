// FloatTodo：一个浮在所有窗口上方的极简待办小窗。
// 界面在 index.html 和 settings.html 里；这个文件负责窗口、磨砂、菜单栏图标、全局快捷键、开机启动和保存数据。

import AppKit
import Carbon.HIToolbox
import QuartzCore
import WebKit

enum K {
    static let bundleID = "local.floattodo"
    static let defaultWidth: CGFloat = 280
    static let minWidth: CGFloat = 220
    static let maxWidth: CGFloat = 720
    static let initialHeight: CGFloat = 72
    static let minHeight: CGFloat = 38
    static let minFixedHeight: CGFloat = 100
    static let gripWidth: CGFloat = 7
    static let cornerRadius: CGFloat = 14
    static let margin: CGFloat = 20
    static let resizeDuration: TimeInterval = 0.16
    static let settingsWidth: CGFloat = 460
}

// MARK: - 菜单文字

enum MenuText {
    static func get(_ key: String, language: String) -> String {
        let zh = ["show": "显示窗口", "hide": "隐藏窗口", "settings": "设置…", "quit": "退出 FloatTodo", "title": "FloatTodo 设置"]
        let en = ["show": "Show Window", "hide": "Hide Window", "settings": "Settings…", "quit": "Quit FloatTodo", "title": "FloatTodo Settings"]
        return (language == "en" ? en : zh)[key] ?? key
    }
}

// MARK: - 全局快捷键

struct HotKey {
    let keyCode: UInt32
    let modifiers: UInt32
    let title: String

    init(keyCode: UInt32, modifiers: UInt32, title: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.title = title
    }

    init?(dictionary: [String: Any]) {
        guard let code = dictionary["keyCode"] as? Int, let keyCode = UInt32(exactly: code),
              let mods = dictionary["modifiers"] as? Int, let modifiers = UInt32(exactly: mods),
              let title = dictionary["title"] as? String else { return nil }
        self.init(keyCode: keyCode, modifiers: modifiers, title: title)
    }

    var dictionary: [String: Any] {
        return ["keyCode": Int(keyCode), "modifiers": Int(modifiers), "title": title]
    }
}

// 网页给的是按键位置的名字（比如 KeyT），这里换成系统用的键码
enum KeyCodes {
    static let table: [String: Int] = [
        "KeyA": Int(kVK_ANSI_A), "KeyB": Int(kVK_ANSI_B), "KeyC": Int(kVK_ANSI_C), "KeyD": Int(kVK_ANSI_D),
        "KeyE": Int(kVK_ANSI_E), "KeyF": Int(kVK_ANSI_F), "KeyG": Int(kVK_ANSI_G), "KeyH": Int(kVK_ANSI_H),
        "KeyI": Int(kVK_ANSI_I), "KeyJ": Int(kVK_ANSI_J), "KeyK": Int(kVK_ANSI_K), "KeyL": Int(kVK_ANSI_L),
        "KeyM": Int(kVK_ANSI_M), "KeyN": Int(kVK_ANSI_N), "KeyO": Int(kVK_ANSI_O), "KeyP": Int(kVK_ANSI_P),
        "KeyQ": Int(kVK_ANSI_Q), "KeyR": Int(kVK_ANSI_R), "KeyS": Int(kVK_ANSI_S), "KeyT": Int(kVK_ANSI_T),
        "KeyU": Int(kVK_ANSI_U), "KeyV": Int(kVK_ANSI_V), "KeyW": Int(kVK_ANSI_W), "KeyX": Int(kVK_ANSI_X),
        "KeyY": Int(kVK_ANSI_Y), "KeyZ": Int(kVK_ANSI_Z),
        "Digit0": Int(kVK_ANSI_0), "Digit1": Int(kVK_ANSI_1), "Digit2": Int(kVK_ANSI_2), "Digit3": Int(kVK_ANSI_3),
        "Digit4": Int(kVK_ANSI_4), "Digit5": Int(kVK_ANSI_5), "Digit6": Int(kVK_ANSI_6), "Digit7": Int(kVK_ANSI_7),
        "Digit8": Int(kVK_ANSI_8), "Digit9": Int(kVK_ANSI_9),
        "Space": Int(kVK_Space), "Minus": Int(kVK_ANSI_Minus), "Equal": Int(kVK_ANSI_Equal),
        "Comma": Int(kVK_ANSI_Comma), "Period": Int(kVK_ANSI_Period), "Slash": Int(kVK_ANSI_Slash),
        "Semicolon": Int(kVK_ANSI_Semicolon), "Quote": Int(kVK_ANSI_Quote),
        "BracketLeft": Int(kVK_ANSI_LeftBracket), "BracketRight": Int(kVK_ANSI_RightBracket),
        "Backslash": Int(kVK_ANSI_Backslash), "Backquote": Int(kVK_ANSI_Grave),
        "F1": Int(kVK_F1), "F2": Int(kVK_F2), "F3": Int(kVK_F3), "F4": Int(kVK_F4), "F5": Int(kVK_F5), "F6": Int(kVK_F6),
        "F7": Int(kVK_F7), "F8": Int(kVK_F8), "F9": Int(kVK_F9), "F10": Int(kVK_F10), "F11": Int(kVK_F11), "F12": Int(kVK_F12),
    ]
}

enum HotKeyCenter {
    static var handler: (() -> Void)?
    private static var ref: EventHotKeyRef?
    private static var installed = false

    static func register(_ key: HotKey) -> Bool {
        if !installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { (_, _, _) -> OSStatus in
                DispatchQueue.main.async { HotKeyCenter.handler?() }
                return OSStatus(0)
            }, 1, &spec, nil, nil)
            guard status == 0 else { return false }
            installed = true
        }
        unregister()
        var newRef: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4654_4F44), id: 1)
        let status = RegisterEventHotKey(key.keyCode, key.modifiers, id, GetApplicationEventTarget(), 0, &newRef)
        guard status == 0, let made = newRef else { return false }
        ref = made
        return true
    }

    static func unregister() {
        if let old = ref {
            _ = UnregisterEventHotKey(old)
            ref = nil
        }
    }
}

// MARK: - 窗口和网页视图

final class FloatingPanel: NSPanel {
    // 无边框窗口默认不能接收键盘，这里打开，打字时才用得上
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return false }
}

final class PanelWebView: WKWebView {
    // 窗口没有焦点时，第一下点击也直接生效
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return true }
    // 点勾选、拖动都不抢别的 app 的键盘焦点；打字时由 takeKeyFocus() 主动要
    override var needsPanelToBecomeKey: Bool { return false }
}

// 窗口没有焦点时网页收不到鼠标移动，这里用一个始终有效的跟踪区把位置告诉网页
final class HoverTracker: NSResponder {
    var onMove: (() -> Void)?
    var onExit: (() -> Void)?
    override func mouseEntered(with event: NSEvent) { onMove?() }
    override func mouseMoved(with event: NSEvent) { onMove?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    private var panel: FloatingPanel!
    private var web: PanelWebView!
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let hover = HoverTracker()
    private var dragMonitor: Any?
    private var keyMonitor: Any?
    private var revealed = false
    private var lastOtherApp: NSRunningApplication?
    private var releaseGeneration = 0
    private var isResizing = false
    private var heightDragged = false
    private var cursorZone = 0   // 0 普通，1 左右调整，2 上下调整

    private var settingsWindow: NSWindow?
    private var settingsWeb: WKWebView?
    private var settingsReady = false
    private var settingsShowPending = false
    private var recordingHotKey = false

    private var defaults: UserDefaults { return UserDefaults.standard }
    private var myPID: Int32 { return ProcessInfo.processInfo.processIdentifier }

    // MARK: 设置值

    private var language: String {
        if let saved = defaults.string(forKey: "language") {
            return saved == "en" ? "en" : "zh"
        }
        // 没选过语言时跟随系统
        return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh" : "en"
    }

    private var appearanceSetting: String {
        switch defaults.string(forKey: "appearance") ?? "" {
        case "light": return "light"
        case "dark": return "dark"
        default: return "system"
        }
    }

    private var transparency: Double {
        guard defaults.object(forKey: "transparency") != nil else { return 50 }
        return min(100, max(0, defaults.double(forKey: "transparency")))
    }

    // 透明度 0 接近不透明，50 是默认的磨砂，100 只剩系统磨砂本身
    private var tintAlpha: Double {
        let remaining = 1 - transparency / 100
        return 0.92 * remaining * remaining
    }

    private var panelWidth: CGFloat {
        let saved = defaults.double(forKey: "panelWidth")
        return saved > 0 ? min(K.maxWidth, max(K.minWidth, CGFloat(saved))) : K.defaultWidth
    }

    // 0 表示高度自动；拉过下边缘后记住拉到的高度
    private var fixedHeight: Int {
        return Int(defaults.double(forKey: "panelHeight"))
    }

    private var toggleHotKey: HotKey {
        if let saved = defaults.dictionary(forKey: "hotKeyToggle"), let key = HotKey(dictionary: saved) {
            return key
        }
        // 1.0 版在菜单里选过的快捷键
        let mods = UInt32(controlKey | optionKey)
        switch defaults.string(forKey: "hotKey") ?? "" {
        case "ctrl-opt-d": return HotKey(keyCode: UInt32(kVK_ANSI_D), modifiers: mods, title: "⌃⌥D")
        case "opt-space": return HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), title: "⌥Space")
        default: return HotKey(keyCode: UInt32(kVK_ANSI_T), modifiers: mods, title: "⌃⌥T")
        }
    }

    // MARK: 启动

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: K.bundleID)
            .filter { $0.processIdentifier != myPID }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != myPID {
            lastOtherApp = front
        }
        buildPanel()
        placePanel()
        applyAppearance()
        buildMenu()
        setUpHotKeys()
        setUpLoginItem()
        watchSystem()
        watchEditingShortcuts()
        loadPage()
        // 万一网页没有报告高度，也要让窗口出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.revealIfNeeded()
        }
    }

    // 再次打开 app：小窗藏着就显示，已经显示就打开设置
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if panel.isVisible {
            openSettings()
        } else {
            showPanel()
        }
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func buildPanel() {
        let rect = NSRect(x: 0, y: 0, width: panelWidth, height: K.initialHeight)
        let p = FloatingPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        // 在每个桌面、以及别的 app 全屏时都显示
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        p.isRestorable = false
        p.animationBehavior = .none
        p.tabbingMode = .disallowed
        p.delegate = self

        let glass = NSVisualEffectView(frame: rect)
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active   // 没有焦点时也保持磨砂
        glass.maskImage = AppDelegate.roundedMask(radius: K.cornerRadius)
        glass.autoresizingMask = [.width, .height]
        p.contentView = glass

        hover.onMove = { [weak self] in self?.sendHover() }
        hover.onExit = { [weak self] in self?.endHover() }
        glass.addTrackingArea(NSTrackingArea(rect: .zero,
                                             options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                             owner: hover,
                                             userInfo: nil))

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "bridge")
        let w = PanelWebView(frame: glass.bounds, configuration: config)
        w.autoresizingMask = [.width, .height]
        w.navigationDelegate = self
        w.allowsMagnification = false
        w.allowsBackForwardNavigationGestures = false
        w.allowsLinkPreview = false
        AppDelegate.makeTransparent(w)
        w.wantsLayer = true
        w.layer?.cornerRadius = K.cornerRadius
        w.layer?.masksToBounds = true
        glass.addSubview(w)

        p.initialFirstResponder = w
        _ = p.makeFirstResponder(w)
        panel = p
        web = w
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private static func makeTransparent(_ view: WKWebView) {
        // 系统没有公开设置项，这是通行做法；先检查一下，免得将来系统改了导致崩溃
        if view.responds(to: NSSelectorFromString("_setDrawsBackground:"))
            || view.responds(to: NSSelectorFromString("setDrawsBackground:")) {
            view.setValue(false, forKey: "drawsBackground")
        }
        if #available(macOS 12.0, *) {
            view.underPageBackgroundColor = .clear
        }
    }

    private func loadPage() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else {
            NSLog("FloatTodo: index.html is missing from the app bundle")
            return
        }
        _ = web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func js(_ code: String, completion: ((Any?) -> Void)? = nil) {
        guard web != nil else { return }
        web.evaluateJavaScript(code) { result, _ in
            completion?(result)
        }
    }

    private func settingsJS(_ code: String) {
        settingsWeb?.evaluateJavaScript(code) { _, _ in }
    }

    private var panelSettingsCall: String {
        return "FT.applySettings({lang:'\(language)',ta:\(tintAlpha),lockedHeight:\(fixedHeight)})"
    }

    // MARK: 网页发来的消息

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        if message.name == "settings" {
            handleSettingsMessage(type: type, body: body)
            return
        }
        switch type {
        case "ready":
            js("\(panelSettingsCall);FT.load(\(readTasksJSON()))")
        case "save":
            if let json = body["json"] as? String {
                writeTasksJSON(json)
                pushRepeats()
            }
        case "resize":
            if let height = body["height"] as? NSNumber { setPanelHeight(CGFloat(height.doubleValue)) }
        case "wantKey":
            takeKeyFocus()
        case "releaseKey":
            releaseKeyFocus()
        case "dragStart":
            beginWindowDrag()
        case "resizeStart":
            if let edge = body["edge"] as? String { beginResizeDrag(edge: edge) }
        case "autoHeight":
            useAutomaticHeight()
        case "openSettings":
            openSettings()
        case "menu":
            stopDragMonitor()   // 菜单会吞掉鼠标松开的事件
            _ = menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        default:
            break
        }
    }

    // 只允许打开自己的界面；拖进来的文件、链接一律不跳转
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        let name = url?.lastPathComponent
        let isOurPage = url?.isFileURL == true && (name == "index.html" || name == "settings.html")
        decisionHandler(isOurPage ? .allow : .cancel)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webView === web {
            loadPage()
        } else {
            loadSettingsPage()
        }
    }

    // MARK: 保存数据

    private var dataURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FloatTodo", isDirectory: true).appendingPathComponent("tasks.json")
    }

    private func readTasksJSON() -> String {
        guard let data = try? Data(contentsOf: dataURL) else { return "null" }
        if (try? JSONSerialization.jsonObject(with: data, options: [])) != nil,
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        // 文件坏了：留一份备份，不要直接覆盖
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = dataURL.deletingLastPathComponent().appendingPathComponent("tasks.broken-\(stamp).json")
        try? FileManager.default.moveItem(at: dataURL, to: backup)
        return "null"
    }

    private func writeTasksJSON(_ json: String) {
        let url = dataURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            try Data(json.utf8).write(to: url, options: .atomic)
        } catch {
            NSLog("FloatTodo: could not save tasks: %@", error.localizedDescription)
        }
    }

    // MARK: 窗口位置和大小

    private func defaultFrame(height: CGFloat) -> NSRect {
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = panelWidth
        return NSRect(x: visible.maxX - width - K.margin,
                      y: visible.maxY - K.margin - height,
                      width: width,
                      height: height)
    }

    private func placePanel() {
        var frame = defaultFrame(height: panel.frame.height)
        if defaults.object(forKey: "panelX") != nil {
            frame.origin.x = CGFloat(defaults.double(forKey: "panelX"))
            frame.origin.y = CGFloat(defaults.double(forKey: "panelTop")) - frame.height
        }
        panel.setFrame(frame, display: false)
        keepOnScreen()
    }

    // 外接显示器拔掉之后，窗口不要留在看不见的地方
    private func keepOnScreen() {
        let frame = panel.frame
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(frame.insetBy(dx: 24, dy: 10)) }
        if !onScreen {
            panel.setFrame(defaultFrame(height: frame.height), display: true)
            savePosition()
        }
    }

    private func savePosition() {
        defaults.set(Double(panel.frame.minX), forKey: "panelX")
        defaults.set(Double(panel.frame.maxY), forKey: "panelTop")
    }

    private func clampToVisibleFrame() {
        guard let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        var origin = panel.frame.origin
        origin.x = min(max(origin.x, visible.minX), visible.maxX - panel.frame.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - panel.frame.height)
        panel.setFrameOrigin(origin)
    }

    private func setPanelHeight(_ height: CGFloat) {
        let h = max(K.minHeight, height.rounded(.up))
        var frame = panel.frame
        let top = frame.maxY
        frame.size.height = h
        frame.origin.y = top - h   // 顶边固定，往下长
        if let visible = (panel.screen ?? NSScreen.main)?.visibleFrame, frame.minY < visible.minY {
            frame.origin.y = visible.minY
        }
        if !revealed {
            panel.setFrame(frame, display: true)
            revealIfNeeded()
            return
        }
        if isResizing || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(frame, display: true)
            panel.invalidateShadow()
            return
        }
        let target = frame
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = K.resizeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panel.animator().setFrame(target, display: true)
        }, completionHandler: {
            self.panel.invalidateShadow()
        })
    }

    private func revealIfNeeded() {
        guard !revealed else { return }
        revealed = true
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    private func sendHover() {
        let mouse = NSEvent.mouseLocation
        let x = mouse.x - panel.frame.minX
        let y = panel.frame.maxY - mouse.y
        js("window.FT&&FT.hoverAt(\(x),\(y))")
        var zone = 0
        if y >= panel.frame.height - 6 {
            zone = 2
        } else if (x <= K.gripWidth || x >= panel.frame.width - K.gripWidth) && y >= 8 {
            zone = 1
        }
        if zone != cursorZone {
            cursorZone = zone
            switch zone {
            case 1: NSCursor.resizeLeftRight.set()
            case 2: NSCursor.resizeUpDown.set()
            default: NSCursor.arrow.set()
            }
        }
    }

    private func endHover() {
        js("window.FT&&FT.hoverEnd()")
        if cursorZone != 0 {
            cursorZone = 0
            NSCursor.arrow.set()
        }
    }

    // MARK: 拖动窗口和调整宽度

    private func beginWindowDrag() {
        stopDragMonitor()
        guard NSEvent.pressedMouseButtons & 1 == 1 else { return }
        let startMouse = NSEvent.mouseLocation
        let startOrigin = panel.frame.origin
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self = self else { return event }
            if event.type == .leftMouseDragged {
                let mouse = NSEvent.mouseLocation
                self.panel.setFrameOrigin(NSPoint(x: startOrigin.x + mouse.x - startMouse.x,
                                                  y: startOrigin.y + mouse.y - startMouse.y))
            } else {
                self.finishWindowDrag()
            }
            return event
        }
    }

    private func stopDragMonitor() {
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
            dragMonitor = nil
            isResizing = false
        }
    }

    private func finishWindowDrag() {
        stopDragMonitor()
        clampToVisibleFrame()
        savePosition()
    }

    private func beginResizeDrag(edge: String) {
        stopDragMonitor()
        guard NSEvent.pressedMouseButtons & 1 == 1 else { return }
        let startMouse = NSEvent.mouseLocation
        let startFrame = panel.frame
        let fromLeft = edge.contains("left")
        let fromRight = edge.contains("right")
        let fromBottom = edge.contains("bottom")
        let maxHeight = max(K.minFixedHeight, (panel.screen ?? NSScreen.main)?.visibleFrame.height ?? 900)
        isResizing = true
        heightDragged = false
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self = self else { return event }
            guard event.type == .leftMouseDragged else {
                self.finishResizeDrag()
                return event
            }
            let mouse = NSEvent.mouseLocation
            // 从当前大小出发：只拉宽度时，高度还要跟着文字换行变化
            var frame = self.panel.frame
            if fromLeft || fromRight {
                let dx = mouse.x - startMouse.x
                let wanted = fromLeft ? startFrame.width - dx : startFrame.width + dx
                let width = min(K.maxWidth, max(K.minWidth, wanted)).rounded()
                frame.size.width = width
                frame.origin.x = fromLeft ? startFrame.maxX - width : startFrame.minX
            }
            if fromBottom {
                if !self.heightDragged {
                    // 第一次拖动时就切到固定高度，内容才会跟着窗口撑开
                    self.heightDragged = true
                    self.js("window.FT&&FT.applySettings({lockedHeight:\(Int(startFrame.height))})")
                }
                let wanted = startFrame.height + startMouse.y - mouse.y
                let height = min(maxHeight, max(K.minFixedHeight, wanted)).rounded()
                frame.size.height = height
                frame.origin.y = startFrame.maxY - height
            }
            self.panel.setFrame(frame, display: true)
            return event
        }
    }

    private func finishResizeDrag() {
        stopDragMonitor()
        defaults.set(Double(panel.frame.width), forKey: "panelWidth")
        if heightDragged {
            heightDragged = false
            defaults.set(Double(panel.frame.height), forKey: "panelHeight")
            js("window.FT&&\(panelSettingsCall)")
            pushSettings()
        }
        clampToVisibleFrame()
        savePosition()
        panel.invalidateShadow()
    }

    private func useAutomaticHeight() {
        defaults.removeObject(forKey: "panelHeight")
        js("window.FT&&\(panelSettingsCall)")
        pushSettings()
    }

    // MARK: 键盘焦点：只有打字时才要，打完还给原来的 app

    private func takeKeyFocus() {
        releaseGeneration += 1
        if !NSApp.isActive && !defaults.bool(forKey: "noActivate") {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.makeKeyAndOrderFront(nil)
        _ = panel.makeFirstResponder(web)
    }

    private func releaseKeyFocus() {
        releaseGeneration += 1
        attemptRelease(generation: releaseGeneration)
    }

    // 鼠标松开后再多等一拍才还：这次点击可能正要进入另一处输入
    private func attemptRelease(generation: Int, buttonsWereUp: Bool = false) {
        guard generation == releaseGeneration, panel.isVisible, panel.isKeyWindow else { return }
        let buttonsUp = NSEvent.pressedMouseButtons == 0
        if !(buttonsUp && buttonsWereUp) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.attemptRelease(generation: generation, buttonsWereUp: buttonsUp)
            }
            return
        }
        if let settings = settingsWindow, settings.isVisible {
            settings.makeKeyAndOrderFront(nil)
        } else if NSApp.isActive, let previous = lastOtherApp, !previous.isTerminated {
            giveFocusBack(to: previous)
        } else {
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }

    private func giveFocusBack(to app: NSRunningApplication) {
        #if compiler(>=5.9)
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: app)
        }
        #endif
        _ = app.activate(options: [])
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === panel else { return }
        js("window.FT&&FT.onKey(true)")
    }

    func windowDidResignKey(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            settingsJS("S.windowClosing()")   // 切到别处时结束录制，恢复全局快捷键
            return
        }
        guard (notification.object as? NSWindow) === panel else { return }
        js("window.FT&&FT.onKey(false)")
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        settingsJS("S.windowClosing()")
        if recordingHotKey {
            recordingHotKey = false
            registerHotKeys()
        }
        if NSApp.isActive, !panel.isKeyWindow, let previous = lastOtherApp, !previous.isTerminated {
            giveFocusBack(to: previous)
        }
    }

    // 这个 app 没有菜单栏，⌘C ⌘V 这些要自己转给网页
    private func watchEditingShortcuts() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handleEditingShortcut(event)
        }
    }

    private func handleEditingShortcut(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return event }
        if let settings = settingsWindow, settings.isKeyWindow {
            if !recordingHotKey, flags == .command, key == "w" {
                settings.performClose(nil)
                return nil
            }
            return event
        }
        guard panel.isKeyWindow else { return event }
        if flags == .command {
            switch key {
            case "x": return sendEdit("cut:", event)
            case "c": return sendEdit("copy:", event)
            case "v": return sendEdit("paste:", event)
            case "a": return sendEdit("selectAll:", event)
            case ",":
                openSettings()
                return nil
            case "z":
                js("window.FT?FT.nativeUndo():false") { [weak self] handled in
                    if (handled as? Bool) != true, self?.panel.undoManager?.canUndo == true {
                        self?.panel.undoManager?.undo()
                    }
                }
                return nil
            default:
                return event
            }
        }
        if flags == [.command, .shift], key == "z" {
            if panel.undoManager?.canRedo == true {
                panel.undoManager?.redo()
            }
            return nil
        }
        return event
    }

    private func sendEdit(_ selectorName: String, _ event: NSEvent) -> NSEvent? {
        let selector = NSSelectorFromString(selectorName)
        guard web.responds(to: selector) else { return event }
        _ = web.perform(selector, with: nil)
        return nil
    }

    // MARK: 显示、隐藏和快速添加

    private func showPanel() {
        panel.orderFrontRegardless()
        js("window.FT&&FT.onShown()")
    }

    private func hidePanel() {
        releaseGeneration += 1
        let hadFocus = NSApp.isActive && settingsWindow?.isKeyWindow != true
        js("window.FT&&FT.onKey(false)")
        panel.orderOut(nil)
        if hadFocus, let settings = settingsWindow, settings.isVisible {
            settings.makeKeyAndOrderFront(nil)
        } else if hadFocus, let previous = lastOtherApp, !previous.isTerminated {
            giveFocusBack(to: previous)
        }
    }

    private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: 菜单栏

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "FloatTodo")
                ?? NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "FloatTodo")
            if let image = image {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "✓"
            }
            button.toolTip = "FloatTodo"
        }

        menu.autoenablesItems = false
        menu.delegate = self

        toggleItem.target = self
        toggleItem.action = #selector(menuTogglePanel)
        menu.addItem(toggleItem)

        settingsItem.target = self
        settingsItem.action = #selector(menuOpenSettings)
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        quitItem.target = self
        quitItem.action = #selector(menuQuit)
        quitItem.keyEquivalent = "q"
        menu.addItem(quitItem)

        updateMenuTitles()
        statusItem.menu = menu
    }

    private func updateMenuTitles() {
        toggleItem.title = MenuText.get(panel.isVisible ? "hide" : "show", language: language)
        settingsItem.title = MenuText.get("settings", language: language)
        quitItem.title = MenuText.get("quit", language: language)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        updateMenuTitles()
    }

    @objc private func menuTogglePanel() {
        togglePanel()
    }

    @objc private func menuOpenSettings() {
        openSettings()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    // MARK: 设置窗口

    private func buildSettingsWindow() {
        let rect = NSRect(x: 0, y: 0, width: K.settingsWidth, height: 560)
        let window = NSWindow(contentRect: rect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = MenuText.get("title", language: language)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        window.appearance = panel.appearance

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "settings")
        let view = WKWebView(frame: rect, configuration: config)
        view.autoresizingMask = [.width, .height]
        view.navigationDelegate = self
        view.allowsMagnification = false
        view.allowsBackForwardNavigationGestures = false
        view.allowsLinkPreview = false
        window.contentView = view
        window.center()

        settingsWindow = window
        settingsWeb = view
        loadSettingsPage()
    }

    private func loadSettingsPage() {
        guard let view = settingsWeb, let url = Bundle.main.url(forResource: "settings", withExtension: "html") else {
            NSLog("FloatTodo: settings.html is missing from the app bundle")
            return
        }
        _ = view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func openSettings() {
        if settingsWindow == nil {
            buildSettingsWindow()
        }
        if settingsReady {
            showSettingsWindow()
        } else {
            // 页面载好再显示，避免先闪一下空白；万一没载好，也要出现
            settingsShowPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.showSettingsIfPending()
            }
        }
    }

    private func showSettingsIfPending() {
        guard settingsShowPending else { return }
        settingsShowPending = false
        showSettingsWindow()
    }

    private func showSettingsWindow() {
        guard let window = settingsWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if let view = settingsWeb {
            _ = window.makeFirstResponder(view)
        }
        pushSettings()
    }

    private func setSettingsHeight(_ height: CGFloat) {
        guard let window = settingsWindow else { return }
        let top = window.frame.maxY
        var content = window.contentRect(forFrameRect: window.frame)
        content.size.height = max(120, height)
        var frame = window.frameRect(forContentRect: content)
        frame.origin.y = top - frame.height
        window.setFrame(frame, display: true)
    }

    private func pushSettings() {
        let payload: [String: Any] = [
            "language": language,
            "appearance": appearanceSetting,
            "transparency": transparency,
            "login": loginItemEnabled,
            "heightLocked": fixedHeight > 0,
            "hotKeys": ["toggle": toggleHotKey.title],
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
           let json = String(data: data, encoding: .utf8) {
            settingsJS("S.update(\(json))")
        }
        pushRepeats()
    }

    private func pushRepeats() {
        guard settingsWindow?.isVisible == true else { return }
        js("JSON.stringify(window.FT?FT.repeats():[])") { [weak self] result in
            if let json = result as? String {
                self?.settingsJS("S.update({repeats:\(json)})")
            }
        }
    }

    private func handleSettingsMessage(type: String, body: [String: Any]) {
        switch type {
        case "ready":
            settingsReady = true
            if settingsShowPending {
                showSettingsIfPending()
            } else {
                pushSettings()   // 窗口已经先显示了，页面载好后才能把设置值送进去
            }
        case "resize":
            if let height = body["height"] as? NSNumber { setSettingsHeight(CGFloat(height.doubleValue)) }
        case "set":
            if let key = body["key"] as? String { applySetting(key: key, value: body["value"]) }
        case "autoHeight":
            useAutomaticHeight()
        case "recordStart":
            recordingHotKey = true
            HotKeyCenter.unregister()
        case "recordEnd":
            recordingHotKey = false
            registerHotKeys()
        case "setHotKey":
            recordingHotKey = false
            changeHotKey(body)
        case "stopRepeat":
            if let id = body["id"] as? String, let data = try? JSONSerialization.data(withJSONObject: [id], options: []),
               let quoted = String(data: data, encoding: .utf8) {
                js("window.FT&&FT.stopRepeat(\(quoted)[0])")
            }
        case "close":
            settingsWindow?.performClose(nil)
        default:
            break
        }
    }

    private func applySetting(key: String, value: Any?) {
        switch key {
        case "language":
            if let text = value as? String, text == "zh" || text == "en" {
                defaults.set(text, forKey: "language")
                settingsWindow?.title = MenuText.get("title", language: language)
                updateMenuTitles()
                js("window.FT&&\(panelSettingsCall)")
                pushRepeats()
            }
        case "appearance":
            if let text = value as? String, text == "system" || text == "light" || text == "dark" {
                defaults.set(text, forKey: "appearance")
                applyAppearance()
            }
        case "transparency":
            if let number = value as? NSNumber {
                defaults.set(number.doubleValue, forKey: "transparency")
                js("window.FT&&\(panelSettingsCall)")
            }
        case "login":
            if let on = value as? Bool {
                setLoginItem(enabled: on)
            }
        default:
            break
        }
    }

    private func applyAppearance() {
        let look: NSAppearance?
        switch appearanceSetting {
        case "light": look = NSAppearance(named: .aqua)
        case "dark": look = NSAppearance(named: .darkAqua)
        default: look = nil
        }
        panel.appearance = look
        settingsWindow?.appearance = look
        panel.invalidateShadow()
    }

    // MARK: 全局快捷键

    private func setUpHotKeys() {
        defaults.removeObject(forKey: "hotKeyQuickAdd")   // 旧版的快速添加已经删除
        HotKeyCenter.handler = { [weak self] in self?.togglePanel() }
        registerHotKeys()
    }

    private func registerHotKeys() {
        let key = toggleHotKey
        if !HotKeyCenter.register(key) {
            NSLog("FloatTodo: could not register hot key %@", key.title)
        }
    }

    private func changeHotKey(_ body: [String: Any]) {
        guard let code = body["code"] as? String, let title = body["title"] as? String else {
            registerHotKeys()
            return
        }
        guard let keyCode = KeyCodes.table[code], let carbonCode = UInt32(exactly: keyCode) else {
            registerHotKeys()
            settingsJS("S.hotKeyError('toggle','unsupported')")
            return
        }
        var mods = 0
        if body["ctrl"] as? Bool == true { mods |= Int(controlKey) }
        if body["alt"] as? Bool == true { mods |= Int(optionKey) }
        if body["shift"] as? Bool == true { mods |= Int(shiftKey) }
        if body["meta"] as? Bool == true { mods |= Int(cmdKey) }
        let key = HotKey(keyCode: carbonCode, modifiers: UInt32(mods), title: title)
        if HotKeyCenter.register(key) {
            defaults.set(key.dictionary, forKey: "hotKeyToggle")
            pushSettings()
        } else {
            registerHotKeys()
            settingsJS("S.hotKeyError('toggle','taken')")
        }
    }

    // MARK: 开机自动启动（在 ~/Library/LaunchAgents 放一个启动项）

    private var launchAgentURL: URL {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(K.bundleID).plist")
    }

    private var loginItemEnabled: Bool {
        return FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    private func setLoginItem(enabled: Bool) {
        let url = launchAgentURL
        if !enabled {
            try? FileManager.default.removeItem(at: url)
            return
        }
        guard let executable = Bundle.main.executablePath else { return }
        let plist: [String: Any] = [
            "Label": K.bundleID,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("FloatTodo: could not write launch agent: %@", error.localizedDescription)
        }
    }

    private func setUpLoginItem() {
        if !defaults.bool(forKey: "loginItemConfigured") {
            defaults.set(true, forKey: "loginItemConfigured")
            setLoginItem(enabled: true)
        } else if loginItemEnabled {
            setLoginItem(enabled: true)   // app 换了位置时更新路径
        }
    }

    // MARK: 系统事件

    private func watchSystem() {
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(systemDidWake),
                                                          name: NSWorkspace.didWakeNotification,
                                                          object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(otherAppDidActivate(_:)),
                                                          name: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screensDidChange),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    @objc private func otherAppDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != myPID else { return }
        lastOtherApp = app
    }

    @objc private func systemDidWake() {
        js("window.FT&&FT.tick()")
    }

    @objc private func screensDidChange() {
        keepOnScreen()
    }
}

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.run()
