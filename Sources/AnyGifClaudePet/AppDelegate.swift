import AppKit

/// App delegate: manages the menu bar status item and the pet window.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var petWindow: PetWindow!
    private var petView: PetView!
    private let gifAssignment = GifAssignment()
    private lazy var viewModel = PetViewModel(gifAssignment: gifAssignment)
    private let hookService = ClaudeHookService()
    private var settingsController: SettingsWindowController?

    // Vibe report components
    private let eventLogger = EventLogger()
    private let geminiService = GeminiAPIService()
    private let vibeBubble = VibeBubbleView()
    private var vibeTimer: Timer?
    private var vibeTriggeredToday = false
    private var lastVibeDate: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        eventLogger.cleanupOldEvents()
        setupStatusItem()
        setupPetWindow()
        loadInitialGif()
        startHookService()
        startVibeTimer()
        showFirstRunOnboardingIfNeeded()
    }

    // MARK: - First-run onboarding

    private func showFirstRunOnboardingIfNeeded() {
        let key = "hasLaunchedBefore"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let alert = NSAlert()
        alert.messageText = "Welcome to AnyGif Claude Pet!"
        alert.informativeText = """
            这是一只桌面宠物，它会通过 Claude Code hooks 实时反映你的编程状态。\
            你可以为不同状态指定自定义 GIF 动画。\n\n\
            是否立即安装 Claude Code hooks？（之后也可在菜单栏中手动安装）
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install Hooks & Start")
        alert.addButton(withTitle: "Skip for Now")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            do {
                try HookInstaller.install()
            } catch {
                let errAlert = NSAlert()
                errAlert.messageText = "Installation Failed"
                errAlert.informativeText = error.localizedDescription
                errAlert.alertStyle = .critical
                errAlert.runModal()
            }
        }

        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Main menu (enables Cmd+C/V/X/A in text fields)

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = {
            let m = NSMenu(title: "Edit")
            m.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
            m.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
            m.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
            m.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
            return m
        }()
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use SF Symbol on macOS 13+; fall back to emoji.
            if let img = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Pet") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "\u{1F43E}"  // paw emoji
            }
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(withTitle: "Install Hooks", action: #selector(installHooks), keyEquivalent: "")
        menu.addItem(withTitle: "Vibe Report", action: #selector(triggerVibeReport), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    // MARK: - Pet window

    private func setupPetWindow() {
        petWindow = PetWindow(size: 120)
        petView = PetView(frame: petWindow.contentView!.bounds)
        petView.autoresizingMask = [.width, .height]
        petWindow.contentView?.addSubview(petView)
        petWindow.orderFront(nil)
    }

    // MARK: - GIF loading

    private func loadInitialGif() {
        // Wire animator output to the view.
        viewModel.animator.onFrame = { [weak self] image in
            self?.petView.currentFrame = image
        }

        // Wire state changes to the view for placeholder animations.
        viewModel.onStateChanged = { [weak self] state in
            print("[PET] State changed to: \(state)")
            self?.petView.petState = state
        }

        // When no GIF is assigned for a state, clear the frame to show placeholder.
        viewModel.onClearFrame = { [weak self] in
            self?.petView.currentFrame = nil
            self?.petView.startPlaceholderAnimation()
        }

        // Start placeholder animation if no GIF is loaded yet.
        petView.startPlaceholderAnimation()

        // Accept a GIF path via command-line argument.
        let args = CommandLine.arguments
        if args.count > 1 {
            let gifURL = URL(fileURLWithPath: args[1])
            viewModel.loadGif(at: gifURL)
        } else {
            // Try loading the GIF for the current (idle) state.
            viewModel.loadGifForCurrentState()
        }
    }

    // MARK: - Hook service

    private func startHookService() {
        hookService.start { [weak self] event in
            self?.viewModel.handleClaudeEvent(event)
        }
    }

    // MARK: - Actions

    @objc func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(gifAssignment: gifAssignment)
            settingsController?.onPetSizeChanged = { [weak self] size in
                self?.resizePet(to: size)
            }
            settingsController?.onGifAssignmentChanged = { [weak self] state in
                guard let self = self else { return }
                if self.viewModel.currentState == state {
                    self.viewModel.loadGifForCurrentState()
                }
            }
        }
        settingsController?.showWindow(self)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func installHooks() {
        do {
            try HookInstaller.install()
            let alert = NSAlert()
            alert.messageText = "Hooks Installed"
            alert.informativeText = "Claude Code hooks have been installed successfully."
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Installation Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    private func resizePet(to size: CGFloat) {
        var frame = petWindow.frame
        frame.size = NSSize(width: size, height: size)
        petWindow.setFrame(frame, display: true, animate: true)
    }

    // MARK: - Vibe Report

    /// Manual trigger from menu.
    @objc private func triggerVibeReport() {
        generateAndShowVibe()
    }

    /// Start a timer that checks every 60 seconds whether it's 18:00.
    private func startVibeTimer() {
        vibeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkDailyVibeTrigger()
        }
    }

    private func checkDailyVibeTrigger() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: now)

        // Reset flag if day changed.
        if todayString != lastVibeDate {
            vibeTriggeredToday = false
            lastVibeDate = todayString
        }

        // Trigger at 18:00 if not already done today.
        if hour >= 18 && !vibeTriggeredToday {
            vibeTriggeredToday = true
            generateAndShowVibe()
        }
    }

    private func generateAndShowVibe() {
        guard let apiKey = gifAssignment.googleApiKey, !apiKey.isEmpty else {
            vibeBubble.show(text: "请在 Settings 中配置 Google API Key 以启用 Vibe Report。", relativeTo: petWindow)
            return
        }

        let stats = eventLogger.todayStats()

        Task {
            do {
                let summary = try await geminiService.generateVibeSummary(stats: stats, apiKey: apiKey)
                await MainActor.run {
                    vibeBubble.show(text: summary, relativeTo: petWindow)
                }
            } catch {
                await MainActor.run {
                    vibeBubble.show(text: "Vibe 生成失败：\(error.localizedDescription)", relativeTo: petWindow)
                }
            }
        }
    }
}
