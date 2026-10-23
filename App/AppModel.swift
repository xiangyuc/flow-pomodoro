import AppKit
import FlowCore
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppModel {
    enum Screen {
        case timer
        case settings
    }

    struct MenuBarState {
        var icon: MenuBarIcon.Kind
        var text: String?
    }

    private(set) var engine: TimerEngine
    private(set) var now = Date()
    private(set) var records: [SessionRecord]
    /// While set and in the future, the menu bar icon shows the moss "minimum reached" tint.
    private(set) var cueUntil: Date? = nil

    var screen: Screen = .timer
    /// The one-line "where to pick up" note, shown during the break and when you come back.
    /// It is used once: starting the next session moves it into `activeNote` and clears it.
    var parkedNote: String {
        didSet { defaults.set(parkedNote, forKey: Keys.note) }
    }
    /// The note the current session started from, shown as "Working on".
    private(set) var activeNote = ""
    /// What is being typed on the parking screen.
    var draftNote = ""

    var minimumMinutes: Int {
        didSet { defaults.set(minimumMinutes, forKey: Keys.minimum); applySettings() }
    }
    var breakRatio: Int {
        didSet { defaults.set(breakRatio, forKey: Keys.ratio); applySettings() }
    }
    var ceilingMinutes: Int {
        didSet { defaults.set(ceilingMinutes, forKey: Keys.ceiling); applySettings() }
    }
    var chimeEnabled: Bool {
        didSet { defaults.set(chimeEnabled, forKey: Keys.chime) }
    }
    var openAtLogin: Bool {
        didSet { updateLoginItem() }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let store = HistoryStore(url: HistoryStore.defaultURL())
    @ObservationIgnored private let notifier: Notifier
    @ObservationIgnored private let statsWindow: StatsWindowController
    @ObservationIgnored private var ticker: Timer?

    private enum Keys {
        static let minimum = "minimumMinutes"
        static let ratio = "breakRatio"
        static let ceiling = "ceilingMinutes"
        static let chime = "chimeEnabled"
        static let note = "parkedNote"
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Keys.minimum: 25, Keys.ratio: 5, Keys.ceiling: 90, Keys.chime: true])
        minimumMinutes = defaults.integer(forKey: Keys.minimum)
        breakRatio = defaults.integer(forKey: Keys.ratio)
        ceilingMinutes = defaults.integer(forKey: Keys.ceiling)
        chimeEnabled = defaults.bool(forKey: Keys.chime)
        parkedNote = defaults.string(forKey: Keys.note) ?? ""
        openAtLogin = SMAppService.mainApp.status == .enabled
        records = HistoryStore(url: HistoryStore.defaultURL()).load()
        engine = TimerEngine(settings: Self.settings(
            minimum: defaults.integer(forKey: Keys.minimum),
            ratio: defaults.integer(forKey: Keys.ratio),
            ceiling: defaults.integer(forKey: Keys.ceiling)
        ))
        notifier = Notifier()
        statsWindow = StatsWindowController()

        notifier.onAction = { [weak self] action in self?.handle(action) }
        notifier.requestAuthorization()
        startTicker()
    }

    // MARK: Actions

    func start() {
        now = Date()
        cueUntil = nil
        screen = .timer
        activeNote = parkedNote
        parkedNote = ""
        engine.startFocus(at: now)
    }

    func pause() {
        now = Date()
        engine.pause(at: now)
    }

    func resume() {
        now = Date()
        engine.resume(at: now)
    }

    func end() {
        now = Date()
        if let record = engine.endFocus(at: now) { append(record) }
        activeNote = ""
    }

    func wrapUp() {
        now = Date()
        engine.wrapUp(at: now)
    }

    func takeBreak() {
        now = Date()
        if let record = engine.takeBreak(at: now) { append(record) }
        draftNote = ""
        activeNote = ""
        notifier.clearCeilingNudge()
    }

    func startBreak(savingNote: Bool) {
        if savingNote {
            let note = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty { parkedNote = note }
        }
        now = Date()
        engine.startBreak(at: now)
    }

    func endBreak() {
        engine.endBreak()
    }

    func showStats() {
        statsWindow.show(model: self)
    }

    func quit() {
        // Keep the focus time already spent in this session.
        end()
        NSApp.terminate(nil)
    }

    // MARK: Derived state

    func summary(for range: StatsRange) -> StatsSummary {
        StatsCalculator.summary(of: records, range: range, now: now)
    }

    var menuBarState: MenuBarState {
        switch engine.phase {
        case .idle:
            return MenuBarState(icon: .idle)
        case .focusing(let session):
            let elapsed = session.elapsed(at: now)
            let minimum = engine.settings.minimumFocus
            if let cueUntil, now < cueUntil {
                return MenuBarState(icon: .cue, text: DurationFormat.clock(elapsed))
            }
            if elapsed < minimum {
                let remaining = minimum - elapsed
                return MenuBarState(icon: .focus(remaining: remaining / minimum), text: DurationFormat.countdown(remaining))
            }
            return MenuBarState(icon: .flow, text: DurationFormat.clock(elapsed))
        case .parking:
            return MenuBarState(icon: .rest)
        case .onBreak(let breakSession):
            return MenuBarState(icon: .rest, text: DurationFormat.countdown(breakSession.remaining(at: now)))
        }
    }

    // MARK: Timer

    private func startTicker() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        now = Date()
        for event in engine.tick(at: now) {
            handle(event)
        }
    }

    private func handle(_ event: EngineEvent) {
        switch event {
        case .reachedMinimum:
            // The core idea: a quiet cue, never an interruption.
            cueUntil = now.addingTimeInterval(3)
            if chimeEnabled { Sound.minimum.play() }
        case .ceilingNudge(let focused):
            notifier.postCeilingNudge(focused: focused, earnedBreak: engine.settings.earnedBreak(for: focused))
        case .wrapUpEnded:
            draftNote = ""
            activeNote = ""
            if chimeEnabled { Sound.minimum.play() }
            if case .parking(let parked) = engine.phase {
                notifier.postWrapUpEnded(earnedBreak: parked.earnedBreak)
            }
        case .sessionCompleted(let record):
            append(record)
        case .breakEnded:
            if chimeEnabled { Sound.breakEnded.play() }
            notifier.postBreakEnded(note: parkedNote)
            screen = .timer
        }
    }

    private func handle(_ action: Notifier.Action) {
        switch action {
        case .takeBreak:
            takeBreak()
            startBreak(savingNote: false)
        case .snooze:
            now = Date()
            engine.snoozeCeiling(at: now)
        case .startBreak:
            startBreak(savingNote: false)
        }
    }

    // MARK: Persistence

    private func append(_ record: SessionRecord) {
        records.append(record)
        do {
            try store.save(records)
        } catch {
            NSLog("Flow Pomodoro: could not save history: \(error)")
        }
    }

    private func applySettings() {
        engine.settings = Self.settings(minimum: minimumMinutes, ratio: breakRatio, ceiling: ceilingMinutes)
    }

    private static func settings(minimum: Int, ratio: Int, ceiling: Int) -> FlowSettings {
        FlowSettings(
            minimumFocus: TimeInterval(minimum * 60),
            breakRatio: Double(ratio),
            ceiling: TimeInterval(ceiling * 60)
        )
    }

    private func updateLoginItem() {
        do {
            if openAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Flow Pomodoro: could not update login item: \(error)")
        }
    }
}

/// Soft system sounds: a wood-like tick at the minimum, a glass chime when a break ends.
private enum Sound {
    case minimum
    case breakEnded

    func play() {
        let name = self == .minimum ? "Tink" : "Glass"
        NSSound(named: name)?.play()
    }
}
