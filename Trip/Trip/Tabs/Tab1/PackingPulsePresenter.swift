

import SwiftUI
import Combine

// MARK: - Packing Pulse Presenter

final class PackingPulsePresenter: ObservableObject {

    // MARK: — Dependencies (storage in extension for rebind support)

    private var cancellables = Set<AnyCancellable>()

    // MARK: — Published State

    @Published var activeSessions: [PackingHeartbeat] = []
    @Published var archivedSessions: [PackingHeartbeat] = []
    @Published var searchQuery: String = ""
    @Published var sortMode: SessionSortMode = .departureAsc
    @Published var showArchive: Bool = false
    @Published var userLevel: Int = 1
    @Published var userLevelTitle: String = "Novice Packer"
    @Published var userEmoji: String = "🧳"
    @Published var totalPackedCount: Int = 0

    // MARK: — Creation Form State

    @Published var draftTitle: String = ""
    @Published var draftArchetype: JourneyArchetype = .urbanExplorer
    @Published var draftDeparture: Date = Calendar.current.date(
        byAdding: .hour, value: 24, to: Date()
    ) ?? Date()
    @Published var draftConditions: Set<UUID> = []

    // MARK: — Sort Modes

    enum SessionSortMode: String, CaseIterable, Identifiable {
        case departureAsc  = "departure_asc"
        case departureDsc  = "departure_dsc"
        case createdRecent = "created_recent"
        case nameAlpha     = "name_alpha"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .departureAsc:  return "Departure ↑"
            case .departureDsc:  return "Departure ↓"
            case .createdRecent: return "Recently Created"
            case .nameAlpha:     return "Name A–Z"
            }
        }
    }

    // MARK: — Init

    init(vault: VitalDataVault, router: VitalRouter) {
        self.vaultStorage = vault
        self.routerStorage = router
        bindToVault()
    }

    // MARK: — Vault Binding

    func bindToVault() {
        // React to session changes
        vault.$heartbeats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSessionLists()
            }
            .store(in: &cancellables)

        // React to identity changes
        vault.$identity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] identity in
                self?.userLevel = identity.vitalLevel
                self?.userLevelTitle = identity.levelTitle
                self?.userEmoji = identity.avatarEmoji
                self?.totalPackedCount = identity.totalItemsPacked
            }
            .store(in: &cancellables)

        // Search query filtering
        $searchQuery
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSessionLists()
            }
            .store(in: &cancellables)

        $sortMode
            .sink { [weak self] _ in
                self?.refreshSessionLists()
            }
            .store(in: &cancellables)

        refreshSessionLists()
    }

    // MARK: — Refresh & Filter

    private func refreshSessionLists() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Active sessions
        var active = vault.activeHeartbeats
        if !query.isEmpty {
            active = active.filter { $0.title.lowercased().contains(query) }
        }
        activeSessions = sortSessions(active)

        // Archived sessions
        var archived = vault.archivedHeartbeats
        if !query.isEmpty {
            archived = archived.filter { $0.title.lowercased().contains(query) }
        }
        archivedSessions = archived
    }

    private func sortSessions(_ sessions: [PackingHeartbeat]) -> [PackingHeartbeat] {
        switch sortMode {
        case .departureAsc:
            return sessions.sorted { $0.departureEpoch < $1.departureEpoch }
        case .departureDsc:
            return sessions.sorted { $0.departureEpoch > $1.departureEpoch }
        case .createdRecent:
            return sessions.sorted { $0.createdEpoch > $1.createdEpoch }
        case .nameAlpha:
            return sessions.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    // MARK: — Session Actions

    func openSession(_ session: PackingHeartbeat) {
        router.navigateTo(.sessionDetail(sessionID: session.id))
    }

    func presentCreateSheet() {
        resetDraft()
        router.presentSheet(.createSession)
    }

    func createSession() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let session = vault.createHeartbeat(
            title: title,
            archetype: draftArchetype,
            departure: draftDeparture,
            conditionIDs: draftConditions
        )

        router.dismissSheet()
        router.showToast("Session created!", style: .success)

        // Navigate to the new session after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.router.navigateTo(.sessionDetail(sessionID: session.id))
        }
    }

    func duplicateSession(_ session: PackingHeartbeat) {
        if let copy = vault.duplicateHeartbeat(id: session.id) {
            router.showToast("Session duplicated", style: .info)
        }
    }

    func archiveSession(_ session: PackingHeartbeat) {
        router.showAlert(.confirmArchiveSession(sessionID: session.id))
    }

    func deleteSession(_ session: PackingHeartbeat) {
        router.showAlert(.confirmDeleteSession(sessionID: session.id))
    }

    func unarchiveSession(_ session: PackingHeartbeat) {
        if var s = vault.heartbeat(byID: session.id) {
            s.isArchived = false
            vault.updateHeartbeat(s)
            router.showToast("Session restored", style: .success)
        }
    }

    // MARK: — Draft Management

    private func resetDraft() {
        draftTitle = ""
        draftArchetype = .urbanExplorer
        draftDeparture = Calendar.current.date(
            byAdding: .hour, value: 24, to: Date()
        ) ?? Date()
        draftConditions = []
    }

    // MARK: — Countdown Formatting

    func countdownText(for session: PackingHeartbeat) -> String {
        let now = Date()
        let departure = session.departureEpoch

        guard departure > now else {
            return "Departed"
        }

        let interval = departure.timeIntervalSince(now)

        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m left"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m left"
        } else {
            let days = Int(interval / 86400)
            let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
            return "\(days)d \(hours)h left"
        }
    }

    /// Urgency level for visual styling.
    func urgencyLevel(for session: PackingHeartbeat) -> UrgencyTier {
        let interval = session.departureEpoch.timeIntervalSince(Date())

        if interval <= 0                 { return .departed }
        if interval < 2 * 3600          { return .critical }    // < 2h
        if interval < 6 * 3600          { return .pressing }    // < 6h
        if interval < 24 * 3600         { return .approaching } // < 24h
        return .comfortable
    }

    enum UrgencyTier {
        case comfortable
        case approaching
        case pressing
        case critical
        case departed

        var accentColor: Color {
            switch self {
            case .comfortable:  return VitalPalette.verdantPulse
            case .approaching:  return VitalPalette.honeyElixir
            case .pressing:     return VitalPalette.feverSignal
            case .critical:     return VitalPalette.emberCore
            case .departed:     return VitalPalette.ashVeil
            }
        }

        var icon: String {
            switch self {
            case .comfortable:  return "clock"
            case .approaching:  return "clock.badge"
            case .pressing:     return "clock.badge.exclamationmark"
            case .critical:     return "exclamationmark.triangle.fill"
            case .departed:     return "checkmark.circle"
            }
        }
    }

    // MARK: — Progress Helpers

    func progressColor(for session: PackingHeartbeat) -> Color {
        let fraction = session.vitalSigns.progressFraction
        if fraction >= 1.0 { return VitalPalette.verdantPulse }
        if fraction >= 0.7 { return VitalPalette.aureliaGlow }
        if fraction >= 0.4 { return VitalPalette.honeyElixir }
        return VitalPalette.feverSignal
    }

    func progressText(for session: PackingHeartbeat) -> String {
        let signs = session.vitalSigns
        return "\(signs.packedCells)/\(signs.totalCells) packed"
    }

    func criticalText(for session: PackingHeartbeat) -> String? {
        let remaining = session.vitalSigns.criticalRemaining
        guard remaining > 0 else { return nil }
        return "\(remaining) critical left"
    }

    // MARK: — Gamification

    var levelProgressFraction: Double {
        let identity = vault.identity
        let thresholds: [Int] = [0, 25, 100, 300, 750, 1500, 3000]
        let currentLevel = identity.vitalLevel
        let levelIndex = min(currentLevel, thresholds.count - 1)
        let nextIndex = min(currentLevel + 1, thresholds.count - 1)

        guard nextIndex > levelIndex else { return 1.0 }

        let currentThreshold = thresholds[levelIndex - 1]
        let nextThreshold = thresholds[nextIndex - 1]
        let progress = identity.totalItemsPacked - currentThreshold
        let range = nextThreshold - currentThreshold

        guard range > 0 else { return 1.0 }
        return min(Double(progress) / Double(range), 1.0)
    }

    var nextLevelItemsNeeded: Int {
        let identity = vault.identity
        let thresholds: [Int] = [25, 100, 300, 750, 1500, 3000]
        let levelIndex = min(identity.vitalLevel - 1, thresholds.count - 1)
        return max(thresholds[levelIndex] - identity.totalItemsPacked, 0)
    }

    // MARK: — Empty State

    var hasAnySessions: Bool {
        !vault.heartbeats.isEmpty
    }

    var emptyStateMessage: String {
        if !searchQuery.isEmpty {
            return "No sessions match your search"
        }
        return "Your packing journey begins here"
    }

    var emptyStateSubtitle: String {
        if !searchQuery.isEmpty {
            return "Try a different search term"
        }
        return "Tap the button below to create\nyour first smart packing session"
    }
}
