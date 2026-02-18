// ConditionNexusPresenter.swift
// c13 — Smart Packing Companion
//
// VIPER Presenter for the Conditions tab (Tab 2).
// Manages the condition library, rule browsing, sandbox preview,
// condition CRUD, and impact calculations.

import SwiftUI
import Combine

// MARK: - Condition Nexus Presenter

final class ConditionNexusPresenter: ObservableObject {

    // MARK: — Dependencies

    private var vault: VitalDataVault
    private var router: VitalRouter
    private var cancellables = Set<AnyCancellable>()

    // MARK: — Published State

    @Published var conditions: [ConditionDisplayModel] = []
    @Published var searchQuery: String = ""
    @Published var selectedConditionID: UUID? = nil

    // Detail view state
    @Published var detailCondition: ConditionTrigger? = nil
    @Published var detailRules: [RuleDisplayModel] = []

    // Sandbox state
    @Published var sandboxActiveConditions: Set<UUID> = []
    @Published var sandboxResults: [SandboxResultItem] = []

    // Creation form
    @Published var newConditionName: String = ""
    @Published var newConditionIcon: String = "bolt.circle"
    @Published var newConditionExplanation: String = ""

    // Rule editor
    @Published var ruleEditorConditionID: UUID? = nil
    @Published var ruleEditorAction: NerveAction = .addItem
    @Published var ruleEditorTargetName: String = ""
    @Published var ruleEditorTargetOrgan: OrganDesignation = .provisions
    @Published var ruleEditorRemovalPolicy: NerveRemovalPolicy = .removeIfNotPacked
    @Published var ruleEditorPriority: Int = 3
    @Published var ruleEditorReasonText: String = ""

    // MARK: — Display Models

    struct ConditionDisplayModel: Identifiable {
        let id: UUID
        let name: String
        let icon: String
        let explanation: String
        let isBuiltIn: Bool
        let ruleCount: Int
        let totalItemImpact: Int
        let isActiveInAnySession: Bool
    }

    struct RuleDisplayModel: Identifiable {
        let id: UUID
        let conditionName: String
        let actionLabel: String
        let targetName: String
        let targetOrganName: String
        let removalPolicyLabel: String
        let priority: Int
        let reasonText: String
        let actionIcon: String
        let actionColor: Color
    }

    struct SandboxResultItem: Identifiable {
        let id = UUID()
        let itemName: String
        let organName: String
        let conditionName: String
        let actionType: NerveAction
    }

    // MARK: — Init

    init(vault: VitalDataVault, router: VitalRouter) {
        self.vault = vault
        self.router = router
        bindToVault()
    }

    // MARK: — Vault Binding

    private func bindToVault() {
        vault.$conditionBank
            .combineLatest(vault.$nerveLibrary, vault.$heartbeats, $searchQuery.debounce(for: .milliseconds(200), scheduler: DispatchQueue.main))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conditions, nerves, sessions, query in
                self?.rebuildConditionList(
                    conditions: conditions,
                    nerves: nerves,
                    sessions: sessions,
                    query: query
                )
            }
            .store(in: &cancellables)
    }

    func rebind(vault: VitalDataVault, router: VitalRouter) {
        self.vault = vault
        self.router = router
        cancellables.removeAll()
        bindToVault()
    }

    // MARK: — Rebuild Condition List

    private func rebuildConditionList(
        conditions: [ConditionTrigger],
        nerves: [DependencyNerve],
        sessions: [PackingHeartbeat],
        query: String
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let activeConditionIDs = sessions.flatMap { $0.activeConditionIDs }

        self.conditions = conditions
            .filter { trimmed.isEmpty || $0.name.lowercased().contains(trimmed) }
            .map { condition in
                let rulesForCondition = nerves.filter { $0.conditionID == condition.id }
                let addItemCount = rulesForCondition.filter { $0.action == .addItem }.count

                return ConditionDisplayModel(
                    id: condition.id,
                    name: condition.name,
                    icon: condition.icon,
                    explanation: condition.explanation,
                    isBuiltIn: condition.isBuiltIn,
                    ruleCount: rulesForCondition.count,
                    totalItemImpact: addItemCount,
                    isActiveInAnySession: activeConditionIDs.contains(condition.id)
                )
            }
            .sorted { $0.ruleCount > $1.ruleCount }
    }

    // MARK: — Navigation

    func openConditionDetail(_ conditionID: UUID) {
        selectedConditionID = conditionID
        loadConditionDetail(conditionID)
        router.navigateTo(.conditionDetail(conditionID: conditionID))
    }

    func openRulesList(_ conditionID: UUID) {
        router.navigateTo(.rulesList(conditionID: conditionID))
    }

    func presentCreateRule(conditionID: UUID?) {
        resetRuleEditor(conditionID: conditionID)
        router.presentSheet(.createRule(conditionID: conditionID))
    }

    func presentEditRule(_ nerveID: UUID) {
        loadRuleIntoEditor(nerveID)
        router.presentSheet(.editRule(nerveID: nerveID))
    }

    func presentSandbox() {
        sandboxActiveConditions = []
        sandboxResults = []
        router.presentSheet(.ruleSandbox)
    }

    // MARK: — Load Condition Detail

    func loadConditionDetail(_ conditionID: UUID) {
        detailCondition = vault.conditionBank.first { $0.id == conditionID }

        let nerves = vault.nervesForCondition(conditionID)
        detailRules = nerves.map { nerve in
            let condName = vault.conditionBank.first { $0.id == nerve.conditionID }?.name ?? "Unknown"
            return mapNerveToDisplay(nerve, conditionName: condName)
        }
    }

    private func mapNerveToDisplay(_ nerve: DependencyNerve, conditionName: String) -> RuleDisplayModel {
        let actionLabel: String
        let actionIcon: String
        let actionColor: Color

        switch nerve.action {
        case .addItem:
            actionLabel = "Adds"
            actionIcon = "plus.circle.fill"
            actionColor = VitalPalette.verdantPulse
        case .makeCritical:
            actionLabel = "Marks Critical"
            actionIcon = "exclamationmark.triangle.fill"
            actionColor = VitalPalette.emberCore
        case .appendNote:
            actionLabel = "Appends Note"
            actionIcon = "note.text"
            actionColor = VitalPalette.cyanVital
        }

        return RuleDisplayModel(
            id: nerve.id,
            conditionName: conditionName,
            actionLabel: actionLabel,
            targetName: nerve.targetItemName,
            targetOrganName: nerve.targetOrgan.displayName,
            removalPolicyLabel: nerve.removalPolicy.displayName,
            priority: nerve.priority,
            reasonText: nerve.reasonText,
            actionIcon: actionIcon,
            actionColor: actionColor
        )
    }

    // MARK: — Condition CRUD

    func createCondition() {
        let name = newConditionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let condition = ConditionTrigger(
            name: name,
            icon: newConditionIcon,
            explanation: newConditionExplanation,
            isBuiltIn: false
        )

        vault.addCondition(condition)
        resetConditionForm()
        router.showToast("Condition created", style: .success)
    }

    func deleteCondition(_ conditionID: UUID) {
        vault.deleteCondition(id: conditionID)
        router.popCurrent()
        router.showToast("Condition deleted", style: .info)
    }

    private func resetConditionForm() {
        newConditionName = ""
        newConditionIcon = "bolt.circle"
        newConditionExplanation = ""
    }

    // MARK: — Rule CRUD

    func saveRule() {
        let targetName = ruleEditorTargetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetName.isEmpty, let condID = ruleEditorConditionID else { return }

        let nerve = DependencyNerve(
            conditionID: condID,
            action: ruleEditorAction,
            targetItemName: targetName,
            targetOrgan: ruleEditorTargetOrgan,
            removalPolicy: ruleEditorRemovalPolicy,
            priority: ruleEditorPriority,
            reasonText: ruleEditorReasonText.isEmpty
                ? "\(ruleEditorAction.displayName): \(targetName)"
                : ruleEditorReasonText
        )

        vault.addNerve(nerve)
        router.dismissSheet()
        router.showToast("Rule created", style: .success)

        // Refresh detail if viewing
        if let condID = ruleEditorConditionID {
            loadConditionDetail(condID)
        }
    }

    func deleteRule(_ nerveID: UUID) {
        let condID = vault.nerveLibrary.first { $0.id == nerveID }?.conditionID
        vault.deleteNerve(id: nerveID)
        router.showUndoToast("Rule deleted", actionTag: "delete_rule")

        if let condID = condID {
            loadConditionDetail(condID)
        }
    }

    private func resetRuleEditor(conditionID: UUID?) {
        ruleEditorConditionID = conditionID
        ruleEditorAction = .addItem
        ruleEditorTargetName = ""
        ruleEditorTargetOrgan = .provisions
        ruleEditorRemovalPolicy = .removeIfNotPacked
        ruleEditorPriority = 3
        ruleEditorReasonText = ""
    }

    private func loadRuleIntoEditor(_ nerveID: UUID) {
        guard let nerve = vault.nerveLibrary.first(where: { $0.id == nerveID }) else { return }
        ruleEditorConditionID = nerve.conditionID
        ruleEditorAction = nerve.action
        ruleEditorTargetName = nerve.targetItemName
        ruleEditorTargetOrgan = nerve.targetOrgan
        ruleEditorRemovalPolicy = nerve.removalPolicy
        ruleEditorPriority = nerve.priority
        ruleEditorReasonText = nerve.reasonText
    }

    // MARK: — Sandbox

    func toggleSandboxCondition(_ conditionID: UUID) {
        if sandboxActiveConditions.contains(conditionID) {
            sandboxActiveConditions.remove(conditionID)
        } else {
            sandboxActiveConditions.insert(conditionID)
        }
        recalculateSandbox()
    }

    private func recalculateSandbox() {
        var results: [SandboxResultItem] = []

        for condID in sandboxActiveConditions {
            let condName = vault.conditionBank.first { $0.id == condID }?.name ?? "Unknown"
            let nerves = vault.nervesForCondition(condID)

            for nerve in nerves {
                results.append(SandboxResultItem(
                    itemName: nerve.targetItemName,
                    organName: nerve.targetOrgan.displayName,
                    conditionName: condName,
                    actionType: nerve.action
                ))
            }
        }

        // Deduplicate by item name (keep first occurrence)
        var seen = Set<String>()
        sandboxResults = results.filter { item in
            let key = item.itemName.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    func clearSandbox() {
        sandboxActiveConditions = []
        sandboxResults = []
    }

    // MARK: — Icon Picker Options

    static let availableIcons: [(String, String)] = [
        ("bolt.circle", "Default"),
        ("cloud.rain.fill", "Rain"),
        ("sun.max.fill", "Sun"),
        ("snowflake", "Snow"),
        ("wind", "Wind"),
        ("figure.hiking", "Hiking"),
        ("figure.run", "Sports"),
        ("figure.and.child.holdinghands", "Children"),
        ("airplane", "Flight"),
        ("car.fill", "Driving"),
        ("bed.double.fill", "Overnight"),
        ("fork.knife", "Dining"),
        ("camera.fill", "Photography"),
        ("briefcase.fill", "Business"),
        ("heart.fill", "Health"),
        ("water.waves", "Water"),
        ("thermometer.snowflake", "Cold"),
        ("sunrise.fill", "Early"),
        ("moon.stars.fill", "Night"),
        ("tent.fill", "Camping")
    ]

    // MARK: — Statistics

    var totalConditions: Int { vault.conditionBank.count }
    var totalRules: Int { vault.nerveLibrary.count }
    var builtInCount: Int { vault.conditionBank.filter { $0.isBuiltIn }.count }
    var customCount: Int { vault.conditionBank.filter { !$0.isBuiltIn }.count }

    // MARK: — Empty State

    var isConditionListEmpty: Bool {
        conditions.isEmpty && searchQuery.isEmpty
    }

    var emptySearchMessage: String {
        "No conditions match \"\(searchQuery)\""
    }
}
