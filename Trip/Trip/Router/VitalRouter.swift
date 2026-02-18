// VitalRouter.swift
// c13 — Smart Packing Companion
//
// VIPER Router layer. Manages all navigation paths, sheet presentations,
// and module assembly. Acts as the circulatory system connecting all screens.

import SwiftUI
import Combine
// MARK: - Navigation Destinations

/// All push-navigable destinations in the app.
enum VitalDestination: Hashable {
    // Tab 1 — Packing
    case sessionDetail(sessionID: UUID)
    case itemsList(sessionID: UUID, organID: UUID? = nil)

    // Tab 2 — Conditions
    case conditionDetail(conditionID: UUID)
    case rulesList(conditionID: UUID)

    // Tab 3 — Settings
    case notificationSettings
    case statisticsDashboard
    case dataManagement
}

// MARK: - Sheet Destinations

/// All modal sheet presentations.
enum VitalSheet: Identifiable {
    // Session sheets
    case createSession
    case addItem(sessionID: UUID, preselectedOrganID: UUID?)
    case editItem(sessionID: UUID, organID: UUID, cellID: UUID)
    case editOrgan(sessionID: UUID, organID: UUID)
    case sessionConditions(sessionID: UUID)
    case sessionReminders(sessionID: UUID)
    case editSession(sessionID: UUID)
    case itemReason(sessionID: UUID, organID: UUID, cellID: UUID)

    // Rule sheets
    case createRule(conditionID: UUID?)
    case editRule(nerveID: UUID)
    case ruleSandbox

    // Settings sheets
    case avatarPicker
    case shareSession(sessionID: UUID)

    var id: String {
        switch self {
        case .createSession:                          return "sheet_create_session"
        case .addItem(let sid, _):                    return "sheet_add_item_\(sid)"
        case .editItem(let sid, let oid, let cid):    return "sheet_edit_item_\(sid)_\(oid)_\(cid)"
        case .editOrgan(let sid, let oid):            return "sheet_edit_organ_\(sid)_\(oid)"
        case .sessionConditions(let sid):             return "sheet_conditions_\(sid)"
        case .sessionReminders(let sid):              return "sheet_reminders_\(sid)"
        case .editSession(let sid):                   return "sheet_edit_session_\(sid)"
        case .itemReason(let sid, let oid, let cid):  return "sheet_reason_\(sid)_\(oid)_\(cid)"
        case .createRule(let cid):                    return "sheet_create_rule_\(cid?.uuidString ?? "new")"
        case .editRule(let nid):                      return "sheet_edit_rule_\(nid)"
        case .ruleSandbox:                            return "sheet_rule_sandbox"
        case .avatarPicker:                           return "sheet_avatar_picker"
        case .shareSession(let sid):                  return "sheet_share_\(sid)"
        }
    }
}

// MARK: - Alert Types

/// Confirmation alerts throughout the app.
enum VitalAlert: Identifiable {
    case confirmDeleteSession(sessionID: UUID)
    case confirmDeleteItem(sessionID: UUID, organID: UUID, cellID: UUID)
    case confirmBulkMark(sessionID: UUID, organID: UUID)
    case confirmResetOrgan(sessionID: UUID, organID: UUID)
    case confirmResetAllData
    case confirmArchiveSession(sessionID: UUID)

    var id: String {
        switch self {
        case .confirmDeleteSession(let id):         return "alert_del_session_\(id)"
        case .confirmDeleteItem(_, _, let id):      return "alert_del_item_\(id)"
        case .confirmBulkMark(_, let id):           return "alert_bulk_\(id)"
        case .confirmResetOrgan(_, let id):         return "alert_reset_organ_\(id)"
        case .confirmResetAllData:                  return "alert_reset_all"
        case .confirmArchiveSession(let id):        return "alert_archive_\(id)"
        }
    }
}

// MARK: - Toast / Undo Banner

/// Transient feedback messages with optional undo.
struct VitalToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let undoAction: UndoPayload?
    let style: ToastStyle

    enum ToastStyle {
        case success
        case info
        case undo
        case warning
    }

    struct UndoPayload: Equatable {
        let label: String
        let actionTag: String // identifier for the undo handler
    }

    static func == (lhs: VitalToast, rhs: VitalToast) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Vital Router (Observable)

/// The main circulatory router — manages navigation state for the entire app.
/// Each tab maintains its own NavigationPath; sheets and alerts are global.
final class VitalRouter: ObservableObject {

    // MARK: — Navigation Paths (one per tab)

    @Published var packingPath: NavigationPath = NavigationPath()
    @Published var conditionsPath: NavigationPath = NavigationPath()
    @Published var settingsPath: NavigationPath = NavigationPath()

    // MARK: — Active Tab

    @Published var activeTab: VitalTab = .packing

    // MARK: — Sheets & Alerts

    @Published var activeSheet: VitalSheet?
    @Published var activeAlert: VitalAlert?
    @Published var activeToast: VitalToast?

    // MARK: — Tab Enum

    enum VitalTab: Int, CaseIterable {
        case packing    = 0
        case conditions = 1
        case settings   = 2

        var label: String {
            switch self {
            case .packing:    return "Packing"
            case .conditions: return "Conditions"
            case .settings:   return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .packing:    return "suitcase.fill"
            case .conditions: return "bolt.badge.clock.fill"
            case .settings:   return "gearshape.fill"
            }
        }
    }

    // =========================================================================
    // MARK: — PUSH Navigation
    // =========================================================================

    func navigateTo(_ destination: VitalDestination) {
        switch destination {
        case .sessionDetail, .itemsList:
            packingPath.append(destination)

        case .conditionDetail, .rulesList:
            conditionsPath.append(destination)

        case .notificationSettings, .statisticsDashboard, .dataManagement:
            settingsPath.append(destination)
        }
    }

    // MARK: — Pop

    func popCurrent() {
        switch activeTab {
        case .packing:
            if !packingPath.isEmpty { packingPath.removeLast() }
        case .conditions:
            if !conditionsPath.isEmpty { conditionsPath.removeLast() }
        case .settings:
            if !settingsPath.isEmpty { settingsPath.removeLast() }
        }
    }

    func popToRoot() {
        switch activeTab {
        case .packing:    packingPath = NavigationPath()
        case .conditions: conditionsPath = NavigationPath()
        case .settings:   settingsPath = NavigationPath()
        }
    }

    // =========================================================================
    // MARK: — SHEET Presentation
    // =========================================================================

    func presentSheet(_ sheet: VitalSheet) {
        activeSheet = sheet
    }

    func dismissSheet() {
        activeSheet = nil
    }

    // =========================================================================
    // MARK: — ALERT Presentation
    // =========================================================================

    func showAlert(_ alert: VitalAlert) {
        activeAlert = alert
    }

    func dismissAlert() {
        activeAlert = nil
    }

    // =========================================================================
    // MARK: — TOAST / Undo
    // =========================================================================

    func showToast(_ message: String, style: VitalToast.ToastStyle = .info) {
        activeToast = VitalToast(message: message, undoAction: nil, style: style)
        scheduleToastDismissal()
    }

    func showUndoToast(_ message: String, undoLabel: String = "Undo", actionTag: String) {
        activeToast = VitalToast(
            message: message,
            undoAction: VitalToast.UndoPayload(label: undoLabel, actionTag: actionTag),
            style: .undo
        )
        scheduleToastDismissal(delay: 5.0)
    }

    func dismissToast() {
        activeToast = nil
    }

    private func scheduleToastDismissal(delay: TimeInterval = 3.0) {
        let toastID = activeToast?.id
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            if self?.activeToast?.id == toastID {
                self?.activeToast = nil
            }
        }
    }

    // =========================================================================
    // MARK: — Deep Link / Quick Actions
    // =========================================================================

    /// Opens a specific session from a notification or widget.
    func openSessionFromDeepLink(sessionID: UUID) {
        activeTab = .packing
        packingPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.navigateTo(.sessionDetail(sessionID: sessionID))
        }
    }

    /// Opens the create session flow.
    func triggerQuickCreate() {
        activeTab = .packing
        packingPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.presentSheet(.createSession)
        }
    }
}

// MARK: - Navigation Destination View Builder

/// Resolves a VitalDestination into its corresponding SwiftUI View.
/// Real implementations are in VitalResolverBindings.swift,
/// SessionHeartbeatDetailView.swift, ConditionNexusView.swift, etc.
struct VitalDestinationResolver: View {

    let destination: VitalDestination
    @EnvironmentObject var router: VitalRouter
    @EnvironmentObject var vault: VitalDataVault

    var body: some View {
        switch destination {
        case .sessionDetail(let sessionID):
            SessionHeartbeatDetailView(sessionID: sessionID)

        case .itemsList(let sessionID, let organID):
            SessionHeartbeatDetailView(sessionID: sessionID)

        case .conditionDetail(let conditionID):
            ConditionNexusDetailView(conditionID: conditionID)

        case .rulesList(let conditionID):
            ConditionNexusDetailView(conditionID: conditionID)

        case .notificationSettings:
            NotificationSettingsView()

        case .statisticsDashboard:
            StatisticsDashboardView()

        case .dataManagement:
            DataManagementView()
        }
    }
}

// MARK: - Sheet View Builder

/// Resolves a VitalSheet into its corresponding modal View.
/// Real implementations are in VitalSheetsCollection.swift,
/// ConditionNexusView.swift (sandbox), VitalSettingsView.swift (avatar).
struct VitalSheetResolver: View {

    let sheet: VitalSheet
    @EnvironmentObject var router: VitalRouter
    @EnvironmentObject var vault: VitalDataVault

    var body: some View {
        switch sheet {
        case .createSession:
            VitalCreateSessionSheet()

        case .addItem(let sessionID, let organID):
            VitalAddItemSheet(sessionID: sessionID, preselectedOrganID: organID)

        case .editItem(let sessionID, let organID, let cellID):
            VitalEditItemSheet(sessionID: sessionID, organID: organID, cellID: cellID)

        case .editOrgan(let sessionID, let organID):
            VitalEditOrganSheet(sessionID: sessionID, organID: organID)

        case .sessionConditions(let sessionID):
            VitalSessionConditionsSheet(sessionID: sessionID)

        case .sessionReminders(let sessionID):
            VitalSessionRemindersSheet(sessionID: sessionID)

        case .editSession(let sessionID):
            VitalEditSessionSheet(sessionID: sessionID)

        case .itemReason(let sessionID, let organID, let cellID):
            VitalItemReasonSheet(sessionID: sessionID, organID: organID, cellID: cellID)

        case .createRule(let conditionID):
            VitalRuleEditorSheet(conditionID: conditionID, existingNerveID: nil)

        case .editRule(let nerveID):
            VitalRuleEditorSheet(conditionID: nil, existingNerveID: nerveID)

        case .ruleSandbox:
            RuleNexusSandboxSheet()

        case .avatarPicker:
            VitalAvatarPickerSheet()

        case .shareSession(let sessionID):
            VitalShareSessionSheet(sessionID: sessionID)
        }
    }
}
