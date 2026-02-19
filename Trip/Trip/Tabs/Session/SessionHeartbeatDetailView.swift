

import SwiftUI

// MARK: - Session Heartbeat Detail View

struct SessionHeartbeatDetailView: View {

    let sessionID: UUID
    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter: SessionHeartbeatPresenter

    @State private var headerVisible = false
    @State private var progressAnimated = false

    init(sessionID: UUID) {
        self.sessionID = sessionID
        _presenter = StateObject(wrappedValue: SessionHeartbeatPresenter(
            sessionID: sessionID,
            vault: VitalDataVault.shared,
            router: VitalRouter()
        ))
    }

    var body: some View {
        ZStack {
            PulseBackdropView(showPulseRing: false, vitalIntensity: 0.25)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Progress hero
                    progressHero
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Filter pills
                    filterPills
                        .padding(.bottom, 14)

                    // Search bar
                    itemSearchBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)

                    // Organ sections
                    organsList
                        .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
            }
            .overlay(alignment: .bottom) {
                bottomActionBar
                    .padding(.bottom, 12)
            }
        }
        .navigationTitle(presenter.sessionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { toolbarContent }
        .onAppear {
            presenter.rebind(vault: vault, router: router)
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                headerVisible = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                progressAnimated = true
            }
        }
    }

    // =========================================================================
    // MARK: — Progress Hero
    // =========================================================================

    private var progressHero: some View {
        VStack(spacing: 16) {
            // Countdown + archetype
            HStack(spacing: 8) {
                Image(systemName: presenter.archetypeIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VitalPalette.aureliaGlow)

                Text(presenter.archetypeDisplay)
                    .font(VitalTypography.microSignal())
                    .foregroundColor(VitalPalette.boneMarrow)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(presenter.countdownColor)
                        .frame(width: 6, height: 6)

                    Text(presenter.countdownText)
                        .font(VitalTypography.microSignal())
                        .foregroundColor(presenter.countdownColor)
                }
            }

            // Progress ring + stats
            HStack(spacing: 24) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(VitalPalette.charcoalBreath, lineWidth: 8)
                        .frame(width: 90, height: 90)

                    Circle()
                        .trim(from: 0, to: progressAnimated ? CGFloat(presenter.progressFraction) : 0)
                        .stroke(
                            presenter.progressColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: presenter.progressFraction)

                    VStack(spacing: 0) {
                        Text("\(presenter.progressPercent)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(presenter.progressColor)

                        Text("%")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.ashVeil)
                    }
                }

                // Stats column
                VStack(alignment: .leading, spacing: 8) {
                    progressStatRow(
                        icon: "checkmark.circle.fill",
                        label: "Packed",
                        value: "\(presenter.packedCells)",
                        color: VitalPalette.verdantPulse
                    )
                    progressStatRow(
                        icon: "circle.dashed",
                        label: "Remaining",
                        value: "\(presenter.remainingCells)",
                        color: VitalPalette.honeyElixir
                    )
                    progressStatRow(
                        icon: "exclamationmark.triangle.fill",
                        label: "Critical",
                        value: "\(presenter.criticalRemaining)",
                        color: presenter.criticalRemaining > 0
                            ? VitalPalette.emberCore
                            : VitalPalette.ashVeil
                    )
                    if presenter.ruleAddedCount > 0 {
                        progressStatRow(
                            icon: "bolt.badge.clock.fill",
                            label: "Smart",
                            value: "\(presenter.ruleAddedCount)",
                            color: VitalPalette.cyanVital
                        )
                    }
                }

                Spacer()
            }

            // Progress message
            Text(presenter.progressMessage)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.boneMarrow)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Critical warning
            if let warning = presenter.criticalWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(warning)
                        .font(VitalTypography.microSignal())
                }
                .foregroundColor(VitalPalette.emberCore)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(VitalPalette.emberCore.opacity(0.08))
                )
            }
        }
        .padding(18)
        .vitalGoldCardStyle(cornerRadius: 18)
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 15)
    }

    private func progressStatRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16)

            Text(label)
                .font(VitalTypography.microSignal())
                .foregroundColor(VitalPalette.ashVeil)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }

    // =========================================================================
    // MARK: — Filter Pills
    // =========================================================================

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VitalFilter.allCases) { filter in
                    FilterPillButton(
                        filter: filter,
                        count: presenter.filterCount(for: filter),
                        isActive: presenter.activeFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            presenter.activeFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // =========================================================================
    // MARK: — Search Bar
    // =========================================================================

    private var itemSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(VitalPalette.ashVeil)

            TextField("Search items…", text: $presenter.searchQuery)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.ivoryBreath)
                .autocorrectionDisabled()

            if !presenter.searchQuery.isEmpty {
                Button {
                    presenter.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(VitalPalette.ashVeil)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(VitalPalette.charcoalBreath)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // =========================================================================
    // MARK: — Organs List
    // =========================================================================

    private var organsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(presenter.displayOrgans) { organ in
                OrganSectionCard(
                    organ: organ,
                    isExpanded: presenter.expandedOrganIDs.contains(organ.id),
                    onToggleExpand: { presenter.toggleOrganExpanded(organ.id) },
                    onMarkComplete: { presenter.markOrganComplete(organ.id) },
                    onResetOrgan: { presenter.resetOrgan(organ.id) },
                    onAddItem: { presenter.presentAddItem(preselectedOrganID: organ.id) },
                    onTogglePacked: { cellID in presenter.toggleCellPacked(cellID, organID: organ.id) },
                    onToggleCritical: { cellID in presenter.toggleCellCritical(cellID, organID: organ.id) },
                    onDeleteCell: { cellID in presenter.deleteCell(cellID, organID: organ.id) },
                    onShowReason: { cellID in presenter.showItemReason(cellID, organID: organ.id) },
                    onEditCell: { cellID in presenter.presentEditItem(cellID: cellID, organID: organ.id) }
                )
            }
        }
    }

    // =========================================================================
    // MARK: — Bottom Action Bar
    // =========================================================================

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            // Conditions button
            Button {
                presenter.presentConditionsSheet()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 14))
                    Text("Conditions")
                        .font(VitalTypography.microSignal())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundColor(VitalPalette.aureliaGlow)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(VitalPalette.midnightVein)
                        .overlay(
                            Capsule()
                                .stroke(VitalPalette.aureliaGlow.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // Reminders button
            Button {
                presenter.presentRemindersSheet()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13))
                    Text("Reminders")
                        .font(VitalTypography.microSignal())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundColor(VitalPalette.boneMarrow)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(VitalPalette.midnightVein)
                        .overlay(
                            Capsule()
                                .stroke(VitalPalette.charcoalBreath, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Add item FAB
            Button {
                presenter.presentAddItem()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Item")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundColor(VitalPalette.obsidianPulse)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(VitalPalette.aureliaGlow)
                .clipShape(Capsule())
                .shadow(color: VitalPalette.aureliaGlow.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(.horizontal, 20)
    }

    // =========================================================================
    // MARK: — Toolbar
    // =========================================================================

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    presenter.presentEditSessionSheet()
                } label: {
                    Label("Edit Session", systemImage: "pencil")
                }

                Button {
                    presenter.shareSession()
                } label: {
                    Label("Share List", systemImage: "square.and.arrow.up")
                }

                Button {
                    presenter.archiveSession()
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }

                Divider()

                Button(role: .destructive) {
                    presenter.deleteSession()
                } label: {
                    Label("Delete Session", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(VitalPalette.aureliaGlow)
            }
        }
    }
}

// MARK: - Filter Pill Button

struct FilterPillButton: View {

    let filter: VitalFilter
    let count: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11, weight: .semibold))

                Text(filter.displayName)
                    .font(VitalTypography.microSignal())

                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(isActive
                                  ? VitalPalette.obsidianPulse.opacity(0.3)
                                  : VitalPalette.charcoalBreath)
                    )
            }
            .foregroundColor(isActive ? VitalPalette.obsidianPulse : VitalPalette.boneMarrow)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive
                          ? VitalPalette.aureliaGlow
                          : VitalPalette.midnightVein)
            )
            .overlay(
                Capsule()
                    .stroke(isActive
                            ? Color.clear
                            : VitalPalette.charcoalBreath,
                            lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Organ Section Card

struct OrganSectionCard: View {

    let organ: SessionHeartbeatPresenter.OrganDisplayModel
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onMarkComplete: () -> Void
    let onResetOrgan: () -> Void
    let onAddItem: () -> Void
    let onTogglePacked: (UUID) -> Void
    let onToggleCritical: (UUID) -> Void
    let onDeleteCell: (UUID) -> Void
    let onShowReason: (UUID) -> Void
    let onEditCell: (UUID) -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            organHeader
                .contentShape(Rectangle())
                .onTapGesture { onToggleExpand() }

            // Items (collapsible)
            if isExpanded {
                Divider()
                    .background(VitalPalette.charcoalBreath.opacity(0.5))
                    .padding(.horizontal, 14)

                VStack(spacing: 2) {
                    ForEach(organ.cells) { cell in
                        CellRow(
                            cell: cell,
                            onTogglePacked: { onTogglePacked(cell.id) },
                            onToggleCritical: { onToggleCritical(cell.id) },
                            onDelete: { onDeleteCell(cell.id) },
                            onShowReason: { onShowReason(cell.id) },
                            onEdit: { onEditCell(cell.id) }
                        )
                    }
                }
                .padding(.vertical, 6)

                // Section actions
                sectionActions
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .vitalCardStyle(cornerRadius: 14)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
    }

    // MARK: — Organ Header

    private var organHeader: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(organ.isComplete
                          ? VitalPalette.verdantPulse.opacity(0.12)
                          : VitalPalette.charcoalBreath)
                    .frame(width: 34, height: 34)

                Image(systemName: organ.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(organ.isComplete
                                     ? VitalPalette.verdantPulse
                                     : VitalPalette.boneMarrow)
            }

            // Name + progress
            VStack(alignment: .leading, spacing: 3) {
                Text(organ.displayName)
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.ivoryBreath)

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VitalPalette.charcoalBreath)
                            .frame(height: 3)

                        Capsule()
                            .fill(organ.isComplete
                                  ? VitalPalette.verdantPulse
                                  : VitalPalette.aureliaGlow)
                            .frame(width: geo.size.width * CGFloat(organ.progressFraction), height: 3)
                            .animation(.spring(response: 0.4), value: organ.progressFraction)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            // Count
            Text("\(organ.packedCells)/\(organ.totalCells)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(organ.isComplete
                                 ? VitalPalette.verdantPulse
                                 : VitalPalette.boneMarrow)

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(VitalPalette.ashVeil)
        }
        .padding(14)
    }

    // MARK: — Section Actions

    private var sectionActions: some View {
        HStack(spacing: 8) {
            Button(action: onAddItem) {
                sectionActionLabel(icon: "plus", text: "Add")
            }

            if !organ.isComplete {
                Button(action: onMarkComplete) {
                    sectionActionLabel(icon: "checkmark.circle", text: "Pack All")
                }
            }

            Button(action: onResetOrgan) {
                sectionActionLabel(icon: "arrow.counterclockwise", text: "Reset")
            }

            Spacer()

            if organ.criticalRemaining > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text("\(organ.criticalRemaining)")
                        .font(VitalTypography.microSignal())
                }
                .foregroundColor(VitalPalette.emberCore)
            }
        }
    }

    private func sectionActionLabel(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(VitalTypography.microSignal())
        }
        .foregroundColor(VitalPalette.honeyElixir)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(VitalPalette.honeyElixir.opacity(0.08))
        )
    }
}

// MARK: - Cell Row

struct CellRow: View {

    let cell: SessionHeartbeatPresenter.CellDisplayModel
    let onTogglePacked: () -> Void
    let onToggleCritical: () -> Void
    let onDelete: () -> Void
    let onShowReason: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onTogglePacked) {
                Image(systemName: cell.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(cell.isPacked
                                     ? VitalPalette.verdantPulse
                                     : VitalPalette.ashVeil)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(cell.name)
                        .font(VitalTypography.captionMurmur())
                        .foregroundColor(cell.isPacked
                                         ? VitalPalette.ashVeil
                                         : VitalPalette.ivoryBreath)
                        .strikethrough(cell.isPacked, color: VitalPalette.ashVeil)

                    if cell.quantity > 1 {
                        Text("×\(cell.quantity)")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.ashVeil)
                    }
                }

                // Badges + reason
                HStack(spacing: 6) {
                    if cell.isCritical {
                        cellBadge(text: "Critical", color: VitalPalette.emberCore)
                    }

                    if cell.hasRuleLineage {
                        cellBadge(text: "Smart", color: VitalPalette.cyanVital)
                    }

                    if let reason = cell.reasonPulse, !reason.isEmpty {
                        Text(reason)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(VitalPalette.ashVeil)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(VitalPalette.aureliaGlow)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onToggleCritical()
            } label: {
                Label(
                    cell.isCritical ? "Unmark" : "Critical",
                    systemImage: cell.isCritical ? "star.slash" : "exclamationmark.triangle"
                )
            }
            .tint(VitalPalette.feverSignal)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onTogglePacked()
            } label: {
                Label(
                    cell.isPacked ? "Unpack" : "Pack",
                    systemImage: cell.isPacked ? "xmark.circle" : "checkmark.circle"
                )
            }
            .tint(VitalPalette.verdantPulse)
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onTogglePacked()
            } label: {
                Label(cell.isPacked ? "Mark Unpacked" : "Mark Packed",
                      systemImage: cell.isPacked ? "circle" : "checkmark.circle.fill")
            }

            Button {
                onToggleCritical()
            } label: {
                Label(cell.isCritical ? "Remove Critical" : "Mark Critical",
                      systemImage: cell.isCritical ? "star.slash" : "exclamationmark.triangle.fill")
            }

            if cell.hasRuleLineage {
                Button {
                    onShowReason()
                } label: {
                    Label("Why Is This Here?", systemImage: "questionmark.circle")
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func cellBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}

// MARK: - Preview

#if DEBUG
struct SessionHeartbeatDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SessionHeartbeatDetailView(sessionID: UUID())
        }
        .environmentObject(VitalDataVault.shared)
        .environmentObject(VitalRouter())
        .preferredColorScheme(.dark)
    }
}
#endif
