// C13App.swift
// c13 — Smart Packing Companion
//
// App entry point. Orchestrates the three lifecycle phases:
//   1. VitalLaunchGateway — animated loading screen
//   2. VitalOnboardingJourney — first-run walkthrough
//   3. VitalNervousSystem — main TabView with 3 tabs
//
// Global overlays: sheets, alerts, undo toasts.

import SwiftUI
import Combine
// MARK: - App Entry

@main
struct C13App: App {

    @StateObject private var vault = VitalDataVault.shared
    @StateObject private var router = VitalRouter()

    var body: some Scene {
        WindowGroup {
            VitalLifecycleGate()
                .environmentObject(vault)
                .environmentObject(router)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Lifecycle Gate (Launch → Onboarding → Main)

/// Controls the three phases of the app lifecycle.
struct VitalLifecycleGate: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    @State private var phase: LifecyclePhase = .launching

    enum LifecyclePhase {
        case launching
        case onboarding
        case alive
    }

    var body: some View {
        ZStack {
            switch phase {
            case .launching:
                VitalLaunchGateway(onFinished: advanceFromLaunch)
                    .transition(.opacity)

            case .onboarding:
                VitalOnboardingJourney(onComplete: advanceFromOnboarding)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))

            case .alive:
                VitalNervousSystem()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
    }

    private func advanceFromLaunch() {
        if vault.onboardingVitals.hasCompletedOnboarding {
            phase = .alive
        } else {
            phase = .onboarding
        }
    }

    private func advanceFromOnboarding() {
        withAnimation(.easeInOut(duration: 0.5)) {
            phase = .alive
        }
    }
}

// MARK: - Vital Nervous System (Main TabView)

/// The main app shell with 3 tabs and global overlay management.
struct VitalNervousSystem: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab container
            TabView(selection: $router.activeTab) {
                packingTab
                    .tag(VitalRouter.VitalTab.packing)

                conditionsTab
                    .tag(VitalRouter.VitalTab.conditions)

                settingsTab
                    .tag(VitalRouter.VitalTab.settings)
            }
            .tint(VitalPalette.aureliaGlow)

            // Global toast overlay
            if let toast = router.activeToast {
                VitalToastBanner(toast: toast, onDismiss: { router.dismissToast() }) { actionTag in
                    _ = vault.performUndo(actionTag: actionTag)
                    router.dismissToast()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: router.activeToast)
                .padding(.bottom, 90)
                .zIndex(100)
            }
        }
        // Global sheet resolver
        .sheet(item: $router.activeSheet) { sheet in
            VitalSheetResolver(sheet: sheet)
                .environmentObject(router)
                .environmentObject(vault)
                .presentationDetents(sheetDetents(for: sheet))
                .presentationDragIndicator(.visible)
        }
        // Global alert resolver
        .alert(item: $router.activeAlert) { alert in
            buildAlert(for: alert)
        }
    }

    // MARK: — Tab 1: Packing

    private var packingTab: some View {
        NavigationStack(path: $router.packingPath) {
            PackingPulseView()
                .navigationDestination(for: VitalDestination.self) { destination in
                    VitalDestinationResolver(destination: destination)
                }
        }
        .tabItem {
            Label(
                VitalRouter.VitalTab.packing.label,
                systemImage: VitalRouter.VitalTab.packing.icon
            )
        }
    }

    // MARK: — Tab 2: Conditions

    private var conditionsTab: some View {
        NavigationStack(path: $router.conditionsPath) {
            ConditionNexusView()
                .navigationDestination(for: VitalDestination.self) { destination in
                    VitalDestinationResolver(destination: destination)
                }
        }
        .tabItem {
            Label(
                VitalRouter.VitalTab.conditions.label,
                systemImage: VitalRouter.VitalTab.conditions.icon
            )
        }
    }

    // MARK: — Tab 3: Settings

    private var settingsTab: some View {
        NavigationStack(path: $router.settingsPath) {
            VitalSettingsView()
                .navigationDestination(for: VitalDestination.self) { destination in
                    VitalDestinationResolver(destination: destination)
                }
        }
        .tabItem {
            Label(
                VitalRouter.VitalTab.settings.label,
                systemImage: VitalRouter.VitalTab.settings.icon
            )
        }
    }

    // MARK: — Sheet Detents

    private func sheetDetents(for sheet: VitalSheet) -> Set<PresentationDetent> {
        switch sheet {
        case .createSession:
            return [.large]
        case .addItem:
            return [.medium, .large]
        case .editItem:
            return [.medium]
        case .editOrgan:
            return [.medium]
        case .sessionConditions:
            return [.medium, .large]
        case .sessionReminders:
            return [.medium]
        case .editSession:
            return [.large]
        case .itemReason:
            return [.fraction(0.45)]
        case .createRule, .editRule:
            return [.large]
        case .ruleSandbox:
            return [.large]
        case .avatarPicker:
            return [.medium]
        case .shareSession:
            return [.large]
        }
    }

    // MARK: — Alert Builder

    private func buildAlert(for alert: VitalAlert) -> Alert {
        switch alert {
        case .confirmDeleteSession(let id):
            return Alert(
                title: Text("Delete Session?"),
                message: Text("This packing session and all its items will be permanently removed."),
                primaryButton: .destructive(Text("Delete")) {
                    vault.deleteHeartbeat(id: id)
                    router.showToast("Session deleted", style: .info)
                },
                secondaryButton: .cancel()
            )

        case .confirmDeleteItem(let sid, let oid, let cid):
            return Alert(
                title: Text("Remove Item?"),
                message: Text("This item will be removed from your packing list."),
                primaryButton: .destructive(Text("Remove")) {
                    vault.deleteCell(sessionID: sid, organID: oid, cellID: cid)
                    router.showUndoToast("Item removed", actionTag: "delete_item")
                },
                secondaryButton: .cancel()
            )

        case .confirmBulkMark(let sid, let oid):
            return Alert(
                title: Text("Mark All Packed?"),
                message: Text("Every item in this section will be marked as packed."),
                primaryButton: .default(Text("Mark All")) {
                    vault.markOrganComplete(sessionID: sid, organID: oid)
                    router.showToast("Section complete!", style: .success)
                },
                secondaryButton: .cancel()
            )

        case .confirmResetOrgan(let sid, let oid):
            return Alert(
                title: Text("Reset Section?"),
                message: Text("All items in this section will be set back to unpacked."),
                primaryButton: .destructive(Text("Reset")) {
                    vault.resetOrgan(sessionID: sid, organID: oid)
                    router.showToast("Section reset", style: .info)
                },
                secondaryButton: .cancel()
            )

        case .confirmResetAllData:
            return Alert(
                title: Text("Reset All Data?"),
                message: Text("This will erase all sessions, rules, statistics, and preferences. This cannot be undone."),
                primaryButton: .destructive(Text("Reset Everything")) {
                    vault.resetAllData()
                    router.showToast("All data cleared", style: .warning)
                },
                secondaryButton: .cancel()
            )

        case .confirmArchiveSession(let id):
            return Alert(
                title: Text("Archive Session?"),
                message: Text("This session will be moved to your archive."),
                primaryButton: .default(Text("Archive")) {
                    vault.archiveHeartbeat(id: id)
                    router.showToast("Session archived", style: .info)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Toast Banner

/// A transient bottom banner for feedback and undo actions.
struct VitalToastBanner: View {

    let toast: VitalToast
    let onDismiss: () -> Void
    var onUndo: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            toastIcon
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(toastColor)

            // Message
            Text(toast.message)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.ivoryBreath)
                .lineLimit(1)

            Spacer()

            // Undo button (if applicable)
            if let undo = toast.undoAction {
                Button(action: {
                    onUndo?(undo.actionTag)
                }) {
                    Text(undo.label)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(VitalPalette.aureliaGlow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(VitalPalette.aureliaGlow.opacity(0.15))
                        )
                }
            } else {
                // Close button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(VitalPalette.ashVeil)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VitalPalette.charcoalBreath)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(toastColor.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 12, y: 6)
        )
        .padding(.horizontal, 16)
    }

    private var toastIcon: Image {
        switch toast.style {
        case .success: return Image(systemName: "checkmark.circle.fill")
        case .info:    return Image(systemName: "info.circle.fill")
        case .undo:    return Image(systemName: "arrow.uturn.backward.circle.fill")
        case .warning: return Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var toastColor: Color {
        switch toast.style {
        case .success: return VitalPalette.verdantPulse
        case .info:    return VitalPalette.cyanVital
        case .undo:    return VitalPalette.aureliaGlow
        case .warning: return VitalPalette.feverSignal
        }
    }
}

// MARK: - Lifecycle Phase Equatable

extension VitalLifecycleGate.LifecyclePhase: Equatable {}

// MARK: - Preview

#if DEBUG
struct C13App_Previews: PreviewProvider {
    static var previews: some View {
        VitalLifecycleGate()
            .environmentObject(VitalDataVault.shared)
            .environmentObject(VitalRouter())
            .preferredColorScheme(.dark)
    }
}
#endif
