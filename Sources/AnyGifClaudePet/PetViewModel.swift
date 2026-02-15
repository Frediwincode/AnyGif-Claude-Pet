import AppKit

/// Manages pet state transitions and drives GIF animation.
final class PetViewModel {

    private(set) var currentState: PetState = .idle {
        didSet { onStateChanged?(currentState) }
    }

    /// Called whenever the pet state changes.
    var onStateChanged: ((PetState) -> Void)?

    let animator = GifAnimator()
    private var autoReturnTimer: Timer?
    private let gifAssignment: GifAssignment?

    /// Timer that fires after 5 minutes of no events to transition to sleeping.
    private var idleTimer: Timer?
    private let idleTimeout: TimeInterval = 300 // 5 minutes

    init(gifAssignment: GifAssignment? = nil) {
        self.gifAssignment = gifAssignment
    }

    /// Transition to a new state. Loads the corresponding GIF if a mapping exists.
    func transition(to state: PetState) {
        autoReturnTimer?.invalidate()
        autoReturnTimer = nil
        currentState = state

        // Load the GIF assigned to this state, if any.
        loadGifForCurrentState()

        // Schedule auto-return to idle for transient states.
        if let delay = state.autoReturnDelay {
            autoReturnTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.transition(to: .idle)
            }
        }
    }

    /// Called to clear the displayed frame (show placeholder).
    var onClearFrame: (() -> Void)?

    /// Load the GIF for the current state from GifAssignment, if available.
    /// If no GIF is assigned, stops the animator and shows the placeholder.
    func loadGifForCurrentState() {
        if let url = gifAssignment?.gifURL(for: currentState) {
            animator.load(from: url)
        } else {
            animator.stop()
            onClearFrame?()
        }
    }

    /// Load a GIF file to display.
    func loadGif(at url: URL) {
        animator.load(from: url)
    }

    // MARK: - Claude Event Handling

    /// Handle an incoming Claude Code hook event and transition the pet state accordingly.
    func handleClaudeEvent(_ event: ClaudeEvent) {
        print("[PET] Received event: \(event.event) tool: \(event.tool ?? "nil")")
        resetIdleTimer()

        let targetState: PetState

        switch event.event {
        case "PreToolUse":
            let workingTools: Set<String> = ["Bash", "Edit", "Write"]
            let thinkingTools: Set<String> = ["Read", "Grep", "Glob"]
            if let tool = event.tool, workingTools.contains(tool) {
                targetState = .working
            } else if let tool = event.tool, thinkingTools.contains(tool) {
                targetState = .thinking
            } else {
                targetState = .thinking
            }

        case "PostToolUse":
            targetState = .happy

        case "Stop":
            targetState = .celebrating

        default:
            // Unknown event -- just reset idle timer, don't change state.
            return
        }

        transition(to: targetState)
    }

    /// Reset the idle timer. Called on every incoming event.
    func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            self?.transition(to: .sleeping)
        }
    }
}
