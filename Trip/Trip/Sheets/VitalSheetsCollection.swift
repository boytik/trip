
import SwiftUI
import UserNotifications

// ============================================================================
// MARK: - 1. Create Session Sheet
// ============================================================================

struct VitalCreateSessionSheet: View {

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    @State private var title: String = ""
    @State private var archetype: JourneyArchetype = .urbanExplorer
    @State private var departure: Date = Calendar.current.date(
        byAdding: .hour, value: 24, to: Date()
    ) ?? Date()
    @State private var selectedConditions: Set<UUID> = []
    @State private var currentStep: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Step indicator
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                Capsule()
                                    .fill(i <= currentStep
                                          ? VitalPalette.aureliaGlow
                                          : VitalPalette.charcoalBreath)
                                    .frame(width: i == currentStep ? 24 : 8, height: 4)
                                    .animation(.spring(response: 0.3), value: currentStep)
                            }
                        }
                        .padding(.top, 8)

                        switch currentStep {
                        case 0: stepNameAndType
                        case 1: stepDeparture
                        default: stepConditions
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { router.dismissSheet() }
                        .foregroundColor(VitalPalette.ashVeil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if currentStep < 2 {
                        Button("Next") { withAnimation { currentStep += 1 } }
                            .foregroundColor(VitalPalette.aureliaGlow)
                            .disabled(currentStep == 0 && title.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        Button("Create") { createSession() }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(VitalPalette.aureliaGlow)
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
        }
    }

    // Step 1: Name + Type
    private var stepNameAndType: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Name your trip")
                .font(VitalTypography.vitalTitle())
                .foregroundColor(VitalPalette.ivoryBreath)

            TextField("e.g. Weekend at the Coast", text: $title)
                .font(VitalTypography.bodyRhythm())
                .foregroundColor(VitalPalette.ivoryBreath)
                .padding(14)
                .background(VitalPalette.charcoalBreath)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Choose trip type")
                .font(VitalTypography.sectionPulse())
                .foregroundColor(VitalPalette.ivoryBreath)
                .padding(.top, 8)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(JourneyArchetype.allCases) { arch in
                    archetypeCard(arch)
                }
            }
        }
    }

    private func archetypeCard(_ arch: JourneyArchetype) -> some View {
        let selected = archetype == arch
        return VStack(spacing: 8) {
            Image(systemName: arch.icon)
                .font(.system(size: 24))
                .foregroundColor(selected ? VitalPalette.aureliaGlow : VitalPalette.boneMarrow)

            Text(arch.displayName)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(selected ? VitalPalette.ivoryBreath : VitalPalette.boneMarrow)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(selected ? VitalPalette.aureliaGlow.opacity(0.10) : VitalPalette.midnightVein)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? VitalPalette.aureliaGlow.opacity(0.5) : VitalPalette.charcoalBreath, lineWidth: selected ? 1.5 : 0.5)
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) { archetype = arch }
        }
    }

    // Step 2: Departure
    private var stepDeparture: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("When do you leave?")
                .font(VitalTypography.vitalTitle())
                .foregroundColor(VitalPalette.ivoryBreath)

            Text("We'll schedule reminders at 24h, 6h, and 2h before departure")
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.boneMarrow)

            DatePicker("Departure", selection: $departure, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .tint(VitalPalette.aureliaGlow)
                .colorScheme(.dark)
                .padding(14)
                .vitalCardStyle(cornerRadius: 14)

            if currentStep > 0 {
                Button { withAnimation { currentStep -= 1 } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text("Back").font(VitalTypography.captionMurmur())
                    }
                    .foregroundColor(VitalPalette.ashVeil)
                }
            }
        }
    }

    // Step 3: Conditions
    private var stepConditions: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set conditions")
                .font(VitalTypography.vitalTitle())
                .foregroundColor(VitalPalette.ivoryBreath)

            Text("Toggle what applies — your list will adapt automatically")
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.boneMarrow)

            VStack(spacing: 8) {
                ForEach(vault.conditionBank) { cond in
                    conditionToggleRow(cond)
                }
            }

            if !selectedConditions.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(VitalPalette.aureliaGlow)
                    Text("\(selectedConditions.count) active — smart items will be added")
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.honeyElixir)
                }
            }

            if currentStep > 0 {
                Button { withAnimation { currentStep -= 1 } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text("Back").font(VitalTypography.captionMurmur())
                    }
                    .foregroundColor(VitalPalette.ashVeil)
                }
            }
        }
    }

    private func conditionToggleRow(_ cond: ConditionTrigger) -> some View {
        let active = selectedConditions.contains(cond.id)
        return HStack(spacing: 12) {
            Image(systemName: cond.icon)
                .font(.system(size: 15))
                .foregroundColor(active ? VitalPalette.aureliaGlow : VitalPalette.ashVeil)
                .frame(width: 22)

            Text(cond.name)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(active ? VitalPalette.ivoryBreath : VitalPalette.boneMarrow)

            Spacer()

            Toggle("", isOn: Binding(
                get: { active },
                set: { _ in
                    if active { selectedConditions.remove(cond.id) }
                    else { selectedConditions.insert(cond.id) }
                }
            ))
            .tint(VitalPalette.aureliaGlow)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .vitalCardStyle(cornerRadius: 10)
    }

    private func createSession() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let session = vault.createHeartbeat(
            title: trimmed,
            archetype: archetype,
            departure: departure,
            conditionIDs: selectedConditions
        )

        router.dismissSheet()
        router.showToast("Session created!", style: .success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            router.navigateTo(.sessionDetail(sessionID: session.id))
        }
    }
}

// ============================================================================
// MARK: - 2. Add Item Sheet
// ============================================================================

struct VitalAddItemSheet: View {

    let sessionID: UUID
    let preselectedOrganID: UUID?

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    @State private var name: String = ""
    @State private var selectedOrganID: UUID?
    @State private var quantity: Int = 1
    @State private var isCritical: Bool = false
    @State private var note: String = ""

    private var organs: [PackingOrgan] {
        vault.heartbeat(byID: sessionID)?.organs ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Item Name")
                            TextField("e.g. Sunscreen", text: $name)
                                .font(VitalTypography.bodyRhythm())
                                .foregroundColor(VitalPalette.ivoryBreath)
                                .padding(12)
                                .background(VitalPalette.charcoalBreath)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Section picker
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Section")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(organs) { organ in
                                        organChip(organ)
                                    }
                                }
                            }
                        }

                        // Quantity
                        HStack {
                            fieldLabel("Quantity")
                            Spacer()
                            HStack(spacing: 14) {
                                Button {
                                    if quantity > 1 { quantity -= 1 }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(VitalPalette.ashVeil)
                                }

                                Text("\(quantity)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(VitalPalette.ivoryBreath)
                                    .frame(width: 30)

                                Button {
                                    if quantity < 99 { quantity += 1 }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(VitalPalette.aureliaGlow)
                                }
                            }
                        }

                        // Critical toggle
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(VitalPalette.emberCore)
                            Text("Mark as Critical")
                                .font(VitalTypography.captionMurmur())
                                .foregroundColor(VitalPalette.ivoryBreath)
                            Spacer()
                            Toggle("", isOn: $isCritical)
                                .tint(VitalPalette.emberCore)
                                .labelsHidden()
                        }
                        .padding(12)
                        .vitalCardStyle(cornerRadius: 10)

                        // Note
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Note (optional)")
                            TextField("Any details…", text: $note, axis: .vertical)
                                .font(VitalTypography.captionMurmur())
                                .foregroundColor(VitalPalette.ivoryBreath)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(VitalPalette.charcoalBreath)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { router.dismissSheet() }
                        .foregroundColor(VitalPalette.ashVeil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { saveItem() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VitalPalette.aureliaGlow)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedOrganID == nil)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
            .onAppear {
                selectedOrganID = preselectedOrganID ?? organs.first?.id
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(VitalTypography.microSignal())
            .foregroundColor(VitalPalette.ashVeil)
    }

    private func organChip(_ organ: PackingOrgan) -> some View {
        let selected = selectedOrganID == organ.id
        return HStack(spacing: 5) {
            Image(systemName: organ.designation.icon)
                .font(.system(size: 11))
            Text(organ.displayName)
                .font(VitalTypography.microSignal())
        }
        .foregroundColor(selected ? VitalPalette.obsidianPulse : VitalPalette.boneMarrow)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selected ? VitalPalette.aureliaGlow : VitalPalette.midnightVein)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(selected ? Color.clear : VitalPalette.charcoalBreath, lineWidth: 0.5))
        .onTapGesture {
            withAnimation(.spring(response: 0.25)) { selectedOrganID = organ.id }
        }
    }

    private func saveItem() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let organID = selectedOrganID else { return }

        vault.addCell(
            sessionID: sessionID,
            organID: organID,
            name: trimmed,
            quantity: quantity,
            isCritical: isCritical,
            note: note.isEmpty ? nil : note
        )
        router.dismissSheet()
        router.showToast("Item added", style: .success)
    }
}

// ============================================================================
// MARK: - 2b. Edit Item Sheet
// ============================================================================

struct VitalEditItemSheet: View {

    let sessionID: UUID
    let organID: UUID
    let cellID: UUID

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var isCritical: Bool = false
    @State private var note: String = ""
    @State private var selectedOrganID: UUID?

    private var organs: [PackingOrgan] {
        vault.heartbeat(byID: sessionID)?.organs ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Item name")
                                .font(VitalTypography.microSignal())
                                .foregroundColor(VitalPalette.ashVeil)
                            TextField("Name", text: $name)
                                .font(VitalTypography.bodyRhythm())
                                .foregroundColor(VitalPalette.ivoryBreath)
                                .padding(14)
                                .background(VitalPalette.charcoalBreath)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Quantity")
                                .font(VitalTypography.microSignal())
                                .foregroundColor(VitalPalette.ashVeil)
                            Stepper(value: $quantity, in: 1...99) {
                                Text("\(quantity)")
                                    .font(VitalTypography.sectionPulse())
                                    .foregroundColor(VitalPalette.ivoryBreath)
                            }
                            .padding(12)
                            .vitalCardStyle(cornerRadius: 10)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Section")
                                .font(VitalTypography.microSignal())
                                .foregroundColor(VitalPalette.ashVeil)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(organs) { organ in
                                        organChip(organ)
                                    }
                                }
                            }
                        }

                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(VitalPalette.emberCore)
                            Text("Mark as Critical")
                                .font(VitalTypography.captionMurmur())
                                .foregroundColor(VitalPalette.ivoryBreath)
                            Spacer()
                            Toggle("", isOn: $isCritical)
                                .tint(VitalPalette.emberCore)
                                .labelsHidden()
                        }
                        .padding(12)
                        .vitalCardStyle(cornerRadius: 10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note (optional)")
                                .font(VitalTypography.microSignal())
                                .foregroundColor(VitalPalette.ashVeil)
                            TextField("Any details…", text: $note, axis: .vertical)
                                .font(VitalTypography.captionMurmur())
                                .foregroundColor(VitalPalette.ivoryBreath)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(VitalPalette.charcoalBreath)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { router.dismissSheet() }
                        .foregroundColor(VitalPalette.ashVeil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveItem() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VitalPalette.aureliaGlow)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedOrganID == nil)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
            .onAppear { loadState() }
        }
    }

    private func organChip(_ organ: PackingOrgan) -> some View {
        let selected = selectedOrganID == organ.id
        return HStack(spacing: 5) {
            Image(systemName: organ.designation.icon)
                .font(.system(size: 11))
            Text(organ.displayName)
                .font(VitalTypography.microSignal())
        }
        .foregroundColor(selected ? VitalPalette.obsidianPulse : VitalPalette.boneMarrow)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selected ? VitalPalette.aureliaGlow : VitalPalette.midnightVein)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(selected ? Color.clear : VitalPalette.charcoalBreath, lineWidth: 0.5))
        .onTapGesture {
            withAnimation(.spring(response: 0.25)) { selectedOrganID = organ.id }
        }
    }

    private func loadState() {
        guard let session = vault.heartbeat(byID: sessionID) else { return }
        for organ in session.organs {
            if let cell = organ.cells.first(where: { $0.id == cellID }) {
                name = cell.name
                quantity = cell.quantity
                isCritical = cell.isCritical
                note = cell.note ?? ""
                selectedOrganID = organ.id
                return
            }
        }
    }

    private func saveItem() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let targetOrganID = selectedOrganID else { return }

        vault.updateCell(
            sessionID: sessionID,
            organID: organID,
            cellID: cellID,
            name: trimmed,
            quantity: quantity,
            note: note.isEmpty ? nil : note,
            targetOrganID: targetOrganID
        )
        router.dismissSheet()
        router.showToast("Item updated", style: .success)
    }
}

// ============================================================================
// MARK: - 3. Edit Organ Sheet
// ============================================================================

struct VitalEditOrganSheet: View {

    let sessionID: UUID
    let organID: UUID

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    private var organ: PackingOrgan? {
        vault.heartbeat(byID: sessionID)?.organs.first { $0.id == organID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                VStack(spacing: 16) {
                    if let organ = organ {
                        // Section info
                        HStack(spacing: 12) {
                            Image(systemName: organ.designation.icon)
                                .font(.system(size: 22))
                                .foregroundColor(VitalPalette.aureliaGlow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(organ.displayName)
                                    .font(VitalTypography.sectionPulse())
                                    .foregroundColor(VitalPalette.ivoryBreath)
                                Text("\(organ.organVitals.packedCells)/\(organ.organVitals.totalCells) packed")
                                    .font(VitalTypography.microSignal())
                                    .foregroundColor(VitalPalette.ashVeil)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .vitalCardStyle(cornerRadius: 14)

                        // Actions
                        VStack(spacing: 1) {
                            sheetActionRow(
                                icon: "checkmark.circle.fill",
                                iconColor: VitalPalette.verdantPulse,
                                label: "Mark All Packed",
                                subtitle: "Pack every item in this section"
                            ) {
                                vault.markOrganComplete(sessionID: sessionID, organID: organID)
                                router.dismissSheet()
                                router.showToast("Section complete!", style: .success)
                            }

                            Divider().background(VitalPalette.charcoalBreath)

                            sheetActionRow(
                                icon: "arrow.counterclockwise",
                                iconColor: VitalPalette.feverSignal,
                                label: "Reset All",
                                subtitle: "Set every item back to unpacked"
                            ) {
                                vault.resetOrgan(sessionID: sessionID, organID: organID)
                                router.dismissSheet()
                                router.showToast("Section reset", style: .info)
                            }

                            Divider().background(VitalPalette.charcoalBreath)

                            sheetActionRow(
                                icon: "trash",
                                iconColor: VitalPalette.emberCore,
                                label: "Delete Unpacked Items",
                                subtitle: "Remove items that aren't packed yet"
                            ) {
                                deleteUnpackedItems()
                            }
                        }
                        .vitalCardStyle(cornerRadius: 14)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { router.dismissSheet() }
                        .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
        }
    }

    private func deleteUnpackedItems() {
        guard let sIdx = vault.heartbeats.firstIndex(where: { $0.id == sessionID }),
              let oIdx = vault.heartbeats[sIdx].organs.firstIndex(where: { $0.id == organID })
        else { return }

        vault.heartbeats[sIdx].organs[oIdx].cells.removeAll { !$0.isPacked }
        vault.recalculateVitalSigns(for: &vault.heartbeats[sIdx])
        vault.updateHeartbeat(vault.heartbeats[sIdx])
        router.dismissSheet()
        router.showToast("Unpacked items removed", style: .info)
    }
}

// ============================================================================
// MARK: - 4. Session Conditions Sheet
// ============================================================================

struct VitalSessionConditionsSheet: View {

    let sessionID: UUID
    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    private var session: PackingHeartbeat? {
        vault.heartbeat(byID: sessionID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        Text("Toggle conditions to add or remove smart items from your list")
                            .font(VitalTypography.captionMurmur())
                            .foregroundColor(VitalPalette.boneMarrow)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .padding(.horizontal, 8)

                        ForEach(vault.conditionBank) { condition in
                            conditionRow(condition)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { router.dismissSheet() }
                        .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
        }
    }

    private func conditionRow(_ condition: ConditionTrigger) -> some View {
        let isActive = session?.activeConditionIDs.contains(condition.id) ?? false
        let preview = vault.previewConditionDelta(conditionID: condition.id, sessionID: sessionID)
        let nervesCount = vault.nervesForCondition(condition.id).filter { $0.action == .addItem }.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: condition.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isActive ? VitalPalette.aureliaGlow : VitalPalette.ashVeil)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(condition.name)
                        .font(VitalTypography.captionMurmur())
                        .foregroundColor(isActive ? VitalPalette.ivoryBreath : VitalPalette.boneMarrow)

                    if isActive {
                        Text("Active · \(nervesCount) items affected")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.verdantPulse)
                    } else {
                        Text("Will add \(nervesCount) items")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.ashVeil)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isActive },
                    set: { _ in
                        vault.toggleCondition(conditionID: condition.id, sessionID: sessionID)
                    }
                ))
                .tint(VitalPalette.aureliaGlow)
                .labelsHidden()
            }

            // Preview delta
            if !isActive && !preview.added.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(VitalPalette.verdantPulse)
                    Text(preview.added.prefix(3).joined(separator: ", "))
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.ashVeil)
                        .lineLimit(1)
                }
                .padding(.leading, 36)
            }

            if isActive && !preview.removed.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(VitalPalette.feverSignal)
                    Text("Would remove: " + preview.removed.prefix(3).joined(separator: ", "))
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.ashVeil)
                        .lineLimit(1)
                }
                .padding(.leading, 36)
            }
        }
        .padding(14)
        .vitalCardStyle(cornerRadius: 12)
    }
}

// ============================================================================
// MARK: - 5. Session Reminders Sheet
// ============================================================================

struct VitalSessionRemindersSheet: View {

    let sessionID: UUID
    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    @State private var is24h: Bool = true
    @State private var is6h: Bool = true
    @State private var is2h: Bool = true
    @State private var permissionState: String = "Checking…"

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Notification status
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 18))
                            .foregroundColor(VitalPalette.aureliaGlow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notification Status")
                                .font(VitalTypography.captionMurmur())
                                .foregroundColor(VitalPalette.ivoryBreath)
                            Text(permissionState)
                                .font(VitalTypography.microSignal())
                                .foregroundColor(VitalPalette.boneMarrow)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .vitalCardStyle(cornerRadius: 12)

                    // Reminder toggles
                    VStack(spacing: 1) {
                        reminderRow(label: "24 hours before", icon: "clock", isOn: $is24h)
                        Divider().background(VitalPalette.charcoalBreath)
                        reminderRow(label: "6 hours before", icon: "clock.badge", isOn: $is6h)
                        Divider().background(VitalPalette.charcoalBreath)
                        reminderRow(label: "2 hours before", icon: "clock.badge.exclamationmark", isOn: $is2h)
                    }
                    .vitalCardStyle(cornerRadius: 14)

                    // Preview text
                    if let session = vault.heartbeat(byID: sessionID) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notification Preview")
                                .font(VitalTypography.microSignal())
                                .foregroundColor(VitalPalette.ashVeil)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("🧳 Packing: \(session.vitalSigns.remainingCells) items left")
                                    .font(VitalTypography.captionMurmur())
                                    .foregroundColor(VitalPalette.ivoryBreath)
                                if session.vitalSigns.criticalRemaining > 0 {
                                    Text("⚠️ Critical: \(session.vitalSigns.criticalRemaining) items")
                                        .font(VitalTypography.captionMurmur())
                                        .foregroundColor(VitalPalette.emberCore)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(VitalPalette.charcoalBreath)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveReminders() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
            .onAppear { loadState() }
        }
    }

    private func reminderRow(label: String, icon: String, isOn: Binding<Bool>) -> some View {
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

    private func loadState() {
        if let session = vault.heartbeat(byID: sessionID) {
            is24h = session.reminderPlan.is24HoursEnabled
            is6h = session.reminderPlan.is6HoursEnabled
            is2h = session.reminderPlan.is2HoursEnabled
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized: permissionState = "Enabled"
                case .denied: permissionState = "Denied — enable in Settings"
                default: permissionState = "Not yet requested"
                }
            }
        }
    }

    private func saveReminders() {
        guard var session = vault.heartbeat(byID: sessionID) else { return }
        session.reminderPlan.is24HoursEnabled = is24h
        session.reminderPlan.is6HoursEnabled = is6h
        session.reminderPlan.is2HoursEnabled = is2h
        vault.updateHeartbeat(session)
        scheduleReminderNotifications(sessionID: sessionID, departure: session.departureEpoch)
        router.dismissSheet()
        router.showToast("Reminders updated", style: .info)
    }

    private func scheduleReminderNotifications(sessionID: UUID, departure: Date) {
        scheduleRemindersForSession(sessionID: sessionID, vault: vault, is24h: is24h, is6h: is6h, is2h: is2h)
    }
}

private func scheduleRemindersForSession(sessionID: UUID, vault: VitalDataVault, is24h: Bool? = nil, is6h: Bool? = nil, is2h: Bool? = nil) {
    guard let session = vault.heartbeat(byID: sessionID) else { return }
    let plan = session.reminderPlan
    let use24h = is24h ?? plan.is24HoursEnabled
    let use6h = is6h ?? plan.is6HoursEnabled
    let use2h = is2h ?? plan.is2HoursEnabled
    let departure = session.departureEpoch

    let center = UNUserNotificationCenter.current()
    let sessionPrefix = "c13_reminder_\(sessionID.uuidString)_"

    center.getNotificationSettings { settings in
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        center.getPendingNotificationRequests { requests in
            let toRemove = requests.filter { $0.identifier.hasPrefix(sessionPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: toRemove.map(\.identifier))
        }

        let title = "Packing Reminder"
        let body = "Time to pack! Check your list before departure."

        if use24h {
                let triggerDate = Calendar.current.date(byAdding: .hour, value: -24, to: departure) ?? departure
                if triggerDate > Date() {
                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = body
                    content.userInfo = ["sessionID": sessionID.uuidString]
                    let request = UNNotificationRequest(identifier: "\(sessionPrefix)24h", content: content, trigger: trigger)
                    center.add(request)
                }
            }
        if use6h {
                let triggerDate = Calendar.current.date(byAdding: .hour, value: -6, to: departure) ?? departure
                if triggerDate > Date() {
                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = body
                    content.userInfo = ["sessionID": sessionID.uuidString]
                    let request = UNNotificationRequest(identifier: "\(sessionPrefix)6h", content: content, trigger: trigger)
                    center.add(request)
                }
            }
        if use2h {
                let triggerDate = Calendar.current.date(byAdding: .hour, value: -2, to: departure) ?? departure
                if triggerDate > Date() {
                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = body
                    content.userInfo = ["sessionID": sessionID.uuidString]
                    let request = UNNotificationRequest(identifier: "\(sessionPrefix)2h", content: content, trigger: trigger)
                    center.add(request)
                }
            }
    }
}

// ============================================================================
// MARK: - 5b. Edit Session Sheet
// ============================================================================

struct VitalEditSessionSheet: View {

    let sessionID: UUID

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    @State private var title: String = ""
    @State private var departure: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Session name")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.ashVeil)
                        TextField("Trip name", text: $title)
                            .font(VitalTypography.bodyRhythm())
                            .foregroundColor(VitalPalette.ivoryBreath)
                            .padding(14)
                            .background(VitalPalette.charcoalBreath)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Departure date & time")
                            .font(VitalTypography.microSignal())
                            .foregroundColor(VitalPalette.ashVeil)
                        DatePicker("", selection: $departure, in: Date()...)
                            .datePickerStyle(.graphical)
                            .tint(VitalPalette.aureliaGlow)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { router.dismissSheet() }
                        .foregroundColor(VitalPalette.ashVeil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveSession() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VitalPalette.aureliaGlow)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadState() }
        }
    }

    private func loadState() {
        if let session = vault.heartbeat(byID: sessionID) {
            title = session.title
            departure = session.departureEpoch
        }
    }

    private func saveSession() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, var session = vault.heartbeat(byID: sessionID) else { return }

        session.title = trimmed
        session.departureEpoch = departure
        vault.updateHeartbeat(session)
        scheduleRemindersForSession(sessionID: sessionID, vault: vault)
        router.dismissSheet()
        router.showToast("Session updated", style: .success)
    }
}

import UserNotifications

// ============================================================================
// MARK: - 6. Item Reason Sheet
// ============================================================================

struct VitalItemReasonSheet: View {

    let sessionID: UUID
    let organID: UUID
    let cellID: UUID

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    private var cell: PackingCell? {
        vault.heartbeat(byID: sessionID)?
            .organs.first { $0.id == organID }?
            .cells.first { $0.id == cellID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                VStack(spacing: 20) {
                    if let cell = cell {
                        // Item name
                        Text(cell.name)
                            .font(VitalTypography.vitalTitle())
                            .foregroundColor(VitalPalette.ivoryBreath)

                        // Origin badge
                        HStack(spacing: 6) {
                            Image(systemName: originIcon(cell.origin))
                                .font(.system(size: 13))
                            Text(originLabel(cell.origin))
                                .font(VitalTypography.captionMurmur())
                        }
                        .foregroundColor(VitalPalette.aureliaGlow)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VitalPalette.aureliaGlow.opacity(0.10)))

                        // Reason
                        if let reason = cell.reasonPulse, !reason.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Reason")
                                    .font(VitalTypography.microSignal())
                                    .foregroundColor(VitalPalette.ashVeil)

                                Text(reason)
                                    .font(VitalTypography.bodyRhythm())
                                    .foregroundColor(VitalPalette.ivoryBreath)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .vitalCardStyle(cornerRadius: 10)
                            }
                        }

                        // Rule lineage
                        if !cell.ruleLineage.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Applied Rules")
                                    .font(VitalTypography.microSignal())
                                    .foregroundColor(VitalPalette.ashVeil)

                                ForEach(cell.ruleLineage, id: \.self) { nerveID in
                                    if let nerve = vault.nerveLibrary.first(where: { $0.id == nerveID }),
                                       let cond = vault.conditionBank.first(where: { $0.id == nerve.conditionID }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: cond.icon)
                                                .font(.system(size: 12))
                                                .foregroundColor(VitalPalette.cyanVital)
                                            Text("\(cond.name) → \(nerve.action.displayName)")
                                                .font(VitalTypography.captionMurmur())
                                                .foregroundColor(VitalPalette.boneMarrow)
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .vitalCardStyle(cornerRadius: 8)
                                    }
                                }
                            }
                        }

                        // Note
                        if let note = cell.note, !note.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Note")
                                    .font(VitalTypography.microSignal())
                                    .foregroundColor(VitalPalette.ashVeil)
                                Text(note)
                                    .font(VitalTypography.captionMurmur())
                                    .foregroundColor(VitalPalette.boneMarrow)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { router.dismissSheet() }
                        .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
        }
    }

    private func originIcon(_ origin: CellOrigin) -> String {
        switch origin {
        case .templateSeeded: return "doc.text.fill"
        case .ruleInjected:   return "bolt.circle.fill"
        case .userAdded:      return "person.fill"
        }
    }

    private func originLabel(_ origin: CellOrigin) -> String {
        switch origin {
        case .templateSeeded: return "From Template"
        case .ruleInjected:   return "Added by Rule"
        case .userAdded:      return "Manually Added"
        }
    }
}

// ============================================================================
// MARK: - 7. Share Session Sheet
// ============================================================================

struct VitalShareSessionSheet: View {

    let sessionID: UUID
    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    @State private var shareText: String = ""
    @State private var showShareSheet: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 28))
                        .foregroundColor(VitalPalette.aureliaGlow)
                        .padding(.top, 12)

                    Text("Share your packing list as text")
                        .font(VitalTypography.captionMurmur())
                        .foregroundColor(VitalPalette.boneMarrow)

                    // Preview
                    ScrollView {
                        Text(shareText)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(VitalPalette.boneMarrow)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .vitalCardStyle(cornerRadius: 12)
                    .frame(maxHeight: .infinity)

                    // Share button
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                            Text("Share")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(VitalPalette.obsidianPulse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(VitalPalette.aureliaGlow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Share List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { router.dismissSheet() }
                        .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
            .onAppear {
                if let payload = vault.buildSharePayload(sessionID: sessionID) {
                    shareText = payload.asPlainText()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheetView(text: shareText)
            }
        }
    }
}

// ============================================================================
// MARK: - 8. Rule Editor Sheet
// ============================================================================

struct VitalRuleEditorSheet: View {

    let conditionID: UUID?
    let existingNerveID: UUID?

    @EnvironmentObject var vault: VitalDataVault
    @EnvironmentObject var router: VitalRouter

    @State private var selectedCondID: UUID?
    @State private var action: NerveAction = .addItem
    @State private var targetName: String = ""
    @State private var targetOrgan: OrganDesignation = .provisions
    @State private var removalPolicy: NerveRemovalPolicy = .removeIfNotPacked
    @State private var priority: Int = 3
    @State private var reasonText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VitalPalette.obsidianPulse.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Condition picker
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("IF condition is active")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(vault.conditionBank) { cond in
                                        condChip(cond)
                                    }
                                }
                            }
                        }

                        // Action
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("THEN do")
                            Picker("Action", selection: $action) {
                                ForEach([NerveAction.addItem, .makeCritical, .appendNote], id: \.self) { act in
                                    Text(act.displayName).tag(act)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(VitalPalette.aureliaGlow)
                        }

                        // Target item
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("Target Item")
                            TextField("e.g. Umbrella", text: $targetName)
                                .font(VitalTypography.bodyRhythm())
                                .foregroundColor(VitalPalette.ivoryBreath)
                                .padding(12)
                                .background(VitalPalette.charcoalBreath)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Target section
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("In Section")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(OrganDesignation.allCases.filter { $0 != .custom }) { des in
                                        organDesChip(des)
                                    }
                                }
                            }
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("Priority (\(priority))")
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= priority ? "star.fill" : "star")
                                        .font(.system(size: 20))
                                        .foregroundColor(star <= priority ? VitalPalette.aureliaGlow : VitalPalette.ashVeil)
                                        .onTapGesture { priority = star }
                                }
                            }
                        }

                        // Removal policy
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("When condition turns off")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    removalPolicyChip(.removeIfNotPacked, label: "Remove")
                                    removalPolicyChip(.alwaysKeep, label: "Keep")
                                    removalPolicyChip(.archive, label: "Archive")
                                }
                            }
                        }

                        // Reason
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("Reason text (shown to user)")
                            TextField("e.g. Rain expected", text: $reasonText)
                                .font(VitalTypography.captionMurmur())
                                .foregroundColor(VitalPalette.ivoryBreath)
                                .padding(12)
                                .background(VitalPalette.charcoalBreath)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(existingNerveID != nil ? "Edit Rule" : "New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { router.dismissSheet() }
                        .foregroundColor(VitalPalette.ashVeil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveRule() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VitalPalette.aureliaGlow)
                        .disabled(targetName.trimmingCharacters(in: .whitespaces).isEmpty || selectedCondID == nil)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .foregroundColor(VitalPalette.aureliaGlow)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(VitalTypography.microSignal())
            .foregroundColor(VitalPalette.ashVeil)
    }

    private func condChip(_ cond: ConditionTrigger) -> some View {
        let selected = selectedCondID == cond.id
        return HStack(spacing: 5) {
            Image(systemName: cond.icon).font(.system(size: 11))
            Text(cond.name).font(VitalTypography.microSignal())
        }
        .foregroundColor(selected ? VitalPalette.obsidianPulse : VitalPalette.boneMarrow)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selected ? VitalPalette.aureliaGlow : VitalPalette.midnightVein)
        .clipShape(Capsule())
        .onTapGesture { selectedCondID = cond.id }
    }

    private func organDesChip(_ des: OrganDesignation) -> some View {
        let selected = targetOrgan == des
        return HStack(spacing: 4) {
            Image(systemName: des.icon).font(.system(size: 10))
            Text(des.displayName).font(VitalTypography.microSignal())
        }
        .foregroundColor(selected ? VitalPalette.obsidianPulse : VitalPalette.boneMarrow)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(selected ? VitalPalette.aureliaGlow : VitalPalette.midnightVein)
        .clipShape(Capsule())
        .onTapGesture { targetOrgan = des }
    }

    private func removalPolicyChip(_ policy: NerveRemovalPolicy, label: String) -> some View {
        let selected = removalPolicy == policy
        return Text(label)
            .font(VitalTypography.microSignal())
            .foregroundColor(selected ? VitalPalette.obsidianPulse : VitalPalette.boneMarrow)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selected ? VitalPalette.aureliaGlow : VitalPalette.midnightVein)
            .clipShape(Capsule())
            .onTapGesture { removalPolicy = policy }
    }

    private func loadExisting() {
        selectedCondID = conditionID
        if let nid = existingNerveID, let nerve = vault.nerveLibrary.first(where: { $0.id == nid }) {
            selectedCondID = nerve.conditionID
            action = nerve.action
            targetName = nerve.targetItemName
            targetOrgan = nerve.targetOrgan
            removalPolicy = nerve.removalPolicy
            priority = nerve.priority
            reasonText = nerve.reasonText
        }
    }

    private func saveRule() {
        let name = targetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let condID = selectedCondID else { return }

        let nerve = DependencyNerve(
            conditionID: condID,
            action: action,
            targetItemName: name,
            targetOrgan: targetOrgan,
            removalPolicy: removalPolicy,
            priority: priority,
            reasonText: reasonText.isEmpty ? "\(action.displayName): \(name)" : reasonText
        )
        vault.addNerve(nerve)
        router.dismissSheet()
        router.showToast("Rule saved", style: .success)
    }
}

// ============================================================================
// MARK: - Shared Action Row Component
// ============================================================================

private func sheetActionRow(
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
                    .font(.system(size: 14, weight: .semibold))
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
