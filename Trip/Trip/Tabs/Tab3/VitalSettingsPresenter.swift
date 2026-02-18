// VitalSettingsPresenter.swift
// c13 — Smart Packing Companion
//
// VIPER Presenter for the Settings tab (Tab 3).
// Manages user identity, avatar selection, statistics,
// notification preferences, data export/reset, and sharing.

import SwiftUI
import Combine
import UserNotifications

// MARK: - Vital Settings Presenter

final class VitalSettingsPresenter: ObservableObject {

    // MARK: — Dependencies

    private var vault: VitalDataVault
    private var router: VitalRouter
    private var cancellables = Set<AnyCancellable>()

    // MARK: — Published State: Identity

    @Published var avatarEmoji: String = "🧳"
    @Published var displayName: String = "Traveler"
    @Published var vitalLevel: Int = 1
    @Published var levelTitle: String = "Novice Packer"
    @Published var levelIcon: String = "leaf"
    @Published var totalItemsPacked: Int = 0
    @Published var perfectStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var levelProgress: Double = 0

    // MARK: — Published State: Statistics

    @Published var totalTrips: Int = 0
    @Published var totalItemsEver: Int = 0
    @Published var averagePackingPercent: String = "0%"
    @Published var perfectTrips: Int = 0
    @Published var criticalSaved: Int = 0
    @Published var conditionsUsed: Int = 0
    @Published var mostUsedArchetype: String = "—"

    // MARK: — Published State: Notifications

    @Published var notificationPermission: NotificationPermissionState = .unknown
    @Published var isReminder24Enabled: Bool = true
    @Published var isReminder6Enabled: Bool = true
    @Published var isReminder2Enabled: Bool = true
    @Published var quietHoursStart: Int = 23
    @Published var quietHoursEnd: Int = 7

    // MARK: — Published State: Avatar Picker

    @Published var isEditingName: Bool = false
    @Published var draftName: String = ""

    // MARK: — Notification Permission

    enum NotificationPermissionState {
        case unknown
        case authorized
        case denied
        case provisional

        var displayLabel: String {
            switch self {
            case .unknown:     return "Not Requested"
            case .authorized:  return "Enabled"
            case .denied:      return "Denied"
            case .provisional: return "Provisional"
            }
        }

        var displayColor: Color {
            switch self {
            case .authorized, .provisional: return VitalPalette.verdantPulse
            case .denied:                   return VitalPalette.emberCore
            case .unknown:                  return VitalPalette.ashVeil
            }
        }

        var icon: String {
            switch self {
            case .authorized, .provisional: return "bell.badge.fill"
            case .denied:                   return "bell.slash.fill"
            case .unknown:                  return "bell"
            }
        }
    }

    // MARK: — Available Avatars

    static let avatarOptions: [String] = [
        "🧳", "🎒", "✈️", "🌍", "🏔️",
        "🏖️", "🧭", "🗺️", "⛺", "🚀",
        "🌊", "🏕️", "🧗", "🚢", "🏄",
        "🎯", "⭐", "🔥", "💎", "🏆",
        "🦅", "🐺", "🦊", "🐻", "🦁",
        "🌿", "🍀", "🌸", "🌙", "☀️"
    ]

    // MARK: — Statistics Cards

    struct StatCardModel: Identifiable {
        let id = UUID()
        let icon: String
        let value: String
        let label: String
        let accentColor: Color
    }

    var statCards: [StatCardModel] {
        [
            StatCardModel(
                icon: "suitcase.fill",
                value: "\(totalTrips)",
                label: "Total Trips",
                accentColor: VitalPalette.aureliaGlow
            ),
            StatCardModel(
                icon: "checkmark.circle.fill",
                value: "\(totalItemsEver)",
                label: "Items Packed",
                accentColor: VitalPalette.verdantPulse
            ),
            StatCardModel(
                icon: "chart.line.uptrend.xyaxis",
                value: averagePackingPercent,
                label: "Avg. Completion",
                accentColor: VitalPalette.cyanVital
            ),
            StatCardModel(
                icon: "trophy.fill",
                value: "\(perfectTrips)",
                label: "Perfect Packs",
                accentColor: VitalPalette.aureliaGlow
            ),
            StatCardModel(
                icon: "exclamationmark.shield.fill",
                value: "\(criticalSaved)",
                label: "Critical Saved",
                accentColor: VitalPalette.emberCore
            ),
            StatCardModel(
                icon: "flame.fill",
                value: "\(longestStreak)",
                label: "Best Streak",
                accentColor: VitalPalette.feverSignal
            )
        ]
    }

    // MARK: — Achievement Badges

    struct AchievementBadge: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let isUnlocked: Bool
        let accentColor: Color
    }

    var achievements: [AchievementBadge] {
        [
            AchievementBadge(
                icon: "suitcase.fill",
                title: "First Journey",
                description: "Create your first packing session",
                isUnlocked: totalTrips >= 1,
                accentColor: VitalPalette.aureliaGlow
            ),
            AchievementBadge(
                icon: "star.fill",
                title: "Seasoned Traveler",
                description: "Complete 5 trips",
                isUnlocked: totalTrips >= 5,
                accentColor: VitalPalette.honeyElixir
            ),
            AchievementBadge(
                icon: "checkmark.seal.fill",
                title: "Perfect Pack",
                description: "Pack 100% of items in a session",
                isUnlocked: perfectTrips >= 1,
                accentColor: VitalPalette.verdantPulse
            ),
            AchievementBadge(
                icon: "bolt.shield.fill",
                title: "Critical Guardian",
                description: "Pack 10 critical items across trips",
                isUnlocked: criticalSaved >= 10,
                accentColor: VitalPalette.emberCore
            ),
            AchievementBadge(
                icon: "flame.fill",
                title: "On Fire",
                description: "Reach a 3-session perfect streak",
                isUnlocked: longestStreak >= 3,
                accentColor: VitalPalette.feverSignal
            ),
            AchievementBadge(
                icon: "crown.fill",
                title: "Master Voyager",
                description: "Reach Level 4",
                isUnlocked: vitalLevel >= 4,
                accentColor: VitalPalette.aureliaGlow
            )
        ]
    }

    // MARK: — Init

    init(vault: VitalDataVault, router: VitalRouter) {
        self.vault = vault
        self.router = router
        bindToVault()
        checkNotificationPermission()
    }

    // MARK: — Rebind

    func rebind(vault: VitalDataVault, router: VitalRouter) {
        self.vault = vault
        self.router = router
        cancellables.removeAll()
        bindToVault()
        checkNotificationPermission()
    }

    // MARK: — Vault Binding

    private func bindToVault() {
        vault.$identity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] identity in
                self?.syncIdentity(identity)
            }
            .store(in: &cancellables)

        vault.$statistics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.syncStatistics(stats)
            }
            .store(in: &cancellables)
    }

    private func syncIdentity(_ identity: VitalIdentity) {
        avatarEmoji = identity.avatarEmoji
        displayName = identity.displayName
        vitalLevel = identity.vitalLevel
        levelTitle = identity.levelTitle
        levelIcon = identity.levelIcon
        totalItemsPacked = identity.totalItemsPacked
        perfectStreak = identity.perfectPackStreak
        longestStreak = identity.longestStreak
        recalculateLevelProgress(identity)
    }

    private func syncStatistics(_ stats: VitalStatistics) {
        totalTrips = stats.totalTrips
        totalItemsEver = stats.totalItemsEverPacked
        averagePackingPercent = stats.formattedAveragePercent
        perfectTrips = stats.perfectTrips
        criticalSaved = stats.criticalItemsSaved
        conditionsUsed = stats.conditionsUsedCount
        mostUsedArchetype = stats.mostUsedArchetype ?? "—"
    }

    private func recalculateLevelProgress(_ identity: VitalIdentity) {
        let thresholds: [Int] = [0, 25, 100, 300, 750, 1500, 3000]
        let lvl = identity.vitalLevel
        let idx = min(lvl, thresholds.count - 1)
        let nextIdx = min(lvl + 1, thresholds.count - 1)

        guard nextIdx > idx else { levelProgress = 1.0; return }

        let current = thresholds[idx - 1]
        let next = thresholds[nextIdx - 1]
        let range = next - current
        guard range > 0 else { levelProgress = 1.0; return }

        levelProgress = min(Double(identity.totalItemsPacked - current) / Double(range), 1.0)
    }

    // MARK: — Avatar Selection

    func selectAvatar(_ emoji: String) {
        var identity = vault.identity
        identity.avatarEmoji = emoji
        vault.updateIdentity(identity)
        router.showToast("Avatar updated!", style: .success)
    }

    func presentAvatarPicker() {
        router.presentSheet(.avatarPicker)
    }

    // MARK: — Name Editing

    func beginNameEdit() {
        draftName = displayName
        isEditingName = true
    }

    func saveName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var identity = vault.identity
        identity.displayName = trimmed
        vault.updateIdentity(identity)
        isEditingName = false
        router.showToast("Name updated", style: .info)
    }

    func cancelNameEdit() {
        isEditingName = false
        draftName = ""
    }

    // MARK: — Notifications

    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:    self?.notificationPermission = .authorized
                case .denied:        self?.notificationPermission = .denied
                case .provisional:   self?.notificationPermission = .provisional
                case .notDetermined: self?.notificationPermission = .unknown
                @unknown default:    self?.notificationPermission = .unknown
                }
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.notificationPermission = granted ? .authorized : .denied
                if granted {
                    self?.router.showToast("Notifications enabled", style: .success)
                }
            }
        }
    }

    func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: — Navigation

    func openNotificationSettings() {
        router.navigateTo(.notificationSettings)
    }

    func openStatistics() {
        router.navigateTo(.statisticsDashboard)
    }

    func openDataManagement() {
        router.navigateTo(.dataManagement)
    }

    // MARK: — Sharing

    func shareAppStats() -> String {
        var lines: [String] = []
        lines.append("🧳 My c13 Packing Stats")
        lines.append("―――――――――――――――")
        lines.append("Level: \(vitalLevel) — \(levelTitle)")
        lines.append("Total Trips: \(totalTrips)")
        lines.append("Items Packed: \(totalItemsEver)")
        lines.append("Perfect Packs: \(perfectTrips)")
        lines.append("Best Streak: \(longestStreak)")
        lines.append("")
        lines.append("Pack smarter with c13 ✨")
        return lines.joined(separator: "\n")
    }

    // MARK: — Data Management

    func confirmResetAllData() {
        router.showAlert(.confirmResetAllData)
    }

    func exportDataAsJSON() -> Data? {
        let exportPayload = DataExportPayload(
            sessions: vault.heartbeats,
            conditions: vault.conditionBank,
            rules: vault.nerveLibrary,
            identity: vault.identity,
            statistics: vault.statistics,
            exportDate: Date()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try? encoder.encode(exportPayload)
    }

    /// Counts for data management display.
    var dataFootprint: DataFootprint {
        DataFootprint(
            sessionCount: vault.heartbeats.count,
            conditionCount: vault.conditionBank.count,
            ruleCount: vault.nerveLibrary.count,
            totalItems: vault.heartbeats.reduce(0) { sum, session in
                sum + session.organs.reduce(0) { $0 + $1.cells.count }
            }
        )
    }

    struct DataFootprint {
        let sessionCount: Int
        let conditionCount: Int
        let ruleCount: Int
        let totalItems: Int
    }

    // MARK: — App Info

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Data Export Payload

struct DataExportPayload: Codable {
    let sessions: [PackingHeartbeat]
    let conditions: [ConditionTrigger]
    let rules: [DependencyNerve]
    let identity: VitalIdentity
    let statistics: VitalStatistics
    let exportDate: Date
}
