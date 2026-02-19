

import SwiftUI

// MARK: - Packing Pulse View

struct PackingPulseView: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter: PackingPulsePresenter = {
        PackingPulsePresenter(vault: VitalDataVault.shared, router: VitalRouter())
    }()

    @State private var headerVisible: Bool = false

    var body: some View {
        ZStack {
            // Animated backdrop
            PulseBackdropView(showPulseRing: false, vitalIntensity: 0.35)
                .ignoresSafeArea()

            mainContent
        }
        .navigationTitle("Packing")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { toolbarItems }
        .onAppear {
            presenter.vault = vault
            presenter.router = router
            withAnimation(.easeOut(duration: 0.5)) { headerVisible = true }
        }
    }

    // MARK: — Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Gamification header
                vitalLevelHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Search bar
                vitalSearchBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                if presenter.hasAnySessions {
                    // Sort control
                    sortPicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // Active sessions
                    if !presenter.activeSessions.isEmpty {
                        sectionHeader(title: "Active", count: presenter.activeSessions.count)
                            .padding(.horizontal, 20)

                        LazyVStack(spacing: 12) {
                            ForEach(presenter.activeSessions) { session in
                                SessionHeartbeatCard(
                                    session: session,
                                    presenter: presenter
                                )
                                .onTapGesture {
                                    presenter.openSession(session)
                                }
                                .contextMenu {
                                    sessionContextMenu(for: session)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }

                    // Archive toggle
                    if !presenter.archivedSessions.isEmpty {
                        archiveSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                } else {
                    // Empty state
                    emptyStateView
                        .padding(.top, 40)
                }

                // Bottom spacer for FAB clearance
                Spacer(minLength: 100)
            }
        }
        .overlay(alignment: .bottom) {
            createSessionFAB
                .padding(.bottom, 16)
        }
    }

    // MARK: — Vital Level Header

    private var vitalLevelHeader: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(VitalPalette.aureliaGlow.opacity(0.10))
                    .frame(width: 50, height: 50)

                Text(presenter.userEmoji)
                    .font(.system(size: 30))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: vault.identity.levelIcon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(VitalPalette.aureliaGlow)

                    Text("Level \(presenter.userLevel)")
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.aureliaGlow)

                    Text("·")
                        .foregroundColor(VitalPalette.ashVeil)

                    Text(presenter.userLevelTitle)
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.boneMarrow)
                }

                // Level progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VitalPalette.charcoalBreath)
                            .frame(height: 4)

                        Capsule()
                            .fill(VitalPalette.aureliaShimmer)
                            .frame(
                                width: geo.size.width * CGFloat(presenter.levelProgressFraction),
                                height: 4
                            )
                    }
                }
                .frame(height: 4)

                Text("\(presenter.totalPackedCount) items packed total")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VitalPalette.ashVeil)
            }

            Spacer()
        }
        .padding(14)
        .vitalCardStyle(cornerRadius: 14)
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : -10)
    }

    // MARK: — Search Bar

    private var vitalSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(VitalPalette.ashVeil)

            TextField("Search sessions…", text: $presenter.searchQuery)
                .font(VitalTypography.bodyRhythm())
                .foregroundColor(VitalPalette.ivoryBreath)
                .autocorrectionDisabled()

            if !presenter.searchQuery.isEmpty {
                Button {
                    presenter.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(VitalPalette.ashVeil)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(VitalPalette.charcoalBreath)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: — Sort Picker

    private var sortPicker: some View {
        HStack {
            Text("Sort by")
                .font(VitalTypography.microSignal())
                .foregroundColor(VitalPalette.ashVeil)

            Spacer()

            Menu {
                ForEach(PackingPulsePresenter.SessionSortMode.allCases) { mode in
                    Button {
                        presenter.sortMode = mode
                    } label: {
                        HStack {
                            Text(mode.displayName)
                            if presenter.sortMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(presenter.sortMode.displayName)
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.honeyElixir)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(VitalPalette.honeyElixir)
                }
            }
        }
    }

    // MARK: — Section Header

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(VitalTypography.sectionPulse())
                .foregroundColor(VitalPalette.ivoryBreath)

            Text("\(count)")
                .font(VitalTypography.microSignal())
                .foregroundColor(VitalPalette.aureliaGlow)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(VitalPalette.aureliaGlow.opacity(0.12))
                )

            Spacer()
        }
        .padding(.bottom, 10)
    }

    // MARK: — Archive Section

    private var archiveSection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    presenter.showArchive.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 18))
                        .foregroundColor(VitalPalette.ashVeil)

                    Text("Archive")
                        .font(VitalTypography.captionMurmur())
                        .foregroundColor(VitalPalette.boneMarrow)

                    Text("\(presenter.archivedSessions.count)")
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.ashVeil)

                    Spacer()

                    Image(systemName: presenter.showArchive ? "chevron.up" : "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(VitalPalette.ashVeil)
                }
                .padding(14)
                .vitalCardStyle(cornerRadius: 12)
            }

            if presenter.showArchive {
                LazyVStack(spacing: 10) {
                    ForEach(presenter.archivedSessions) { session in
                        ArchivedSessionRow(session: session, presenter: presenter)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    // MARK: — Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(VitalPalette.aureliaGlow.opacity(0.06))
                    .frame(width: 100, height: 100)

                Image(systemName: "suitcase")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(VitalPalette.aureliaGlow.opacity(0.5))
            }

            Text(presenter.emptyStateMessage)
                .font(VitalTypography.sectionPulse())
                .foregroundColor(VitalPalette.ivoryBreath)

            Text(presenter.emptyStateSubtitle)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.ashVeil)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: — Create Session FAB

    private var createSessionFAB: some View {
        Button(action: { presenter.presentCreateSheet() }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                Text("New Session")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(VitalPalette.obsidianPulse)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(VitalPalette.aureliaGlow)
            .clipShape(Capsule())
            .shadow(color: VitalPalette.aureliaGlow.opacity(0.35), radius: 12, y: 6)
        }
    }

    // MARK: — Context Menu

    @ViewBuilder
    private func sessionContextMenu(for session: PackingHeartbeat) -> some View {
        Button {
            presenter.duplicateSession(session)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Button {
            presenter.archiveSession(session)
        } label: {
            Label("Archive", systemImage: "archivebox")
        }

        Divider()

        Button(role: .destructive) {
            presenter.deleteSession(session)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: — Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.presentCreateSheet()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(VitalPalette.aureliaGlow)
            }
        }
    }
}

// MARK: - Session Heartbeat Card

struct SessionHeartbeatCard: View {

    let session: PackingHeartbeat
    let presenter: PackingPulsePresenter

    @State private var appeared: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: type icon + title + countdown
            HStack(spacing: 10) {
                // Archetype icon
                ZStack {
                    Circle()
                        .fill(presenter.urgencyLevel(for: session).accentColor.opacity(0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: session.archetype.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(presenter.urgencyLevel(for: session).accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(VitalTypography.sectionPulse())
                        .foregroundColor(VitalPalette.ivoryBreath)
                        .lineLimit(1)

                    Text(session.archetype.displayName)
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.ashVeil)
                }

                Spacer()

                // Countdown badge
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: presenter.urgencyLevel(for: session).icon)
                            .font(.system(size: 14, weight: .bold))
                        Text(presenter.countdownText(for: session))
                            .font(VitalTypography.microSignal())
                    }
                    .foregroundColor(presenter.urgencyLevel(for: session).accentColor)
                }
            }

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VitalPalette.charcoalBreath)
                            .frame(height: 6)

                        Capsule()
                            .fill(presenter.progressColor(for: session))
                            .frame(
                                width: geo.size.width * CGFloat(session.vitalSigns.progressFraction),
                                height: 6
                            )
                            .animation(.spring(response: 0.5), value: session.vitalSigns.progressFraction)
                    }
                }
                .frame(height: 6)

                // Progress stats row
                HStack {
                    Text(presenter.progressText(for: session))
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.boneMarrow)

                    Spacer()

                    if let critical = presenter.criticalText(for: session) {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                            Text(critical)
                                .font(VitalTypography.microSignal())
                        }
                        .foregroundColor(VitalPalette.emberCore)
                    }

                    Text("\(session.vitalSigns.progressPercent)%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(presenter.progressColor(for: session))
                }
            }

            // Section pills (quick overview of top sections)
            if !session.organs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(session.organs.prefix(5)) { organ in
                            organPill(organ)
                        }
                    }
                }
            }
        }
        .padding(16)
        .vitalGoldCardStyle(cornerRadius: 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    private func organPill(_ organ: PackingOrgan) -> some View {
        HStack(spacing: 4) {
            Image(systemName: organ.designation.icon)
                .font(.system(size: 13))

            Text("\(organ.organVitals.packedCells)/\(organ.organVitals.totalCells)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundColor(
            organ.organVitals.isComplete
                ? VitalPalette.verdantPulse
                : VitalPalette.boneMarrow
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    (organ.organVitals.isComplete
                        ? VitalPalette.verdantPulse.opacity(0.10)
                        : VitalPalette.charcoalBreath) as Color
                )
        )
    }
}

// MARK: - Archived Session Row

struct ArchivedSessionRow: View {

    let session: PackingHeartbeat
    let presenter: PackingPulsePresenter

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.archetype.icon)
                .font(.system(size: 18))
                .foregroundColor(VitalPalette.ashVeil)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.boneMarrow)
                    .lineLimit(1)

                Text("\(session.vitalSigns.progressPercent)% packed")
                    .font(VitalTypography.microSignal())
                    .foregroundColor(VitalPalette.ashVeil)
            }

            Spacer()

            // Restore button
            Button {
                presenter.unarchiveSession(session)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(VitalPalette.honeyElixir)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(VitalPalette.honeyElixir.opacity(0.10))
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .vitalCardStyle(cornerRadius: 12)
    }
}

// MARK: - Presenter Dependency Injection Fix

extension PackingPulsePresenter {
    /// Allow re-binding after EnvironmentObject injection.
    var vault: VitalDataVault {
        get { _vault }
        set {
            guard _vault !== newValue else { return }
            _vault = newValue
            bindToVault()
        }
    }

    var router: VitalRouter {
        get { _router }
        set { _router = newValue }
    }

    // Expose private stored props via underscored names
    private var _vault: VitalDataVault {
        get { vaultStorage }
        set { vaultStorage = newValue }
    }

    private var _router: VitalRouter {
        get { routerStorage }
        set { routerStorage = newValue }
    }
}

// To make the presenter work with both direct init and EnvironmentObject rebinding,
// we use internal storage. This is a workaround for the separation of View and ViewModel files.
extension PackingPulsePresenter {
    private static var vaultKey: UInt8 = 0
    private static var routerKey: UInt8 = 0

    var vaultStorage: VitalDataVault {
        get { objc_getAssociatedObject(self, &Self.vaultKey) as? VitalDataVault ?? VitalDataVault.shared }
        set { objc_setAssociatedObject(self, &Self.vaultKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var routerStorage: VitalRouter {
        get { objc_getAssociatedObject(self, &Self.routerKey) as? VitalRouter ?? VitalRouter() }
        set { objc_setAssociatedObject(self, &Self.routerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - Preview

#if DEBUG
struct PackingPulseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PackingPulseView()
        }
        .environmentObject(VitalDataVault.shared)
        .environmentObject(VitalRouter())
        .preferredColorScheme(.dark)
    }
}
#endif
