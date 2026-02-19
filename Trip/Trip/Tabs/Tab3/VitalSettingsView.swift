

import SwiftUI

// MARK: - Vital Settings View

struct VitalSettingsView: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter = VitalSettingsPresenter(
        vault: VitalDataVault.shared,
        router: VitalRouter()
    )

    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            PulseBackdropView(showPulseRing: false, vitalIntensity: 0.25)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Profile card
                    profileCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // Achievements
                    achievementsSection
                        .padding(.horizontal, 20)

                    // Statistics grid
                    statisticsGrid
                        .padding(.horizontal, 20)

                    // Notifications section
                    notificationsSection
                        .padding(.horizontal, 20)

                    // Actions section
                    actionsSection
                        .padding(.horizontal, 20)

                    // Data management
                    dataSection
                        .padding(.horizontal, 20)

                    // App info footer
                    appInfoFooter
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            presenter.rebind(vault: vault, router: router)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(text: presenter.shareAppStats())
        }
    }

    // =========================================================================
    // MARK: — Profile Card
    // =========================================================================

    private var profileCard: some View {
        VStack(spacing: 16) {
            // Avatar + name row
            HStack(spacing: 16) {
                // Avatar (tappable)
                Button {
                    presenter.presentAvatarPicker()
                } label: {
                    ZStack {
                        Circle()
                            .fill(VitalPalette.aureliaGlow.opacity(0.10))
                            .frame(width: 68, height: 68)

                        Text(presenter.avatarEmoji)
                            .font(.system(size: 38))

                        // Edit badge
                        Circle()
                            .fill(VitalPalette.charcoalBreath)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(VitalPalette.aureliaGlow)
                            )
                            .offset(x: 24, y: 24)
                    }
                }

                // Name + level
                VStack(alignment: .leading, spacing: 6) {
                    if presenter.isEditingName {
                        HStack(spacing: 8) {
                            TextField("Name", text: $presenter.draftName)
                                .font(VitalTypography.sectionPulse())
                                .foregroundColor(VitalPalette.ivoryBreath)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(VitalPalette.charcoalBreath)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .submitLabel(.done)
                                .onSubmit { presenter.saveName() }

                            Button {
                                presenter.saveName()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(VitalPalette.verdantPulse)
                            }

                            Button {
                                presenter.cancelNameEdit()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(VitalPalette.ashVeil)
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(presenter.displayName)
                                .font(VitalTypography.vitalTitle())
                                .foregroundColor(VitalPalette.ivoryBreath)

                            Button {
                                presenter.beginNameEdit()
                            } label: {
                                Image(systemName: "pencil.line")
                                    .font(.system(size: 16))
                                    .foregroundColor(VitalPalette.ashVeil)
                            }
                        }
                    }

                    // Level badge
                    HStack(spacing: 6) {
                        Image(systemName: presenter.levelIcon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(VitalPalette.aureliaGlow)

                        Text("Level \(presenter.vitalLevel)")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.aureliaGlow)

                        Text("·")
                            .foregroundColor(VitalPalette.ashVeil)

                        Text(presenter.levelTitle)
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.boneMarrow)
                    }
                }

                Spacer()
            }

            // Level progress
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VitalPalette.charcoalBreath)
                            .frame(height: 6)

                        Capsule()
                            .fill(VitalPalette.aureliaShimmer)
                            .frame(width: geo.size.width * CGFloat(presenter.levelProgress), height: 6)
                            .animation(.spring(response: 0.6), value: presenter.levelProgress)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(presenter.totalItemsPacked) items packed")
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.ashVeil)

                    Spacer()

                    if presenter.vitalLevel < 6 {
                        Text("Next level soon")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.honeyElixir)
                    } else {
                        Text("Max level reached!")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.verdantPulse)
                    }
                }
            }
        }
        .padding(18)
        .vitalGoldCardStyle(cornerRadius: 18)
    }

    // =========================================================================
    // MARK: — Achievements
    // =========================================================================

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(title: "Achievements", icon: "trophy.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presenter.achievements) { badge in
                        AchievementBadgeCard(badge: badge)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // =========================================================================
    // MARK: — Statistics Grid
    // =========================================================================

    private var statisticsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(title: "Statistics", icon: "chart.bar.fill")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(presenter.statCards) { card in
                    StatisticCell(card: card)
                }
            }
        }
    }

    // =========================================================================
    // MARK: — Notifications
    // =========================================================================

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(title: "Notifications", icon: "bell.fill")

            VStack(spacing: 1) {
                // Permission status
                HStack(spacing: 12) {
                    Image(systemName: presenter.notificationPermission.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(presenter.notificationPermission.displayColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Push Notifications")
                            .font(VitalTypography.captionMurmur())
                            .foregroundColor(VitalPalette.ivoryBreath)

                        Text(presenter.notificationPermission.displayLabel)
                            .font(VitalTypography.microSignal())
                            .foregroundColor(presenter.notificationPermission.displayColor)
                    }

                    Spacer()

                    switch presenter.notificationPermission {
                    case .unknown:
                        Button("Enable") {
                            presenter.requestNotificationPermission()
                        }
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.obsidianPulse)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(VitalPalette.aureliaGlow)
                        .clipShape(Capsule())

                    case .denied:
                        Button("Settings") {
                            presenter.openSystemNotificationSettings()
                        }
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.aureliaGlow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .stroke(VitalPalette.aureliaGlow.opacity(0.4), lineWidth: 1)
                        )

                    default:
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(VitalPalette.verdantPulse)
                    }
                }
                .padding(14)

                // Reminder toggles (if authorized)
                if presenter.notificationPermission == .authorized
                    || presenter.notificationPermission == .provisional {
                    Divider()
                        .background(VitalPalette.charcoalBreath)

                    reminderToggle(
                        label: "24 hours before",
                        icon: "clock",
                        isOn: $presenter.isReminder24Enabled
                    )

                    Divider()
                        .background(VitalPalette.charcoalBreath)

                    reminderToggle(
                        label: "6 hours before",
                        icon: "clock.badge",
                        isOn: $presenter.isReminder6Enabled
                    )

                    Divider()
                        .background(VitalPalette.charcoalBreath)

                    reminderToggle(
                        label: "2 hours before",
                        icon: "clock.badge.exclamationmark",
                        isOn: $presenter.isReminder2Enabled
                    )
                }
            }
            .vitalCardStyle(cornerRadius: 14)
        }
    }

    private func reminderToggle(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(VitalPalette.ashVeil)
                .frame(width: 24)

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

    // =========================================================================
    // MARK: — Actions
    // =========================================================================

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(title: "Quick Actions", icon: "bolt.fill")

            VStack(spacing: 1) {
                settingsRow(
                    icon: "square.and.arrow.up",
                    iconColor: VitalPalette.cyanVital,
                    label: "Share My Stats",
                    subtitle: "Show off your packing prowess"
                ) {
                    showShareSheet = true
                }
            }
            .vitalCardStyle(cornerRadius: 14)
        }
    }

    // =========================================================================
    // MARK: — Data Management
    // =========================================================================

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(title: "Data", icon: "externaldrive.fill")

            // Data footprint
            let footprint = presenter.dataFootprint
            HStack(spacing: 0) {
                footprintCell(value: "\(footprint.sessionCount)", label: "Sessions")
                footprintDivider
                footprintCell(value: "\(footprint.conditionCount)", label: "Conditions")
                footprintDivider
                footprintCell(value: "\(footprint.ruleCount)", label: "Rules")
                footprintDivider
                footprintCell(value: "\(footprint.totalItems)", label: "Items")
            }
            .padding(.vertical, 12)
            .vitalCardStyle(cornerRadius: 12)

            VStack(spacing: 1) {
                settingsRow(
                    icon: "doc.text",
                    iconColor: VitalPalette.cyanVital,
                    label: "Export Data",
                    subtitle: "Save all data as JSON file"
                ) {
                    exportData()
                }

                Divider().background(VitalPalette.charcoalBreath)

                settingsRow(
                    icon: "trash",
                    iconColor: VitalPalette.emberCore,
                    label: "Reset All Data",
                    subtitle: "Erase everything and start fresh"
                ) {
                    presenter.confirmResetAllData()
                }
            }
            .vitalCardStyle(cornerRadius: 14)
        }
    }

    private func footprintCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(VitalPalette.ivoryBreath)
            Text(label)
                .font(VitalTypography.microSignal())
                .foregroundColor(VitalPalette.ashVeil)
        }
        .frame(maxWidth: .infinity)
    }

    private var footprintDivider: some View {
        Rectangle()
            .fill(VitalPalette.charcoalBreath)
            .frame(width: 1, height: 28)
    }

    // =========================================================================
    // MARK: — App Info Footer
    // =========================================================================

    private var appInfoFooter: some View {
        VStack(spacing: 4) {
            Text("Ready Set: Easy Now")
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.ashVeil)

            Text("Version \(presenter.appVersion) (\(presenter.buildNumber))")
                .font(VitalTypography.microSignal())
                .foregroundColor(VitalPalette.ashVeil.opacity(0.6))

            Text("Pack with confidence")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(VitalPalette.honeyElixir.opacity(0.5))
                .italic()
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    // =========================================================================
    // MARK: — Reusable Components
    // =========================================================================

    private func sectionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(VitalPalette.aureliaGlow)

            Text(title)
                .font(VitalTypography.sectionPulse())
                .foregroundColor(VitalPalette.ivoryBreath)

            Spacer()
        }
    }

    private func settingsRow(
        icon: String,
        iconColor: Color,
        label: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VitalPalette.ashVeil)
            }
            .padding(14)
        }
    }

    // MARK: — Data Export

    private func exportData() {
        guard let data = presenter.exportDataAsJSON() else {
            router.showToast("Export failed", style: .warning)
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("c13_backup.json")
        do {
            try data.write(to: tempURL)
            let controller = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(controller, animated: true)
            }
        } catch {
            router.showToast("Export failed", style: .warning)
        }
    }
}

// MARK: - Achievement Badge Card

struct AchievementBadgeCard: View {

    let badge: VitalSettingsPresenter.AchievementBadge
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked
                          ? badge.accentColor.opacity(0.12)
                          : VitalPalette.charcoalBreath)
                    .frame(width: 48, height: 48)

                Image(systemName: badge.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(badge.isUnlocked
                                     ? badge.accentColor
                                     : VitalPalette.ashVeil.opacity(0.4))

                if !badge.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(VitalPalette.ashVeil)
                        .offset(x: 16, y: 16)
                }
            }

            Text(badge.title)
                .font(VitalTypography.microSignal())
                .foregroundColor(badge.isUnlocked
                                 ? VitalPalette.ivoryBreath
                                 : VitalPalette.ashVeil)
                .lineLimit(1)

            Text(badge.description)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VitalPalette.ashVeil)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 100)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .vitalCardStyle(cornerRadius: 12)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
    }
}

// MARK: - Statistic Cell

struct StatisticCell: View {

    let card: VitalSettingsPresenter.StatCardModel

    var body: some View {
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .vitalCardStyle(cornerRadius: 12)
    }
}

// MARK: - Avatar Picker Sheet (replaces placeholder)

struct VitalAvatarPickerSheet: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter = VitalSettingsPresenter(
        vault: VitalDataVault.shared,
        router: VitalRouter()
    )

    @State private var selectedEmoji: String = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Preview
                    ZStack {
                        Circle()
                            .fill(VitalPalette.aureliaGlow.opacity(0.10))
                            .frame(width: 90, height: 90)

                        Text(selectedEmoji.isEmpty ? presenter.avatarEmoji : selectedEmoji)
                            .font(.system(size: 52))
                            .animation(.spring(response: 0.3), value: selectedEmoji)
                    }
                    .padding(.top, 20)

                    // Grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(VitalSettingsPresenter.avatarOptions, id: \.self) { emoji in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedEmoji = emoji
                                }
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 48, height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(selectedEmoji == emoji
                                                  ? VitalPalette.aureliaGlow.opacity(0.15)
                                                  : VitalPalette.charcoalBreath)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selectedEmoji == emoji
                                                    ? VitalPalette.aureliaGlow.opacity(0.5)
                                                    : Color.clear,
                                                    lineWidth: 1.5)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Choose Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        router.dismissSheet()
                    }
                    .foregroundColor(VitalPalette.ashVeil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if !selectedEmoji.isEmpty {
                            presenter.selectAvatar(selectedEmoji)
                        }
                        router.dismissSheet()
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
            .onAppear {
                presenter.rebind(vault: vault, router: router)
                selectedEmoji = presenter.avatarEmoji
            }
        }
    }
}

// MARK: - Share Sheet (UIKit bridge)

struct ShareSheetView: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#if DEBUG
struct VitalSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            VitalSettingsView()
        }
        .environmentObject(VitalDataVault.shared)
        .environmentObject(VitalRouter())
        .preferredColorScheme(.dark)
    }
}
#endif
