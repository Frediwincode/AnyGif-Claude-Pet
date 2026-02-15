import AppKit
import UniformTypeIdentifiers

/// Settings window built with programmatic NSStackView layout.
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {

    private let gifAssignment: GifAssignment
    /// Called when the user changes pet size via the slider.
    var onPetSizeChanged: ((CGFloat) -> Void)?
    /// Called when the user assigns or clears a GIF for any state.
    var onGifAssignmentChanged: ((PetState) -> Void)?

    private var gifPreviews: [PetState: NSImageView] = [:]
    private var apiKeyMaskTimer: Timer?
    private var apiKeyMasked = false

    init(gifAssignment: GifAssignment) {
        self.gifAssignment = gifAssignment

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 820),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AnyGif Claude Pet - Settings"
        window.minSize = NSSize(width: 460, height: 400)
        window.center()

        super.init(window: window)

        let contentView = buildContentView()
        window.contentView = contentView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    private func buildContentView() -> NSView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let clipView = NSClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(buildGifSection())
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(buildSizeSection())
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(buildHookSection())
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(buildApiKeySection())

        // Wrap stack in a flipped container so NSScrollView can compute content height.
        let container = FlippedView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        scrollView.documentView = container

        // Pin container width to clip view so only vertical scrolling occurs.
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
        ])

        return scrollView
    }

    // MARK: - GIF Assignment Section

    private func buildGifSection() -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 12

        let title = makeLabel("GIF Assignments", bold: true, size: 15)
        section.addArrangedSubview(title)

        for state in PetState.allCases {
            let row = buildGifRow(for: state)
            section.addArrangedSubview(row)
        }

        return section
    }

    private func buildGifRow(for state: PetState) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        // State name (fixed width).
        let label = makeLabel(state.rawValue.capitalized, bold: false, size: 13)
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
        row.addArrangedSubview(label)

        // GIF preview thumbnail.
        let preview = NSImageView()
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            preview.widthAnchor.constraint(equalToConstant: 48),
            preview.heightAnchor.constraint(equalToConstant: 48),
        ])
        gifPreviews[state] = preview
        updatePreview(for: state)
        row.addArrangedSubview(preview)

        // "Choose..." button.
        let chooseBtn = NSButton(title: "Choose...", target: self, action: #selector(chooseGifTapped(_:)))
        chooseBtn.tag = PetState.allCases.firstIndex(of: state)!
        row.addArrangedSubview(chooseBtn)

        // "Clear" button.
        let clearBtn = NSButton(title: "Clear", target: self, action: #selector(clearGifTapped(_:)))
        clearBtn.tag = PetState.allCases.firstIndex(of: state)!
        row.addArrangedSubview(clearBtn)

        return row
    }

    @objc private func chooseGifTapped(_ sender: NSButton) {
        let state = PetState.allCases[sender.tag]
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a GIF for the \"\(state.rawValue)\" state"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        gifAssignment.setGif(url: url, for: state)
        updatePreview(for: state)
        onGifAssignmentChanged?(state)
    }

    @objc private func clearGifTapped(_ sender: NSButton) {
        let state = PetState.allCases[sender.tag]
        gifAssignment.clearGif(for: state)
        updatePreview(for: state)
        onGifAssignmentChanged?(state)
    }

    private func updatePreview(for state: PetState) {
        guard let imageView = gifPreviews[state] else { return }
        if let url = gifAssignment.gifURL(for: state) {
            imageView.image = NSImage(contentsOf: url)
        } else {
            imageView.image = nil
        }
    }

    // MARK: - Pet Size Section

    private func buildSizeSection() -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8

        let title = makeLabel("Pet Size", bold: true, size: 15)
        section.addArrangedSubview(title)

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10

        let slider = NSSlider(value: 120, minValue: 60, maxValue: 300, target: self, action: #selector(sizeSliderChanged(_:)))
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 250).isActive = true

        let sizeLabel = makeLabel("120 px", bold: false, size: 13)
        sizeLabel.tag = 999  // identifier to find it later
        slider.tag = 998

        row.addArrangedSubview(slider)
        row.addArrangedSubview(sizeLabel)
        section.addArrangedSubview(row)

        return section
    }

    @objc private func sizeSliderChanged(_ sender: NSSlider) {
        let size = CGFloat(sender.integerValue)
        // Find the label in the same row.
        if let row = sender.superview as? NSStackView {
            for view in row.arrangedSubviews {
                if let label = view as? NSTextField, label.tag == 999 {
                    label.stringValue = "\(Int(size)) px"
                }
            }
        }
        onPetSizeChanged?(size)
    }

    // MARK: - Hook Status Section

    private func buildHookSection() -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8

        let title = makeLabel("Claude Code Hooks", bold: true, size: 15)
        section.addArrangedSubview(title)

        let installed = HookInstaller.isInstalled()
        let statusLabel = makeLabel(
            installed ? "Status: Installed" : "Status: Not installed",
            bold: false, size: 13
        )
        statusLabel.tag = 700
        section.addArrangedSubview(statusLabel)

        let installBtn = NSButton(
            title: installed ? "Reinstall Hooks" : "Install Hooks",
            target: self,
            action: #selector(installHooksTapped(_:))
        )
        installBtn.tag = 701
        section.addArrangedSubview(installBtn)

        return section
    }

    @objc private func installHooksTapped(_ sender: NSButton) {
        do {
            try HookInstaller.install()
            // Update label.
            if let section = sender.superview as? NSStackView {
                for view in section.arrangedSubviews {
                    if let label = view as? NSTextField, label.tag == 700 {
                        label.stringValue = "Status: Installed"
                    }
                }
            }
            sender.title = "Reinstall Hooks"

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

    // MARK: - Google API Key Section

    private func buildApiKeySection() -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8

        let title = makeLabel("Vibe Report (Gemini API)", bold: true, size: 15)
        section.addArrangedSubview(title)

        let desc = makeLabel("输入 Google API Key 以启用每日 Vibe 锐评（使用 Gemini 2.0 Flash）", bold: false, size: 11)
        desc.textColor = .secondaryLabelColor
        section.addArrangedSubview(desc)

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10

        let field = NSTextField()
        field.placeholderString = "Google API Key"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 300).isActive = true
        field.tag = 800
        field.delegate = self

        // Show masked if key already saved.
        if let key = gifAssignment.googleApiKey, !key.isEmpty {
            field.stringValue = String(repeating: "•", count: key.count)
            apiKeyMasked = true
        }

        row.addArrangedSubview(field)

        section.addArrangedSubview(row)
        return section
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field.tag == 800 else { return }

        // If masked, user started typing → clear and treat as new input.
        if apiKeyMasked {
            apiKeyMasked = false
        }

        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        gifAssignment.googleApiKey = key.isEmpty ? nil : key

        // Reset mask timer: mask after 3 seconds of no input.
        apiKeyMaskTimer?.invalidate()
        if !key.isEmpty {
            apiKeyMaskTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self, weak field] _ in
                guard let self, let field, let k = self.gifAssignment.googleApiKey, !k.isEmpty else { return }
                field.stringValue = String(repeating: "•", count: k.count)
                self.apiKeyMasked = true
            }
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field.tag == 800 else { return }
        // Unmask when user focuses the field.
        if apiKeyMasked, let key = gifAssignment.googleApiKey {
            apiKeyMasked = false
            apiKeyMaskTimer?.invalidate()
            field.stringValue = key
        }
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, bold: Bool, size: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        label.isEditable = false
        label.isSelectable = false
        label.isBezeled = false
        label.drawsBackground = false
        return label
    }

    private func makeSeparator() -> NSView {
        let sep = NSBox()
        sep.boxType = .separator
        return sep
    }
}

/// An NSView subclass with flipped coordinates (origin at top-left) for correct scroll behavior.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
