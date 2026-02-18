// SessionHeartbeatPresenter.swift
// c13 — Smart Packing Companion
//
// VIPER Presenter for the Session Detail screen (C2).
// Manages items display, filtering, packing toggles, countdown,
// conditions, bulk section actions, share, and progress tracking.

import SwiftUI
import Combine

// MARK: - Session Heartbeat Presenter

final class SessionHeartbeatPresenter: ObservableObject {

    // MARK: — Dependencies

    private var vault: VitalDataVault
    private var router: VitalRouter
    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?

    let sessionID: UUID

    // MARK: — Published State: Session Header

    @Published var sessionTitle: String = ""
    @Published var archetypeDisplay: String = ""
    @Published var archetypeIcon: String = "suitcase.fill"
    @Published var countdownText: String = ""
    @Published var countdownColor: Color = VitalPalette.boneMarrow
    @Published var departureDate: Date = Date()
    @Published var isArchived: Bool = false

    // MARK: — Published State: Progress

    @Published var totalCells: Int = 0
    @Published var packedCells: Int = 0
    @Published var remainingCells: Int = 0
    @Published var criticalRemaining: Int = 0
    @Published var ruleAddedCount: Int = 0
    @Published var progressFraction: Double = 0
    @Published var progressPercent: Int = 0

    // MARK: — Published State: Organs & Cells

    @Published var displayOrgans: [OrganDisplayModel] = []
    @Published var activeFilter: VitalFilter = .all
    @Published var searchQuery: String = ""
    @Published var expandedOrganIDs: Set<UUID> = []

    // MARK: — Published State: Conditions

    @Published var activeConditionIDs: Set<UUID> = []
    @Published var conditionDisplayList: [ConditionToggleModel] = []

    // MARK: — Published State: Editing

    @Published var addItemOrganID: UUID? = nil
    @Published var addItemName: String = ""
    @Published var addItemQuantity: Int = 1
    @Published var addItemIsCritical: Bool = false
    @Published var addItemNote: String = ""

    // MARK: — Display Models

    struct OrganDisplayModel: Identifiable {
        let id: UUID
        let designation: OrganDesignation
        let displayName: String
        let icon: String
        let totalCells: Int
        let packedCells: Int
        let criticalRemaining: Int
        let isComplete: Bool
        let progressFraction: Double
        var cells: [CellDisplayModel]
    }

    struct CellDisplayModel: Identifiable {
        let id: UUID
        let organID: UUID
        let name: String
        let quantity: Int
        let isPacked: Bool
        let isCritical: Bool
        let origin: CellOrigin
        let reasonPulse: String?
        let note: String?
        let hasRuleLineage: Bool
    }

    struct ConditionToggleModel: Identifiable {
        let id: UUID
        let name: String
        let icon: String
        let isActive: Bool
        let impactCount: Int
        let previewAdded: [String]
        let previewRemoved: [String]
    }

    // MARK: — Init

    init(sessionID: UUID, vault: VitalDataVault, router: VitalRouter) {
        self.sessionID = sessionID
        self.vault = vault
        self.router = router
        bindToVault()
        startCountdownTimer()
    }

    func rebind(vault: VitalDataVault, router: VitalRouter) {
        self.vault = vault
        self.router = router
        cancellables.removeAll()
        bindToVault()
        startCountdownTimer()
    }

    // MARK: — Vault Binding

    private func bindToVault() {
        vault.$heartbeats
            .combineLatest(
                $activeFilter,
                $searchQuery.debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.rebuildDisplay()
            }
            .store(in: &cancellables)

        rebuildDisplay()
    }

    // MARK: — Rebuild Display

    private func rebuildDisplay() {
        guard let session = vault.heartbeat(byID: sessionID) else { return }

        // Header
        sessionTitle = session.title
        archetypeDisplay = session.archetype.displayName
        archetypeIcon = session.archetype.icon
        departureDate = session.departureEpoch
        isArchived = session.isArchived

        // Progress
        let signs = session.vitalSigns
        totalCells = signs.totalCells
        packedCells = signs.packedCells
        remainingCells = signs.remainingCells
        criticalRemaining = signs.criticalRemaining
        ruleAddedCount = signs.ruleAddedCount
        progressFraction = signs.progressFraction
        progressPercent = signs.progressPercent

        // Conditions
        activeConditionIDs = session.activeConditionIDs
        rebuildConditionList(session: session)

        // Organs
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        displayOrgans = session.organs.map { organ in
            let filteredCells = organ.cells
                .filter { cell in applyFilter(cell: cell) }
                .filter { cell in
                    query.isEmpty || cell.name.lowercased().contains(query)
                }
                .map { cell in
                    CellDisplayModel(
                        id: cell.id,
                        organID: organ.id,
                        name: cell.name,
                        quantity: cell.quantity,
                        isPacked: cell.isPacked,
                        isCritical: cell.isCritical,
                        origin: cell.origin,
                        reasonPulse: cell.reasonPulse,
                        note: cell.note,
                        hasRuleLineage: !cell.ruleLineage.isEmpty
                    )
                }

            return OrganDisplayModel(
                id: organ.id,
                designation: organ.designation,
                displayName: organ.displayName,
                icon: organ.designation.icon,
                totalCells: organ.organVitals.totalCells,
                packedCells: organ.organVitals.packedCells,
                criticalRemaining: organ.organVitals.criticalRemaining,
                isComplete: organ.organVitals.isComplete,
                progressFraction: organ.organVitals.progressFraction,
                cells: filteredCells
            )
        }
        .filter { !$0.cells.isEmpty || activeFilter == .all }

        // Auto-expand all organs on first load
        if expandedOrganIDs.isEmpty {
            expandedOrganIDs = Set(displayOrgans.map { $0.id })
        }
    }

    private func applyFilter(cell: PackingCell) -> Bool {
        switch activeFilter {
        case .all:          return true
        case .unpacked:     return !cell.isPacked
        case .packed:       return cell.isPacked
        case .critical:     return cell.isCritical && !cell.isPacked
        case .ruleInjected: return cell.origin == .ruleInjected
        }
    }

    // MARK: — Condition List Rebuild

    private func rebuildConditionList(session: PackingHeartbeat) {
        conditionDisplayList = vault.conditionBank.map { condition in
            let isActive = session.activeConditionIDs.contains(condition.id)
            let preview = vault.previewConditionDelta(conditionID: condition.id, sessionID: sessionID)
            let nerves = vault.nervesForCondition(condition.id)
            let addCount = nerves.filter { $0.action == .addItem }.count

            return ConditionToggleModel(
                id: condition.id,
                name: condition.name,
                icon: condition.icon,
                isActive: isActive,
                impactCount: addCount,
                previewAdded: preview.added,
                previewRemoved: preview.removed
            )
        }
    }

    // MARK: — Countdown Timer

    private func startCountdownTimer() {
        timerCancellable?.cancel()
        updateCountdown()

        timerCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCountdown()
            }
    }

    private func updateCountdown() {
        guard let session = vault.heartbeat(byID: sessionID) else { return }

        let now = Date()
        let departure = session.departureEpoch

        guard departure > now else {
            countdownText = "Departed"
            countdownColor = VitalPalette.ashVeil
            return
        }

        let interval = departure.timeIntervalSince(now)

        if interval < 2 * 3600 {
            countdownColor = VitalPalette.emberCore
        } else if interval < 6 * 3600 {
            countdownColor = VitalPalette.feverSignal
        } else if interval < 24 * 3600 {
            countdownColor = VitalPalette.honeyElixir
        } else {
            countdownColor = VitalPalette.verdantPulse
        }

        if interval < 3600 {
            let min = Int(interval / 60)
            countdownText = "\(min)m until departure"
        } else if interval < 86400 {
            let hrs = Int(interval / 3600)
            let min = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            countdownText = "\(hrs)h \(min)m until departure"
        } else {
            let days = Int(interval / 86400)
            let hrs = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
            countdownText = "\(days)d \(hrs)h until departure"
        }
    }

    // =========================================================================
    // MARK: — Item Actions
    // =========================================================================

    func toggleCellPacked(_ cellID: UUID, organID: UUID) {
        vault.toggleCellPacked(sessionID: sessionID, organID: organID, cellID: cellID)
    }

    func toggleCellCritical(_ cellID: UUID, organID: UUID) {
        vault.toggleCellCritical(sessionID: sessionID, organID: organID, cellID: cellID)
    }

    func deleteCell(_ cellID: UUID, organID: UUID) {
        router.showAlert(.confirmDeleteItem(sessionID: sessionID, organID: organID, cellID: cellID))
    }

    func showItemReason(_ cellID: UUID, organID: UUID) {
        router.presentSheet(.itemReason(sessionID: sessionID, organID: organID, cellID: cellID))
    }

    func presentEditItem(cellID: UUID, organID: UUID) {
        router.presentSheet(.editItem(sessionID: sessionID, organID: organID, cellID: cellID))
    }

    // =========================================================================
    // MARK: — Add Item
    // =========================================================================

    func presentAddItem(preselectedOrganID: UUID? = nil) {
        addItemOrganID = preselectedOrganID ?? displayOrgans.first?.id
        addItemName = ""
        addItemQuantity = 1
        addItemIsCritical = false
        addItemNote = ""
        router.presentSheet(.addItem(sessionID: sessionID, preselectedOrganID: preselectedOrganID))
    }

    func saveNewItem() {
        let name = addItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let organID = addItemOrganID else { return }

        vault.addCell(
            sessionID: sessionID,
            organID: organID,
            name: name,
            quantity: addItemQuantity,
            isCritical: addItemIsCritical,
            note: addItemNote.isEmpty ? nil : addItemNote
        )

        router.dismissSheet()
        router.showToast("Item added", style: .success)
    }

    // =========================================================================
    // MARK: — Organ (Section) Actions
    // =========================================================================

    func toggleOrganExpanded(_ organID: UUID) {
        if expandedOrganIDs.contains(organID) {
            expandedOrganIDs.remove(organID)
        } else {
            expandedOrganIDs.insert(organID)
        }
    }

    func markOrganComplete(_ organID: UUID) {
        router.showAlert(.confirmBulkMark(sessionID: sessionID, organID: organID))
    }

    func resetOrgan(_ organID: UUID) {
        router.showAlert(.confirmResetOrgan(sessionID: sessionID, organID: organID))
    }

    func presentEditOrgan(_ organID: UUID) {
        router.presentSheet(.editOrgan(sessionID: sessionID, organID: organID))
    }

    // =========================================================================
    // MARK: — Conditions
    // =========================================================================

    func presentConditionsSheet() {
        router.presentSheet(.sessionConditions(sessionID: sessionID))
    }

    func toggleCondition(_ conditionID: UUID) {
        vault.toggleCondition(conditionID: conditionID, sessionID: sessionID)
        rebuildDisplay()
    }

    // =========================================================================
    // MARK: — Reminders
    // =========================================================================

    func presentRemindersSheet() {
        router.presentSheet(.sessionReminders(sessionID: sessionID))
    }

    func presentEditSessionSheet() {
        router.presentSheet(.editSession(sessionID: sessionID))
    }

    // =========================================================================
    // MARK: — Session Management
    // =========================================================================

    func archiveSession() {
        router.showAlert(.confirmArchiveSession(sessionID: sessionID))
    }

    func deleteSession() {
        router.showAlert(.confirmDeleteSession(sessionID: sessionID))
    }

    func shareSession() {
        router.presentSheet(.shareSession(sessionID: sessionID))
    }

    // =========================================================================
    // MARK: — Filter Helpers
    // =========================================================================

    func filterCount(for filter: VitalFilter) -> Int {
        guard let session = vault.heartbeat(byID: sessionID) else { return 0 }
        let allCells = session.organs.flatMap { $0.cells }

        switch filter {
        case .all:          return allCells.count
        case .unpacked:     return allCells.filter { !$0.isPacked }.count
        case .packed:       return allCells.filter { $0.isPacked }.count
        case .critical:     return allCells.filter { $0.isCritical && !$0.isPacked }.count
        case .ruleInjected: return allCells.filter { $0.origin == .ruleInjected }.count
        }
    }

    // =========================================================================
    // MARK: — Progress Helpers
    // =========================================================================

    var progressColor: Color {
        if progressFraction >= 1.0 { return VitalPalette.verdantPulse }
        if progressFraction >= 0.7 { return VitalPalette.aureliaGlow }
        if progressFraction >= 0.4 { return VitalPalette.honeyElixir }
        return VitalPalette.feverSignal
    }

    var progressMessage: String {
        if progressFraction >= 1.0 { return "All packed! You're ready." }
        if progressFraction >= 0.8 { return "Almost there — just a few left." }
        if progressFraction >= 0.5 { return "Halfway through. Keep going!" }
        if progressFraction >= 0.2 { return "Good start. Many items to go." }
        return "Let's begin packing!"
    }

    var criticalWarning: String? {
        guard criticalRemaining > 0 else { return nil }
        if criticalRemaining == 1 { return "1 critical item still unpacked" }
        return "\(criticalRemaining) critical items still unpacked"
    }

    // =========================================================================
    // MARK: — Cleanup
    // =========================================================================

    deinit {
        timerCancellable?.cancel()
    }
}
