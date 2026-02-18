// VitalResolverBindings.swift
// c13 — Smart Packing Companion
//
// Replaces the placeholder VitalDestinationResolver and VitalSheetResolver
// from VitalRouter.swift with real view bindings.
// Also provides the updated VitalFilter conformances and any missing
// display extensions needed for the full app to compile.

import SwiftUI

// ============================================================================
// MARK: - Destination Resolver (real bindings)
// ============================================================================

/// Maps VitalDestination enum cases to their real SwiftUI views.
/// This file replaces the placeholder views defined in VitalRouter.swift.
/// To use: remove or comment out the original VitalDestinationResolver
/// in VitalRouter.swift and use this one instead.
struct VitalDestinationResolverReal: View {

    let destination: VitalDestination
    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    var body: some View {
        switch destination {
        case .sessionDetail(let sessionID):
            SessionHeartbeatDetailView(sessionID: sessionID)

        case .itemsList(let sessionID, let organID):
            // Re-use session detail with a filter — in practice the organ
            // is expanded by default within session detail.
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

// ============================================================================
// MARK: - Sheet Resolver (real bindings)
// ============================================================================

/// Maps VitalSheet enum cases to their real modal views.
struct VitalSheetResolverReal: View {

    let sheet: VitalSheet
    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    var body: some View {
        switch sheet {
        case .createSession:
            VitalCreateSessionSheet()

        case .addItem(let sessionID, let preselectedOrganID):
            VitalAddItemSheet(sessionID: sessionID, preselectedOrganID: preselectedOrganID)

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

// ============================================================================
// MARK: - Notification Settings View (push destination)
// ============================================================================

struct NotificationSettingsView: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter = VitalSettingsPresenter(
        vault: VitalDataVault.shared,
        router: VitalRouter()
    )

    var body: some View {
        ZStack {
            PulseBackdropView(showPulseRing: false, vitalIntensity: 0.2)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Permission card
                    HStack(spacing: 14) {
                        Image(systemName: presenter.notificationPermission.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(presenter.notificationPermission.displayColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Push Notifications")
                                .font(VitalTypography.sectionPulse())
                                .foregroundColor(VitalPalette.ivoryBreath)
                            Text(presenter.notificationPermission.displayLabel)
                                .font(VitalTypography.captionMurmur())
                                .foregroundColor(presenter.notificationPermission.displayColor)
                        }

                        Spacer()

                        if presenter.notificationPermission == .unknown {
                            Button("Enable") { presenter.requestNotificationPermission() }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(VitalPalette.obsidianPulse)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(VitalPalette.aureliaGlow)
                                .clipShape(Capsule())
                        } else if presenter.notificationPermission == .denied {
                            Button("Open Settings") { presenter.openSystemNotificationSettings() }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(VitalPalette.aureliaGlow)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().stroke(VitalPalette.aureliaGlow.opacity(0.4), lineWidth: 1))
                        }
                    }
                    .padding(16)
                    .vitalGoldCardStyle(cornerRadius: 16)

                    // Default reminders
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Default Reminders")
                            .font(VitalTypography.sectionPulse())
                            .foregroundColor(VitalPalette.ivoryBreath)

                        Text("These defaults apply to newly created sessions. You can override them per session.")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.ashVeil)

                        VStack(spacing: 1) {
                            toggleRow(label: "24 hours before departure", icon: "clock", isOn: $presenter.isReminder24Enabled)
                            Divider().background(VitalPalette.charcoalBreath)
                            toggleRow(label: "6 hours before departure", icon: "clock.badge", isOn: $presenter.isReminder6Enabled)
                            Divider().background(VitalPalette.charcoalBreath)
                            toggleRow(label: "2 hours before departure", icon: "clock.badge.exclamationmark", isOn: $presenter.isReminder2Enabled)
                        }
                        .vitalCardStyle(cornerRadius: 14)
                    }

                    // Quiet hours
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quiet Hours")
                            .font(VitalTypography.sectionPulse())
                            .foregroundColor(VitalPalette.ivoryBreath)

                        Text("No notifications between these times")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.ashVeil)

                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Text("From")
                                    .font(VitalTypography.microSignal())
                                    .foregroundColor(VitalPalette.ashVeil)
                                Text("\(presenter.quietHoursStart):00")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(VitalPalette.ivoryBreath)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .vitalCardStyle(cornerRadius: 12)

                            Image(systemName: "arrow.right")
                                .foregroundColor(VitalPalette.ashVeil)

                            VStack(spacing: 4) {
                                Text("To")
                                    .font(VitalTypography.microSignal())
                                    .foregroundColor(VitalPalette.ashVeil)
                                Text("\(presenter.quietHoursEnd):00")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(VitalPalette.ivoryBreath)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .vitalCardStyle(cornerRadius: 12)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { presenter.rebind(vault: vault, router: router) }
    }

    private func toggleRow(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(VitalPalette.ashVeil)
                .frame(width: 22)
            Text(label)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.boneMarrow)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(VitalPalette.aureliaGlow)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// ============================================================================
// MARK: - Statistics Dashboard View (push destination)
// ============================================================================

struct StatisticsDashboardView: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter = VitalSettingsPresenter(
        vault: VitalDataVault.shared,
        router: VitalRouter()
    )

    var body: some View {
        ZStack {
            PulseBackdropView(showPulseRing: false, vitalIntensity: 0.2)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Hero stat
                    VStack(spacing: 8) {
                        Text("\(presenter.totalItemsPacked)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(VitalPalette.aureliaGlow)

                        Text("Total Items Packed")
                            .font(VitalTypography.captionMurmur())
                            .foregroundColor(VitalPalette.boneMarrow)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .vitalGoldCardStyle(cornerRadius: 18)

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        ForEach(presenter.statCards) { card in
                            VStack(spacing: 6) {
                                Image(systemName: card.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(card.accentColor)
                                Text(card.value)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(VitalPalette.ivoryBreath)
                                Text(card.label)
                                    .font(VitalTypography.microSignal())
                                    .foregroundColor(VitalPalette.ashVeil)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .vitalCardStyle(cornerRadius: 14)
                        }
                    }

                    // Extra stats
                    VStack(spacing: 1) {
                        statRow(label: "Most Used Trip Type", value: presenter.mostUsedArchetype)
                        Divider().background(VitalPalette.charcoalBreath)
                        statRow(label: "Conditions Used", value: "\(presenter.conditionsUsed)")
                        Divider().background(VitalPalette.charcoalBreath)
                        statRow(label: "Current Streak", value: "\(presenter.perfectStreak)")
                        Divider().background(VitalPalette.charcoalBreath)
                        statRow(label: "Longest Streak", value: "\(presenter.longestStreak)")
                    }
                    .vitalCardStyle(cornerRadius: 14)

                    // Achievements
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Achievements")
                            .font(VitalTypography.sectionPulse())
                            .foregroundColor(VitalPalette.ivoryBreath)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 10) {
                            ForEach(presenter.achievements) { badge in
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(badge.isUnlocked
                                                  ? badge.accentColor.opacity(0.12)
                                                  : VitalPalette.charcoalBreath)
                                            .frame(width: 44, height: 44)

                                        Image(systemName: badge.icon)
                                            .font(.system(size: 18))
                                            .foregroundColor(badge.isUnlocked
                                                             ? badge.accentColor
                                                             : VitalPalette.ashVeil.opacity(0.4))
                                    }

                                    Text(badge.title)
                                        .font(VitalTypography.microSignal())
                                        .foregroundColor(badge.isUnlocked
                                                         ? VitalPalette.ivoryBreath
                                                         : VitalPalette.ashVeil)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .vitalCardStyle(cornerRadius: 10)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { presenter.rebind(vault: vault, router: router) }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.boneMarrow)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(VitalPalette.ivoryBreath)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// ============================================================================
// MARK: - Data Management View (push destination)
// ============================================================================

struct DataManagementView: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter = VitalSettingsPresenter(
        vault: VitalDataVault.shared,
        router: VitalRouter()
    )

    var body: some View {
        ZStack {
            PulseBackdropView(showPulseRing: false, vitalIntensity: 0.2)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Data footprint
                    let fp = presenter.dataFootprint
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Footprint")
                            .font(VitalTypography.sectionPulse())
                            .foregroundColor(VitalPalette.ivoryBreath)

                        HStack(spacing: 0) {
                            fpCell(value: "\(fp.sessionCount)", label: "Sessions", icon: "suitcase.fill")
                            fpDivider
                            fpCell(value: "\(fp.conditionCount)", label: "Conditions", icon: "bolt.circle.fill")
                            fpDivider
                            fpCell(value: "\(fp.ruleCount)", label: "Rules", icon: "arrow.triangle.branch")
                            fpDivider
                            fpCell(value: "\(fp.totalItems)", label: "Items", icon: "checklist")
                        }
                        .padding(.vertical, 14)
                        .vitalCardStyle(cornerRadius: 14)
                    }

                    // Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Actions")
                            .font(VitalTypography.sectionPulse())
                            .foregroundColor(VitalPalette.ivoryBreath)

                        VStack(spacing: 1) {
                            actionRow(
                                icon: "doc.text.fill",
                                iconColor: VitalPalette.cyanVital,
                                label: "Export as JSON",
                                subtitle: "Full backup of all your data"
                            ) {
                                exportJSON()
                            }

                            Divider().background(VitalPalette.charcoalBreath)

                            actionRow(
                                icon: "square.and.arrow.up",
                                iconColor: VitalPalette.honeyElixir,
                                label: "Share Stats Summary",
                                subtitle: "Text summary of your achievements"
                            ) {
                                shareStats()
                            }

                            Divider().background(VitalPalette.charcoalBreath)

                            actionRow(
                                icon: "trash.fill",
                                iconColor: VitalPalette.emberCore,
                                label: "Reset All Data",
                                subtitle: "Permanently erase everything"
                            ) {
                                presenter.confirmResetAllData()
                            }
                        }
                        .vitalCardStyle(cornerRadius: 14)
                    }

                    // Storage info
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Storage")
                            .font(VitalTypography.sectionPulse())
                            .foregroundColor(VitalPalette.ivoryBreath)

                        Text("All data is stored locally on this device using JSON files. No cloud sync. Export regularly to keep a backup.")
                            .font(VitalTypography.captionMurmur())
                            .foregroundColor(VitalPalette.ashVeil)
                    }
                    .padding(14)
                    .vitalCardStyle(cornerRadius: 12)
                }
                .padding(20)
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { presenter.rebind(vault: vault, router: router) }
    }

    private func fpCell(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(VitalPalette.aureliaGlow)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(VitalPalette.ivoryBreath)
            Text(label)
                .font(VitalTypography.microSignal())
                .foregroundColor(VitalPalette.ashVeil)
        }
        .frame(maxWidth: .infinity)
    }

    private var fpDivider: some View {
        Rectangle().fill(VitalPalette.charcoalBreath).frame(width: 1, height: 36)
    }

    private func actionRow(icon: String, iconColor: Color, label: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(VitalTypography.captionMurmur())
                        .foregroundColor(VitalPalette.ivoryBreath)
                    Text(subtitle)
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.ashVeil)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(VitalPalette.ashVeil)
            }
            .padding(14)
        }
    }

    private func exportJSON() {
        guard let data = presenter.exportDataAsJSON() else {
            router.showToast("Export failed", style: .warning)
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("c13_backup.json")
        try? data.write(to: url)
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(controller, animated: true)
        }
    }

    private func shareStats() {
        let text = presenter.shareAppStats()
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(controller, animated: true)
        }
    }
}


