

import SwiftUI
import Combine
// MARK: - Condition Nexus View (Root)

struct ConditionNexusView: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter = ConditionNexusPresenter(
        vault: VitalDataVault.shared,
        router: VitalRouter()
    )

    var body: some View {
        ZStack {
            PulseBackdropView(showPulseRing: false, vitalIntensity: 0.3)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Stats header
                    conditionStatsBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 14)

                    // Search
                    conditionSearchBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // Condition list
                    if presenter.conditions.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        conditionList
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 100)
                }
            }
            .overlay(alignment: .bottom) {
                bottomActions
                    .padding(.bottom, 16)
            }
        }
        .navigationTitle("Conditions")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { toolbarItems }
        .onAppear {
            presenter.rebind(vault: vault, router: router)
        }
    }

    // MARK: — Stats Bar

    private var conditionStatsBar: some View {
        HStack(spacing: 0) {
            statCell(value: "\(presenter.totalConditions)", label: "Conditions", icon: "bolt.circle.fill")
            dividerLine
            statCell(value: "\(presenter.totalRules)", label: "Rules", icon: "arrow.triangle.branch")
            dividerLine
            statCell(value: "\(presenter.customCount)", label: "Custom", icon: "plus.diamond.fill")
        }
        .padding(.vertical, 14)
        .vitalCardStyle(cornerRadius: 14)
    }

    private func statCell(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(VitalPalette.aureliaGlow)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(VitalPalette.ivoryBreath)
            }
            Text(label)
                .font(VitalTypography.microSignal())
                .foregroundColor(VitalPalette.ashVeil)
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(VitalPalette.charcoalBreath)
            .frame(width: 1, height: 30)
    }

    // MARK: — Search Bar

    private var conditionSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(VitalPalette.ashVeil)

            TextField("Search conditions…", text: $presenter.searchQuery)
                .font(VitalTypography.bodyRhythm())
                .foregroundColor(VitalPalette.ivoryBreath)
                .autocorrectionDisabled()

            if !presenter.searchQuery.isEmpty {
                Button {
                    presenter.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(VitalPalette.ashVeil)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(VitalPalette.charcoalBreath)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: — Condition List

    private var conditionList: some View {
        LazyVStack(spacing: 10) {
            ForEach(presenter.conditions) { condition in
                ConditionNexusCard(condition: condition)
                    .onTapGesture {
                        presenter.openConditionDetail(condition.id)
                    }
                    .contextMenu {
                        if !condition.isBuiltIn {
                            Button(role: .destructive) {
                                presenter.deleteCondition(condition.id)
                            } label: {
                                Label("Delete Condition", systemImage: "trash")
                            }
                        }

                        Button {
                            presenter.presentCreateRule(conditionID: condition.id)
                        } label: {
                            Label("Add Rule", systemImage: "plus.circle")
                        }
                    }
            }
        }
    }

    // MARK: — Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(VitalPalette.aureliaGlow.opacity(0.06))
                    .frame(width: 80, height: 80)

                Image(systemName: "bolt.badge.clock")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(VitalPalette.aureliaGlow.opacity(0.5))
            }

            if presenter.searchQuery.isEmpty {
                Text("No conditions yet")
                    .font(VitalTypography.sectionPulse())
                    .foregroundColor(VitalPalette.ivoryBreath)
                Text("Conditions power smart packing.\nCreate one to get started.")
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.ashVeil)
                    .multilineTextAlignment(.center)
            } else {
                Text(presenter.emptySearchMessage)
                    .font(VitalTypography.sectionPulse())
                    .foregroundColor(VitalPalette.ivoryBreath)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: — Bottom Actions

    private var bottomActions: some View {
        HStack(spacing: 12) {
            // Sandbox button
            Button {
                presenter.presentSandbox()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sandbox")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(VitalPalette.aureliaGlow)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(VitalPalette.midnightVein)
                        .overlay(
                            Capsule()
                                .stroke(VitalPalette.aureliaGlow.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            // Create condition button
            Button {
                presenter.presentCreateRule(conditionID: nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("New Rule")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(VitalPalette.obsidianPulse)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(VitalPalette.aureliaGlow)
                .clipShape(Capsule())
                .shadow(color: VitalPalette.aureliaGlow.opacity(0.3), radius: 10, y: 4)
            }
        }
    }

    // MARK: — Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    // Inline creation
                    router.presentSheet(.createRule(conditionID: nil))
                } label: {
                    Label("New Condition", systemImage: "bolt.circle.fill")
                }

                Button {
                    presenter.presentSandbox()
                } label: {
                    Label("Rule Sandbox", systemImage: "flask")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(VitalPalette.aureliaGlow)
            }
        }
    }
}

// MARK: - Condition Card

struct ConditionNexusCard: View {

    let condition: ConditionNexusPresenter.ConditionDisplayModel
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(condition.isActiveInAnySession
                          ? VitalPalette.aureliaGlow.opacity(0.12)
                          : VitalPalette.charcoalBreath)
                    .frame(width: 44, height: 44)

                Image(systemName: condition.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(condition.isActiveInAnySession
                                     ? VitalPalette.aureliaGlow
                                     : VitalPalette.boneMarrow)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(condition.name)
                        .font(VitalTypography.sectionPulse())
                        .foregroundColor(VitalPalette.ivoryBreath)
                        .lineLimit(1)

                    if condition.isActiveInAnySession {
                        Text("LIVE")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(VitalPalette.verdantPulse)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(VitalPalette.verdantPulse.opacity(0.12))
                            )
                    }
                }

                Text(condition.explanation.isEmpty ? "No description" : condition.explanation)
                    .font(VitalTypography.microSignal())
                    .foregroundColor(VitalPalette.ashVeil)
                    .lineLimit(1)
            }

            Spacer()

            // Impact stats
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 3) {
                    Text("\(condition.ruleCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(VitalPalette.honeyElixir)
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundColor(VitalPalette.ashVeil)
                }

                if condition.totalItemImpact > 0 {
                    Text("+\(condition.totalItemImpact) items")
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.verdantPulse)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(VitalPalette.ashVeil)
        }
        .padding(14)
        .vitalCardStyle(cornerRadius: 14)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
    }
}

// MARK: - Condition Detail View (replaces placeholder)

struct ConditionNexusDetailView: View {

    let conditionID: UUID
    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter = ConditionNexusPresenter(
        vault: VitalDataVault.shared,
        router: VitalRouter()
    )

    var body: some View {
        ZStack {
            PulseBackdropView(showPulseRing: false, vitalIntensity: 0.25)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Condition header
                    if let cond = presenter.detailCondition {
                        conditionHeader(cond)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    // Rules section header
                    HStack {
                        Text("Dependency Rules")
                            .font(VitalTypography.sectionPulse())
                            .foregroundColor(VitalPalette.ivoryBreath)

                        Spacer()

                        Button {
                            presenter.presentCreateRule(conditionID: conditionID)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Add")
                                    .font(VitalTypography.microSignal())
                            }
                            .foregroundColor(VitalPalette.aureliaGlow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(VitalPalette.aureliaGlow.opacity(0.12))
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Rules list
                    if presenter.detailRules.isEmpty {
                        rulesEmptyState
                            .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(presenter.detailRules) { rule in
                                RuleNerveCard(rule: rule)
                                    .contextMenu {
                                        Button {
                                            presenter.presentEditRule(rule.id)
                                        } label: {
                                            Label("Edit Rule", systemImage: "pencil")
                                        }

                                        Button(role: .destructive) {
                                            presenter.deleteRule(rule.id)
                                        } label: {
                                            Label("Delete Rule", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle(presenter.detailCondition?.name ?? "Condition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            presenter.rebind(vault: vault, router: router)
            presenter.loadConditionDetail(conditionID)
        }
    }

    private func conditionHeader(_ condition: ConditionTrigger) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(VitalPalette.aureliaGlow.opacity(0.10))
                    .frame(width: 64, height: 64)

                Image(systemName: condition.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(VitalPalette.aureliaGlow)
            }

            Text(condition.name)
                .font(VitalTypography.vitalTitle())
                .foregroundColor(VitalPalette.ivoryBreath)

            if !condition.explanation.isEmpty {
                Text(condition.explanation)
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.boneMarrow)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                infoPill(icon: "arrow.triangle.branch", value: "\(presenter.detailRules.count) rules")
                if condition.isBuiltIn {
                    infoPill(icon: "lock.fill", value: "Built-in")
                } else {
                    infoPill(icon: "person.fill", value: "Custom")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .vitalCardStyle(cornerRadius: 16)
    }

    private func infoPill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(value)
                .font(VitalTypography.microSignal())
        }
        .foregroundColor(VitalPalette.ashVeil)
    }

    private var rulesEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(VitalPalette.ashVeil)
            Text("No rules yet")
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.boneMarrow)
            Text("Add a rule to define what happens\nwhen this condition is active")
                .font(VitalTypography.microSignal())
                .foregroundColor(VitalPalette.ashVeil)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Rule Card

struct RuleNerveCard: View {

    let rule: ConditionNexusPresenter.RuleDisplayModel
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Action row
            HStack(spacing: 8) {
                Image(systemName: rule.actionIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(rule.actionColor)

                Text(rule.actionLabel)
                    .font(VitalTypography.microSignal())
                    .foregroundColor(rule.actionColor)

                Spacer()

                // Priority stars
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rule.priority ? "star.fill" : "star")
                            .font(.system(size: 8))
                            .foregroundColor(star <= rule.priority
                                             ? VitalPalette.aureliaGlow
                                             : VitalPalette.charcoalBreath)
                    }
                }
            }

            // Target
            HStack(spacing: 6) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(VitalPalette.aureliaGlow)

                Text(rule.targetName)
                    .font(VitalTypography.sectionPulse())
                    .foregroundColor(VitalPalette.ivoryBreath)
                    .lineLimit(1)
            }

            // Metadata row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                    Text(rule.targetOrganName)
                        .font(VitalTypography.microSignal())
                }
                .foregroundColor(VitalPalette.ashVeil)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9))
                    Text(rule.removalPolicyLabel)
                        .font(VitalTypography.microSignal())
                }
                .foregroundColor(VitalPalette.ashVeil)

                Spacer()
            }

            // Reason text
            if !rule.reasonText.isEmpty {
                Text("\"" + rule.reasonText + "\"")
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundColor(VitalPalette.honeyElixir.opacity(0.8))
                    .italic()
            }
        }
        .padding(14)
        .vitalCardStyle(cornerRadius: 12)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
    }
}

// MARK: - Rule Sandbox Sheet (replaces placeholder)

struct RuleNexusSandboxSheet: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter
    @StateObject private var presenter = ConditionNexusPresenter(
        vault: VitalDataVault.shared,
        router: VitalRouter()
    )

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header explanation
                        VStack(spacing: 6) {
                            Image(systemName: "flask.fill")
                                .font(.system(size: 24))
                                .foregroundColor(VitalPalette.aureliaGlow)

                            Text("Toggle conditions below to preview\nwhich items would be added")
                                .font(VitalTypography.captionMurmur())
                                .foregroundColor(VitalPalette.boneMarrow)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // Condition toggles
                        VStack(spacing: 8) {
                            ForEach(vault.conditionBank) { condition in
                                sandboxConditionRow(condition)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Results
                        if !presenter.sandboxResults.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Preview Results")
                                        .font(VitalTypography.sectionPulse())
                                        .foregroundColor(VitalPalette.ivoryBreath)

                                    Spacer()

                                    Text("\(presenter.sandboxResults.count) items")
                                        .font(VitalTypography.microSignal())
                                        .foregroundColor(VitalPalette.aureliaGlow)
                                }

                                ForEach(presenter.sandboxResults) { result in
                                    sandboxResultRow(result)
                                }
                            }
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Rule Sandbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        presenter.clearSandbox()
                    }
                    .foregroundColor(VitalPalette.ashVeil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        router.dismissSheet()
                    }
                    .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
            .onAppear {
                presenter.rebind(vault: vault, router: router)
            }
        }
    }

    private func sandboxConditionRow(_ condition: ConditionTrigger) -> some View {
        let isActive = presenter.sandboxActiveConditions.contains(condition.id)

        return HStack(spacing: 12) {
            Image(systemName: condition.icon)
                .font(.system(size: 16))
                .foregroundColor(isActive ? VitalPalette.aureliaGlow : VitalPalette.ashVeil)
                .frame(width: 24)

            Text(condition.name)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(isActive ? VitalPalette.ivoryBreath : VitalPalette.boneMarrow)

            Spacer()

            Toggle("", isOn: Binding(
                get: { isActive },
                set: { _ in presenter.toggleSandboxCondition(condition.id) }
            ))
            .tint(VitalPalette.aureliaGlow)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .vitalCardStyle(cornerRadius: 10)
    }

    private func sandboxResultRow(_ result: ConditionNexusPresenter.SandboxResultItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: result.actionType == .addItem
                  ? "plus.circle.fill"
                  : result.actionType == .makeCritical
                  ? "exclamationmark.triangle.fill"
                  : "note.text")
                .font(.system(size: 13))
                .foregroundColor(result.actionType == .addItem
                                 ? VitalPalette.verdantPulse
                                 : VitalPalette.feverSignal)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.itemName)
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.ivoryBreath)

                Text("\(result.organName) · \(result.conditionName)")
                    .font(VitalTypography.microSignal())
                    .foregroundColor(VitalPalette.ashVeil)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(VitalPalette.charcoalBreath.opacity(0.5))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ConditionNexusView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ConditionNexusView()
        }
        .environmentObject(VitalDataVault.shared)
        .environmentObject(VitalRouter())
        .preferredColorScheme(.dark)
    }
}
#endif
