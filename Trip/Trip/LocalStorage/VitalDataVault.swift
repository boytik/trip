

import Foundation
import Combine

// MARK: - Data Vault (Singleton)

/// Manages sessions, conditions, rules, user identity, and statistics.
final class VitalDataVault: ObservableObject {

    static let shared = VitalDataVault()

    // MARK: — Published State

    @Published var heartbeats: [PackingHeartbeat] = []         // All sessions
    @Published var conditionBank: [ConditionTrigger] = []      // All conditions
    @Published var nerveLibrary: [DependencyNerve] = []        // All rules
    @Published var identity: VitalIdentity = VitalIdentity()
    @Published var statistics: VitalStatistics = VitalStatistics()
    @Published var onboardingVitals: OnboardingVitals = OnboardingVitals()

    // MARK: — File Paths

    private let vaultQueue = DispatchQueue(label: "com.c13.vitalVault", qos: .userInitiated)

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var sessionsFileURL: URL    { documentsURL.appendingPathComponent("vital_heartbeats.json") }
    private var conditionsFileURL: URL  { documentsURL.appendingPathComponent("vital_conditions.json") }
    private var nervesFileURL: URL      { documentsURL.appendingPathComponent("vital_nerves.json") }
    private var identityFileURL: URL    { documentsURL.appendingPathComponent("vital_identity.json") }
    private var statisticsFileURL: URL  { documentsURL.appendingPathComponent("vital_statistics.json") }
    private var onboardingFileURL: URL  { documentsURL.appendingPathComponent("vital_onboarding.json") }

    // MARK: — Init

    private init() {
        loadAll()
        seedBuiltInDataIfNeeded()
    }

    // MARK: — Load All

    func loadAll() {
        heartbeats = load(from: sessionsFileURL) ?? []
        conditionBank = load(from: conditionsFileURL) ?? []
        nerveLibrary = load(from: nervesFileURL) ?? []
        identity = load(from: identityFileURL) ?? VitalIdentity()
        statistics = load(from: statisticsFileURL) ?? VitalStatistics()
        onboardingVitals = load(from: onboardingFileURL) ?? OnboardingVitals()
    }

    // MARK: — Generic JSON Read / Write

    private func load<T: Codable>(from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[VitalDataVault] Load error at \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    private func save<T: Codable>(_ object: T, to url: URL) {
        vaultQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(object)
                try data.write(to: url, options: .atomic)
            } catch {
                print("[VitalDataVault] Save error at \(url.lastPathComponent): \(error)")
            }
        }
    }

    private func persistSessions()   { save(heartbeats, to: sessionsFileURL) }
    private func persistConditions() { save(conditionBank, to: conditionsFileURL) }
    private func persistNerves()     { save(nerveLibrary, to: nervesFileURL) }
    private func persistIdentity()   { save(identity, to: identityFileURL) }
    private func persistStatistics() { save(statistics, to: statisticsFileURL) }
    private func persistOnboarding() { save(onboardingVitals, to: onboardingFileURL) }

    // =========================================================================
    // MARK: — SESSION CRUD
    // =========================================================================

    /// Creates a new packing session seeded with template items for the archetype.
    @discardableResult
    func createHeartbeat(
        title: String,
        archetype: JourneyArchetype,
        departure: Date,
        conditionIDs: Set<UUID> = []
    ) -> PackingHeartbeat {

        let organs = TemplateNursery.seedOrgans(for: archetype)
        var session = PackingHeartbeat(
            title: title,
            archetype: archetype,
            departureEpoch: departure,
            organs: organs,
            activeConditionIDs: conditionIDs
        )

        // Apply initial conditions
        for condID in conditionIDs {
            applyConditionRules(conditionID: condID, to: &session)
        }

        recalculateVitalSigns(for: &session)

        heartbeats.insert(session, at: 0)
        identity.totalSessionsCreated += 1
        statistics.totalTrips += 1

        persistSessions()
        persistIdentity()
        persistStatistics()

        return session
    }

    /// Returns active (non-archived) sessions sorted by departure.
    var activeHeartbeats: [PackingHeartbeat] {
        heartbeats
            .filter { !$0.isArchived }
            .sorted { $0.departureEpoch < $1.departureEpoch }
    }

    /// Returns archived sessions.
    var archivedHeartbeats: [PackingHeartbeat] {
        heartbeats
            .filter { $0.isArchived }
            .sorted { $0.departureEpoch > $1.departureEpoch }
    }

    func heartbeat(byID id: UUID) -> PackingHeartbeat? {
        heartbeats.first { $0.id == id }
    }

    func updateHeartbeat(_ session: PackingHeartbeat) {
        if let idx = heartbeats.firstIndex(where: { $0.id == session.id }) {
            heartbeats[idx] = session
            persistSessions()
        }
    }

    func archiveHeartbeat(id: UUID) {
        if let idx = heartbeats.firstIndex(where: { $0.id == id }) {
            heartbeats[idx].isArchived = true
            persistSessions()
        }
    }

    func deleteHeartbeat(id: UUID) {
        heartbeats.removeAll { $0.id == id }
        persistSessions()
    }

    func duplicateHeartbeat(id: UUID) -> PackingHeartbeat? {
        guard var original = heartbeat(byID: id) else { return nil }
        var copy = original
        copy = PackingHeartbeat(
            title: original.title + " (copy)",
            archetype: original.archetype,
            departureEpoch: original.departureEpoch,
            organs: original.organs.map { organ in
                var newOrgan = PackingOrgan(designation: organ.designation, sortIndex: organ.sortIndex)
                newOrgan.cells = organ.cells.map { cell in
                    var newCell = PackingCell(
                        name: cell.name,
                        quantity: cell.quantity,
                        isCritical: cell.isCritical,
                        origin: cell.origin,
                        note: cell.note
                    )
                    newCell.reasonPulse = cell.reasonPulse
                    return newCell
                }
                return newOrgan
            },
            activeConditionIDs: original.activeConditionIDs
        )
        recalculateVitalSigns(for: &copy)
        heartbeats.insert(copy, at: 0)
        persistSessions()
        return copy
    }

    // =========================================================================
    // MARK: — ITEM (CELL) OPERATIONS
    // =========================================================================

    /// Toggle packed status of a single item.
    func toggleCellPacked(sessionID: UUID, organID: UUID, cellID: UUID) {
        guard let sIdx = heartbeats.firstIndex(where: { $0.id == sessionID }),
              let oIdx = heartbeats[sIdx].organs.firstIndex(where: { $0.id == organID }),
              let cIdx = heartbeats[sIdx].organs[oIdx].cells.firstIndex(where: { $0.id == cellID })
        else { return }

        let wasPacked = heartbeats[sIdx].organs[oIdx].cells[cIdx].isPacked
        heartbeats[sIdx].organs[oIdx].cells[cIdx].isPacked = !wasPacked
        heartbeats[sIdx].organs[oIdx].cells[cIdx].packedEpoch = wasPacked ? nil : Date()

        if !wasPacked {
            identity.totalItemsPacked += 1
            statistics.totalItemsEverPacked += 1
            if heartbeats[sIdx].organs[oIdx].cells[cIdx].isCritical {
                statistics.criticalItemsSaved += 1
            }
        }

        recalculateVitalSigns(for: &heartbeats[sIdx])
        persistSessions()
        persistIdentity()
        persistStatistics()
    }

    /// Toggle critical flag on an item.
    func toggleCellCritical(sessionID: UUID, organID: UUID, cellID: UUID) {
        guard let sIdx = heartbeats.firstIndex(where: { $0.id == sessionID }),
              let oIdx = heartbeats[sIdx].organs.firstIndex(where: { $0.id == organID }),
              let cIdx = heartbeats[sIdx].organs[oIdx].cells.firstIndex(where: { $0.id == cellID })
        else { return }

        heartbeats[sIdx].organs[oIdx].cells[cIdx].isCritical.toggle()
        recalculateVitalSigns(for: &heartbeats[sIdx])
        persistSessions()
    }

    /// Restore a cell (for undo). Preserves id, origin, ruleLineage, etc.
    private func restoreCell(sessionID: UUID, organID: UUID, cell: PackingCell) {
        guard let sIdx = heartbeats.firstIndex(where: { $0.id == sessionID }),
              let oIdx = heartbeats[sIdx].organs.firstIndex(where: { $0.id == organID })
        else { return }

        heartbeats[sIdx].organs[oIdx].cells.append(cell)
        recalculateVitalSigns(for: &heartbeats[sIdx])
        objectWillChange.send()
        persistSessions()
    }

    /// Add a new item to a specific section.
    func addCell(
        sessionID: UUID,
        organID: UUID,
        name: String,
        quantity: Int = 1,
        isCritical: Bool = false,
        note: String? = nil
    ) {
        guard let sIdx = heartbeats.firstIndex(where: { $0.id == sessionID }),
              let oIdx = heartbeats[sIdx].organs.firstIndex(where: { $0.id == organID })
        else { return }

        let cell = PackingCell(
            name: name,
            quantity: quantity,
            isCritical: isCritical,
            origin: .userAdded,
            note: note
        )
        heartbeats[sIdx].organs[oIdx].cells.append(cell)
        recalculateVitalSigns(for: &heartbeats[sIdx])
        objectWillChange.send()
        persistSessions()
    }

    /// Update an existing item (name, quantity, note, organ/section).
    func updateCell(sessionID: UUID, organID: UUID, cellID: UUID, name: String, quantity: Int, note: String?, targetOrganID: UUID?) {
        guard let sIdx = heartbeats.firstIndex(where: { $0.id == sessionID }),
              let oIdx = heartbeats[sIdx].organs.firstIndex(where: { $0.id == organID }),
              let cIdx = heartbeats[sIdx].organs[oIdx].cells.firstIndex(where: { $0.id == cellID })
        else { return }

        let qty = max(1, quantity)
        let noteVal = note?.isEmpty == true ? nil : note

        if let targetOrganID = targetOrganID, targetOrganID != organID,
           let targetOIdx = heartbeats[sIdx].organs.firstIndex(where: { $0.id == targetOrganID }) {
            var cell = heartbeats[sIdx].organs[oIdx].cells.remove(at: cIdx)
            cell.name = name
            cell.quantity = qty
            cell.note = noteVal
            heartbeats[sIdx].organs[targetOIdx].cells.append(cell)
        } else {
            heartbeats[sIdx].organs[oIdx].cells[cIdx].name = name
            heartbeats[sIdx].organs[oIdx].cells[cIdx].quantity = qty
            heartbeats[sIdx].organs[oIdx].cells[cIdx].note = noteVal
        }

        recalculateVitalSigns(for: &heartbeats[sIdx])
        objectWillChange.send()
        persistSessions()
    }

    /// Delete an item from a section. Stores undo capsule for delete_item.
    func deleteCell(sessionID: UUID, organID: UUID, cellID: UUID) {
        guard let sIdx = heartbeats.firstIndex(where: { $0.id == sessionID }),
              let oIdx = heartbeats[sIdx].organs.firstIndex(where: { $0.id == organID }),
              let cellIdx = heartbeats[sIdx].organs[oIdx].cells.firstIndex(where: { $0.id == cellID })
        else { return }

        let cell = heartbeats[sIdx].organs[oIdx].cells[cellIdx]
        let payload = DeleteItemUndoPayload(sessionID: sessionID, organID: organID, cell: cell)
        if let data = try? JSONEncoder().encode(payload) {
            lastUndoCapsule = UndoCapsule(actionType: .deleteItem, timestamp: Date(), payload: data)
        }

        heartbeats[sIdx].organs[oIdx].cells.remove(at: cellIdx)
        recalculateVitalSigns(for: &heartbeats[sIdx])
        objectWillChange.send()
        persistSessions()
    }

    /// Last undoable action for rollback.
    private(set) var lastUndoCapsule: UndoCapsule?

    /// Performs undo for the given action tag. Returns true if undo was applied.
    @discardableResult
    func performUndo(actionTag: String) -> Bool {
        guard let capsule = lastUndoCapsule else { return false }
        let applied: Bool
        switch (actionTag, capsule.actionType) {
        case ("delete_item", .deleteItem):
            if let payload = try? JSONDecoder().decode(DeleteItemUndoPayload.self, from: capsule.payload) {
                restoreCell(sessionID: payload.sessionID, organID: payload.organID, cell: payload.cell)
                applied = true
            } else {
                applied = false
            }
        default:
            applied = false
        }
        if applied {
            lastUndoCapsule = nil
        }
        return applied
    }

    /// Bulk mark all items in a section as packed.
    func markOrganComplete(sessionID: UUID, organID: UUID) {
        guard let sIdx = heartbeats.firstIndex(where: { $0.id == sessionID }),
              let oIdx = heartbeats[sIdx].organs.firstIndex(where: { $0.id == organID })
        else { return }

        let now = Date()
        for cIdx in heartbeats[sIdx].organs[oIdx].cells.indices {
            if !heartbeats[sIdx].organs[oIdx].cells[cIdx].isPacked {
                heartbeats[sIdx].organs[oIdx].cells[cIdx].isPacked = true
                heartbeats[sIdx].organs[oIdx].cells[cIdx].packedEpoch = now
                identity.totalItemsPacked += 1
                statistics.totalItemsEverPacked += 1
            }
        }
        recalculateVitalSigns(for: &heartbeats[sIdx])
        persistSessions()
        persistIdentity()
        persistStatistics()
    }

    /// Reset all items in a section to unpacked.
    func resetOrgan(sessionID: UUID, organID: UUID) {
        guard let sIdx = heartbeats.firstIndex(where: { $0.id == sessionID }),
              let oIdx = heartbeats[sIdx].organs.firstIndex(where: { $0.id == organID })
        else { return }

        for cIdx in heartbeats[sIdx].organs[oIdx].cells.indices {
            heartbeats[sIdx].organs[oIdx].cells[cIdx].isPacked = false
            heartbeats[sIdx].organs[oIdx].cells[cIdx].packedEpoch = nil
        }
        recalculateVitalSigns(for: &heartbeats[sIdx])
        persistSessions()
    }

    // =========================================================================
    // MARK: — CONDITION OPERATIONS
    // =========================================================================

    /// Toggle a condition on/off for a specific session.
    func toggleCondition(conditionID: UUID, sessionID: UUID) {
        guard let sIdx = heartbeats.firstIndex(where: { $0.id == sessionID }) else { return }

        if heartbeats[sIdx].activeConditionIDs.contains(conditionID) {
            // Turning OFF — remove rule-injected items
            heartbeats[sIdx].activeConditionIDs.remove(conditionID)
            removeConditionItems(conditionID: conditionID, from: &heartbeats[sIdx])
        } else {
            // Turning ON — inject items via rules
            heartbeats[sIdx].activeConditionIDs.insert(conditionID)
            applyConditionRules(conditionID: conditionID, to: &heartbeats[sIdx])
        }

        recalculateVitalSigns(for: &heartbeats[sIdx])
        persistSessions()
    }

    /// Returns items that WOULD be added/removed by toggling a condition (preview).
    func previewConditionDelta(conditionID: UUID, sessionID: UUID) -> (added: [String], removed: [String]) {
        guard let session = heartbeat(byID: sessionID) else { return ([], []) }

        let isCurrentlyActive = session.activeConditionIDs.contains(conditionID)
        let matchingNerves = nerveLibrary.filter { $0.conditionID == conditionID }

        if isCurrentlyActive {
            // Preview removal
            let removable = matchingNerves.compactMap { nerve -> String? in
                for organ in session.organs {
                    if let cell = organ.cells.first(where: {
                        $0.ruleLineage.contains(nerve.id) && !$0.isPacked
                    }) {
                        return cell.name
                    }
                }
                return nil
            }
            return (added: [], removed: removable)
        } else {
            // Preview additions
            let addable = matchingNerves.compactMap { nerve -> String? in
                guard nerve.action == .addItem else { return nil }
                let exists = session.organs.contains { organ in
                    organ.cells.contains { $0.name.lowercased() == nerve.targetItemName.lowercased() }
                }
                return exists ? nil : nerve.targetItemName
            }
            return (added: addable, removed: [])
        }
    }

    private func applyConditionRules(conditionID: UUID, to session: inout PackingHeartbeat) {
        let matchingNerves = nerveLibrary
            .filter { $0.conditionID == conditionID }
            .sorted { $0.priority > $1.priority }

        for nerve in matchingNerves {
            // Check archetype mask
            if !nerve.archetypeMask.isEmpty &&
               !nerve.archetypeMask.contains(session.archetype.rawValue) {
                continue
            }

            guard let oIdx = session.organs.firstIndex(where: {
                $0.designation == nerve.targetOrgan
            }) else { continue }

            switch nerve.action {
            case .addItem:
                let alreadyExists = session.organs[oIdx].cells.contains {
                    $0.name.lowercased() == nerve.targetItemName.lowercased()
                }
                if !alreadyExists {
                    var newCell = PackingCell(
                        name: nerve.targetItemName,
                        isCritical: false,
                        origin: .ruleInjected
                    )
                    newCell.ruleLineage = [nerve.id]
                    newCell.reasonPulse = nerve.reasonText.isEmpty
                        ? "Added by condition"
                        : nerve.reasonText
                    session.organs[oIdx].cells.append(newCell)
                } else {
                    // Add lineage to existing
                    if let cIdx = session.organs[oIdx].cells.firstIndex(where: {
                        $0.name.lowercased() == nerve.targetItemName.lowercased()
                    }) {
                        if !session.organs[oIdx].cells[cIdx].ruleLineage.contains(nerve.id) {
                            session.organs[oIdx].cells[cIdx].ruleLineage.append(nerve.id)
                        }
                    }
                }

            case .makeCritical:
                if let cIdx = session.organs[oIdx].cells.firstIndex(where: {
                    $0.name.lowercased() == nerve.targetItemName.lowercased()
                }) {
                    session.organs[oIdx].cells[cIdx].isCritical = true
                    if !session.organs[oIdx].cells[cIdx].ruleLineage.contains(nerve.id) {
                        session.organs[oIdx].cells[cIdx].ruleLineage.append(nerve.id)
                    }
                }

            case .appendNote:
                if let cIdx = session.organs[oIdx].cells.firstIndex(where: {
                    $0.name.lowercased() == nerve.targetItemName.lowercased()
                }) {
                    let existing = session.organs[oIdx].cells[cIdx].note ?? ""
                    if !existing.contains(nerve.reasonText) {
                        session.organs[oIdx].cells[cIdx].note =
                            existing.isEmpty ? nerve.reasonText : existing + "; " + nerve.reasonText
                    }
                }
            }
        }
    }

    private func removeConditionItems(conditionID: UUID, from session: inout PackingHeartbeat) {
        let matchingNerveIDs = Set(nerveLibrary.filter { $0.conditionID == conditionID }.map { $0.id })
        let nerveMap = Dictionary(uniqueKeysWithValues: nerveLibrary.map { ($0.id, $0) })

        for oIdx in session.organs.indices {
            session.organs[oIdx].cells.removeAll { cell in
                guard cell.origin == .ruleInjected else { return false }
                let remainingLineage = cell.ruleLineage.filter { !matchingNerveIDs.contains($0) }

                if remainingLineage.isEmpty && !cell.isPacked {
                    // Check removal policy
                    let policy = cell.ruleLineage.compactMap { nerveMap[$0]?.removalPolicy }.first
                        ?? .removeIfNotPacked
                    switch policy {
                    case .removeIfNotPacked: return true
                    case .alwaysKeep:        return false
                    case .archive:           return true // simplified: treat as remove for now
                    }
                }
                return false
            }

            // Clean lineage references from remaining cells
            for cIdx in session.organs[oIdx].cells.indices {
                session.organs[oIdx].cells[cIdx].ruleLineage.removeAll {
                    matchingNerveIDs.contains($0)
                }
            }
        }
    }

    // =========================================================================
    // MARK: — VITAL SIGNS RECALCULATION
    // =========================================================================

    func recalculateVitalSigns(for session: inout PackingHeartbeat) {
        var totalCells = 0
        var packedCells = 0
        var criticalRemaining = 0
        var ruleAdded = 0

        for oIdx in session.organs.indices {
            var oTotal = 0
            var oPacked = 0
            var oCritRemaining = 0

            for cell in session.organs[oIdx].cells {
                oTotal += 1
                if cell.isPacked { oPacked += 1 }
                if cell.isCritical && !cell.isPacked { oCritRemaining += 1 }
                if cell.origin == .ruleInjected { ruleAdded += 1 }
            }

            session.organs[oIdx].organVitals = OrganVitalSigns(
                totalCells: oTotal,
                packedCells: oPacked,
                criticalRemaining: oCritRemaining
            )

            totalCells += oTotal
            packedCells += oPacked
            criticalRemaining += oCritRemaining
        }

        session.vitalSigns = SessionVitalSigns(
            totalCells: totalCells,
            packedCells: packedCells,
            criticalRemaining: criticalRemaining,
            ruleAddedCount: ruleAdded
        )

        // Update perfect pack streak
        if totalCells > 0 && packedCells == totalCells {
            identity.perfectPackStreak += 1
            identity.longestStreak = max(identity.longestStreak, identity.perfectPackStreak)
            statistics.perfectTrips += 1
            persistIdentity()
            persistStatistics()
        }
    }

    // =========================================================================
    // MARK: — CONDITION & RULE CRUD
    // =========================================================================

    func addCondition(_ condition: ConditionTrigger) {
        conditionBank.append(condition)
        persistConditions()
    }

    func deleteCondition(id: UUID) {
        conditionBank.removeAll { $0.id == id }
        nerveLibrary.removeAll { $0.conditionID == id }
        persistConditions()
        persistNerves()
    }

    func addNerve(_ nerve: DependencyNerve) {
        nerveLibrary.append(nerve)
        // Update rule count on condition
        if let idx = conditionBank.firstIndex(where: { $0.id == nerve.conditionID }) {
            conditionBank[idx].ruleCount = nerveLibrary.filter {
                $0.conditionID == nerve.conditionID
            }.count
        }
        persistNerves()
        persistConditions()
    }

    func deleteNerve(id: UUID) {
        let condID = nerveLibrary.first { $0.id == id }?.conditionID
        nerveLibrary.removeAll { $0.id == id }
        if let condID = condID, let idx = conditionBank.firstIndex(where: { $0.id == condID }) {
            conditionBank[idx].ruleCount = nerveLibrary.filter {
                $0.conditionID == condID
            }.count
        }
        persistNerves()
        persistConditions()
    }

    func nervesForCondition(_ conditionID: UUID) -> [DependencyNerve] {
        nerveLibrary
            .filter { $0.conditionID == conditionID }
            .sorted { $0.priority > $1.priority }
    }

    // =========================================================================
    // MARK: — IDENTITY & SETTINGS
    // =========================================================================

    func updateIdentity(_ newIdentity: VitalIdentity) {
        identity = newIdentity
        persistIdentity()
    }

    func completeOnboarding() {
        onboardingVitals.hasCompletedOnboarding = true
        persistOnboarding()
    }

    func resetAllData() {
        heartbeats = []
        conditionBank = []
        nerveLibrary = []
        identity = VitalIdentity()
        statistics = VitalStatistics()
        onboardingVitals = OnboardingVitals()

        persistSessions()
        persistConditions()
        persistNerves()
        persistIdentity()
        persistStatistics()
        persistOnboarding()

        seedBuiltInDataIfNeeded()
    }

    // =========================================================================
    // MARK: — SHARE
    // =========================================================================

    func buildSharePayload(sessionID: UUID) -> VitalSharePayload? {
        guard let session = heartbeat(byID: sessionID) else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let sections = session.organs.map { organ in
            (
                name: organ.displayName,
                items: organ.cells.map { cell in
                    let status = cell.isPacked ? "✅" : "⬜"
                    let critical = cell.isCritical ? " ⚠️" : ""
                    return "\(status) \(cell.name)\(critical)"
                }
            )
        }

        return VitalSharePayload(
            sessionTitle: session.title,
            archetype: session.archetype.displayName,
            departureDate: formatter.string(from: session.departureEpoch),
            sections: sections
        )
    }

    // =========================================================================
    // MARK: — SEED BUILT-IN DATA
    // =========================================================================

    private func seedBuiltInDataIfNeeded() {
        if conditionBank.isEmpty {
            conditionBank = BuiltInConditions.allConditions()
            persistConditions()
        }
        if nerveLibrary.isEmpty {
            nerveLibrary = BuiltInConditions.allNerves(conditions: conditionBank)
            persistNerves()
        }
    }
}

// MARK: - Template Nursery (Generates base items per archetype)

enum TemplateNursery {

    static func seedOrgans(for archetype: JourneyArchetype) -> [PackingOrgan] {
        let designations: [OrganDesignation] = [
            .documents, .clothing, .footwear, .hygiene, .firstAid, .gadgets, .provisions
        ]

        return designations.enumerated().map { index, designation in
            var organ = PackingOrgan(designation: designation, sortIndex: index)
            organ.cells = seedCells(for: designation, archetype: archetype)
            organ.organVitals = OrganVitalSigns(
                totalCells: organ.cells.count,
                packedCells: 0,
                criticalRemaining: organ.cells.filter { $0.isCritical }.count
            )
            return organ
        }
    }

    private static func seedCells(
        for designation: OrganDesignation,
        archetype: JourneyArchetype
    ) -> [PackingCell] {

        var items: [(String, Bool)] = [] // (name, isCritical)

        switch designation {
        case .documents:
            items = [
                ("Passport / ID", true),
                ("Tickets / Boarding Pass", true),
                ("Insurance Documents", true),
                ("Hotel Reservation", false),
                ("Cash / Cards", true),
                ("Emergency Contacts List", false)
            ]

        case .clothing:
            items = baseClothing(for: archetype)

        case .footwear:
            items = baseFootwear(for: archetype)

        case .hygiene:
            items = [
                ("Toothbrush & Paste", false),
                ("Shampoo & Conditioner", false),
                ("Deodorant", false),
                ("Sunscreen", false),
                ("Towel", false),
                ("Lip Balm", false)
            ]

        case .firstAid:
            items = [
                ("Band-Aids", false),
                ("Pain Relievers", false),
                ("Antiseptic Wipes", false),
                ("Personal Medications", true),
                ("Insect Repellent", false)
            ]

        case .gadgets:
            items = [
                ("Phone Charger", true),
                ("Power Bank", false),
                ("Headphones", false),
                ("Travel Adapter", false),
                ("Camera", false)
            ]

        case .provisions:
            items = [
                ("Water Bottle", false),
                ("Snacks", false),
                ("Reusable Bag", false)
            ]

        case .custom:
            items = []
        }

        return items.map { name, critical in
            PackingCell(name: name, isCritical: critical, origin: .templateSeeded)
        }
    }

    private static func baseClothing(for archetype: JourneyArchetype) -> [(String, Bool)] {
        var base: [(String, Bool)] = [
            ("T-Shirts", false),
            ("Underwear", false),
            ("Socks", false),
            ("Pants / Shorts", false),
            ("Sleepwear", false)
        ]

        switch archetype {
        case .urbanExplorer:
            base.append(("Light Jacket", false))
            base.append(("Smart Casual Outfit", false))
        case .coastalBreeze:
            base.append(("Swimsuit", false))
            base.append(("Cover-Up / Sarong", false))
            base.append(("Hat / Cap", false))
        case .alpineAscent:
            base.append(("Hiking Pants", false))
            base.append(("Fleece / Midlayer", false))
            base.append(("Rain Jacket", false))
            base.append(("Hat / Beanie", false))
        case .frostExpedition:
            base.append(("Thermal Base Layer", true))
            base.append(("Warm Jacket / Parka", true))
            base.append(("Gloves", false))
            base.append(("Warm Hat / Beanie", false))
            base.append(("Scarf / Neck Gaiter", false))
        }

        return base
    }

    private static func baseFootwear(for archetype: JourneyArchetype) -> [(String, Bool)] {
        switch archetype {
        case .urbanExplorer:
            return [
                ("Comfortable Walking Shoes", false),
                ("Casual / Evening Shoes", false)
            ]
        case .coastalBreeze:
            return [
                ("Sandals / Flip-Flops", false),
                ("Water Shoes", false),
                ("Light Sneakers", false)
            ]
        case .alpineAscent:
            return [
                ("Hiking Boots", true),
                ("Camp Sandals", false)
            ]
        case .frostExpedition:
            return [
                ("Insulated Boots", true),
                ("Warm Indoor Shoes", false)
            ]
        }
    }
}

// MARK: - Built-In Conditions & Rules

enum BuiltInConditions {

    static func allConditions() -> [ConditionTrigger] {
        [
            ConditionTrigger(name: "Rain Expected",        icon: "cloud.rain.fill",       explanation: "Pack rain protection gear"),
            ConditionTrigger(name: "Trekking / Hiking",    icon: "figure.hiking",          explanation: "Add hiking-specific essentials"),
            ConditionTrigger(name: "With Children",        icon: "figure.and.child.holdinghands", explanation: "Items for traveling with kids"),
            ConditionTrigger(name: "Early Departure",      icon: "sunrise.fill",           explanation: "Prepare for pre-dawn start"),
            ConditionTrigger(name: "Cold Evenings",        icon: "thermometer.snowflake",  explanation: "Extra warmth for chilly nights"),
            ConditionTrigger(name: "Water / Beach",        icon: "water.waves",            explanation: "Swimming and beach essentials"),
            ConditionTrigger(name: "Long Transit",         icon: "airplane",               explanation: "Comfort items for long travel")
        ]
    }

    static func allNerves(conditions: [ConditionTrigger]) -> [DependencyNerve] {
        guard conditions.count >= 7 else { return [] }

        var nerves: [DependencyNerve] = []

        // Rain Expected
        let rainID = conditions[0].id
        nerves.append(DependencyNerve(conditionID: rainID, action: .addItem, targetItemName: "Umbrella",            targetOrgan: .provisions,  reasonText: "Rain expected"))
        nerves.append(DependencyNerve(conditionID: rainID, action: .addItem, targetItemName: "Rain Jacket",         targetOrgan: .clothing,    reasonText: "Rain expected"))
        nerves.append(DependencyNerve(conditionID: rainID, action: .addItem, targetItemName: "Waterproof Bag Cover", targetOrgan: .provisions, reasonText: "Rain expected"))

        // Trekking
        let trekID = conditions[1].id
        nerves.append(DependencyNerve(conditionID: trekID, action: .addItem, targetItemName: "Blister Plasters",    targetOrgan: .firstAid,    reasonText: "Trekking planned"))
        nerves.append(DependencyNerve(conditionID: trekID, action: .addItem, targetItemName: "Trekking Poles",      targetOrgan: .provisions,  reasonText: "Trekking planned"))
        nerves.append(DependencyNerve(conditionID: trekID, action: .addItem, targetItemName: "Trail Mix / Energy Bars", targetOrgan: .provisions, reasonText: "Trekking planned"))
        nerves.append(DependencyNerve(conditionID: trekID, action: .makeCritical, targetItemName: "Hiking Boots",   targetOrgan: .footwear,    reasonText: "Critical for trekking"))

        // With Children
        let kidsID = conditions[2].id
        nerves.append(DependencyNerve(conditionID: kidsID, action: .addItem, targetItemName: "Kids Snacks",         targetOrgan: .provisions,  reasonText: "Traveling with children"))
        nerves.append(DependencyNerve(conditionID: kidsID, action: .addItem, targetItemName: "Entertainment / Toys", targetOrgan: .provisions,  reasonText: "Keep kids occupied"))
        nerves.append(DependencyNerve(conditionID: kidsID, action: .addItem, targetItemName: "Kids First Aid Kit",  targetOrgan: .firstAid,    reasonText: "Traveling with children"))
        nerves.append(DependencyNerve(conditionID: kidsID, action: .addItem, targetItemName: "Extra Wet Wipes",     targetOrgan: .hygiene,     reasonText: "Traveling with children"))

        // Early Departure
        let earlyID = conditions[3].id
        nerves.append(DependencyNerve(conditionID: earlyID, action: .addItem, targetItemName: "Sleep Mask",         targetOrgan: .provisions,  reasonText: "Early departure rest"))
        nerves.append(DependencyNerve(conditionID: earlyID, action: .addItem, targetItemName: "Thermos / Coffee",   targetOrgan: .provisions,  reasonText: "Early morning boost"))
        nerves.append(DependencyNerve(conditionID: earlyID, action: .appendNote, targetItemName: "Phone Charger",   targetOrgan: .gadgets,     reasonText: "Charge fully the night before"))

        // Cold Evenings
        let coldID = conditions[4].id
        nerves.append(DependencyNerve(conditionID: coldID, action: .addItem, targetItemName: "Warm Layer / Fleece", targetOrgan: .clothing,    reasonText: "Cold evenings expected"))
        nerves.append(DependencyNerve(conditionID: coldID, action: .addItem, targetItemName: "Hand Warmers",        targetOrgan: .provisions,  reasonText: "Cold evenings expected"))
        nerves.append(DependencyNerve(conditionID: coldID, action: .addItem, targetItemName: "Warm Socks",          targetOrgan: .clothing,    reasonText: "Cold evenings expected"))

        // Water / Beach
        let waterID = conditions[5].id
        nerves.append(DependencyNerve(conditionID: waterID, action: .addItem, targetItemName: "Beach Towel",        targetOrgan: .provisions,  reasonText: "Beach / water activities"))
        nerves.append(DependencyNerve(conditionID: waterID, action: .addItem, targetItemName: "Waterproof Phone Case", targetOrgan: .gadgets,  reasonText: "Protect phone near water"))
        nerves.append(DependencyNerve(conditionID: waterID, action: .addItem, targetItemName: "Goggles / Snorkel",  targetOrgan: .provisions,  reasonText: "Water activities"))
        nerves.append(DependencyNerve(conditionID: waterID, action: .makeCritical, targetItemName: "Sunscreen",     targetOrgan: .hygiene,     reasonText: "Critical for beach"))

        // Long Transit
        let transitID = conditions[6].id
        nerves.append(DependencyNerve(conditionID: transitID, action: .addItem, targetItemName: "Neck Pillow",       targetOrgan: .provisions,  reasonText: "Long transit comfort"))
        nerves.append(DependencyNerve(conditionID: transitID, action: .addItem, targetItemName: "Compression Socks", targetOrgan: .clothing,    reasonText: "Long flight health"))
        nerves.append(DependencyNerve(conditionID: transitID, action: .addItem, targetItemName: "eBook / Kindle",    targetOrgan: .gadgets,     reasonText: "Long transit entertainment"))
        nerves.append(DependencyNerve(conditionID: transitID, action: .addItem, targetItemName: "Toiletry Zip Bag",  targetOrgan: .hygiene,     reasonText: "Airport security ready"))

        return nerves
    }
}
