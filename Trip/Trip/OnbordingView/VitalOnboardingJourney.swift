

import SwiftUI

// MARK: - Onboarding Journey Container

struct VitalOnboardingJourney: View {

    @EnvironmentObject var vault: VitalDataVault
    var onComplete: () -> Void

    @State private var currentStep: Int = 0
    @State private var direction: NavigationDirection = .forward

    private let totalSteps = 5

    enum NavigationDirection {
        case forward, backward
    }

    var body: some View {
        ZStack {
            // Backdrop
            PulseBackdropView(showPulseRing: false, vitalIntensity: 0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top: step indicator
                onboardingStepIndicator
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Content area
                TabView(selection: $currentStep) {
                    OnboardingWelcomeStep()
                        .tag(0)

                    OnboardingTemplateStep()
                        .tag(1)

                    OnboardingConditionsStep()
                        .tag(2)

                    OnboardingSmartRulesStep()
                        .tag(3)

                    OnboardingReadyStep(onStart: finishOnboarding)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.4), value: currentStep)

                // Bottom navigation
                onboardingBottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: — Step Indicator

    private var onboardingStepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep
                          ? VitalPalette.aureliaGlow
                          : VitalPalette.charcoalBreath)
                    .frame(width: index == currentStep ? 28 : 8, height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
    }

    // MARK: — Bottom Bar

    private var onboardingBottomBar: some View {
        HStack {
            // Back / Skip
            if currentStep > 0 {
                Button(action: goBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(VitalTypography.captionMurmur())
                    }
                    .foregroundColor(VitalPalette.boneMarrow)
                }
            } else {
                Button("Skip") {
                    finishOnboarding()
                }
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.ashVeil)
            }

            Spacer()

            // Next / Get Started
            if currentStep < totalSteps - 1 {
                Button(action: goForward) {
                    HStack(spacing: 6) {
                        Text("Next")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(VitalPalette.obsidianPulse)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(VitalPalette.aureliaGlow)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: — Navigation

    private func goForward() {
        direction = .forward
        withAnimation { currentStep = min(currentStep + 1, totalSteps - 1) }
    }

    private func goBack() {
        direction = .backward
        withAnimation { currentStep = max(currentStep - 1, 0) }
    }

    private func finishOnboarding() {
        vault.completeOnboarding()
        onComplete()
    }
}

// MARK: - Step 1: Welcome

struct OnboardingWelcomeStep: View {

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var featureOpacity: Double = 0
    @State private var glowPulse: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated suitcase icon
            ZStack {
                Circle()
                    .fill(VitalPalette.aureliaGlow.opacity(0.06))
                    .frame(width: 160, height: 160)
                    .scaleEffect(glowPulse)

                Circle()
                    .fill(VitalPalette.midnightVein)
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle()
                            .stroke(VitalPalette.aureliaGlow.opacity(0.3), lineWidth: 1.5)
                    )

                Image(systemName: "suitcase.fill")
                    .font(.system(size: 48))
                    .foregroundColor(VitalPalette.aureliaGlow)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .padding(.bottom, 40)

            // Title
            Text("Welcome to Ready Set")
                .font(VitalTypography.vitalTitle())
                .foregroundColor(VitalPalette.ivoryBreath)
                .opacity(textOpacity)
                .padding(.bottom, 12)

            // Subtitle
            Text("The smartest way to pack\nfor any journey")
                .font(VitalTypography.bodyRhythm())
                .foregroundColor(VitalPalette.boneMarrow)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)
                .padding(.bottom, 40)

            // Feature highlights
            VStack(spacing: 16) {
                OnboardingFeatureRow(
                    icon: "sparkles",
                    title: "Smart Templates",
                    subtitle: "Lists tailored to your trip type"
                )
                OnboardingFeatureRow(
                    icon: "bolt.circle.fill",
                    title: "Condition Rules",
                    subtitle: "\"If rain → pack umbrella\" — automatic"
                )
                OnboardingFeatureRow(
                    icon: "chart.bar.fill",
                    title: "Progress Tracking",
                    subtitle: "Know exactly what's left at a glance"
                )
            }
            .opacity(featureOpacity)
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .onAppear { animateWelcome() }
    }

    private func animateWelcome() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            glowPulse = 1.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.6)) { textOpacity = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.6)) { featureOpacity = 1.0 }
        }
    }
}

// MARK: - Step 2: Templates

struct OnboardingTemplateStep: View {

    @State private var cardsAppeared: Bool = false
    @State private var selectedArchetype: JourneyArchetype? = nil
    @State private var headerOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Choose Your Adventure")
                .font(VitalTypography.vitalTitle())
                .foregroundColor(VitalPalette.ivoryBreath)
                .opacity(headerOpacity)
                .padding(.bottom, 8)

            Text("Each trip type generates a tailored\npacking list with smart defaults")
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.boneMarrow)
                .multilineTextAlignment(.center)
                .opacity(headerOpacity)
                .padding(.bottom, 32)

            // Trip type cards
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(Array(JourneyArchetype.allCases.enumerated()), id: \.element.id) { index, archetype in
                    OnboardingArchetypeCard(
                        archetype: archetype,
                        isSelected: selectedArchetype == archetype,
                        delay: Double(index) * 0.12
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedArchetype = archetype
                        }
                    }
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 30)
                }
            }
            .padding(.horizontal, 28)

            if let selected = selectedArchetype {
                Text("Great choice! \(selected.tagline)")
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.aureliaGlow)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { headerOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) { cardsAppeared = true }
        }
    }
}

struct OnboardingArchetypeCard: View {

    let archetype: JourneyArchetype
    let isSelected: Bool
    let delay: Double

    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isSelected
                          ? VitalPalette.aureliaGlow.opacity(0.15)
                          : VitalPalette.charcoalBreath)
                    .frame(width: 52, height: 52)

                Image(systemName: archetype.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected
                                     ? VitalPalette.aureliaGlow
                                     : VitalPalette.boneMarrow)
            }

            Text(archetype.displayName)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(isSelected
                                 ? VitalPalette.ivoryBreath
                                 : VitalPalette.boneMarrow)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VitalPalette.midnightVein)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected
                        ? VitalPalette.aureliaGlow.opacity(0.5)
                        : VitalPalette.charcoalBreath.opacity(0.5),
                        lineWidth: isSelected ? 1.5 : 0.5)
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .shadow(color: isSelected ? VitalPalette.aureliaGlow.opacity(0.15) : .clear,
                radius: 8, y: 4)
    }
}

// MARK: - Step 3: Conditions

struct OnboardingConditionsStep: View {

    @State private var headerOpacity: Double = 0
    @State private var chipsVisible: Bool = false
    @State private var activeConditions: Set<Int> = []
    @State private var hintOpacity: Double = 0

    private let demoConditions: [(String, String)] = [
        ("cloud.rain.fill", "Rain Expected"),
        ("figure.hiking", "Trekking"),
        ("thermometer.snowflake", "Cold Evenings"),
        ("water.waves", "Beach Day"),
        ("airplane", "Long Transit"),
        ("figure.and.child.holdinghands", "With Children")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Set Your Conditions")
                .frame(maxWidth: .infinity)
                .font(VitalTypography.vitalTitle())
                .foregroundColor(VitalPalette.ivoryBreath)
                .opacity(headerOpacity)
                .padding(.bottom, 8)

            Text("Toggle what applies to your trip.\nThe list adapts automatically.")
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.boneMarrow)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .opacity(headerOpacity)
                .padding(.bottom, 32)

            // Condition chips
            FlowLayout(spacing: 10, alignment: .center) {
                ForEach(Array(demoConditions.enumerated()), id: \.offset) { index, condition in
                    OnboardingConditionChip(
                        icon: condition.0,
                        label: condition.1,
                        isActive: activeConditions.contains(index)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if activeConditions.contains(index) {
                                activeConditions.remove(index)
                            } else {
                                activeConditions.insert(index)
                            }
                        }
                    }
                    .opacity(chipsVisible ? 1 : 0)
                    .offset(y: chipsVisible ? 0 : 20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)

            // Dynamic hint
            if !activeConditions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(VitalPalette.aureliaGlow)
                    Text("\(activeConditions.count) condition\(activeConditions.count == 1 ? "" : "s") active — items will be added")
                        .font(VitalTypography.microSignal())
                        .foregroundColor(VitalPalette.honeyElixir)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { headerOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.6).delay(0.25)) { chipsVisible = true }
        }
    }
}

struct OnboardingConditionChip: View {

    let icon: String
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isActive ? VitalPalette.aureliaGlow : VitalPalette.ashVeil)

            Text(label)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(isActive ? VitalPalette.ivoryBreath : VitalPalette.boneMarrow)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isActive
                      ? VitalPalette.aureliaGlow.opacity(0.12)
                      : VitalPalette.charcoalBreath)
        )
        .overlay(
            Capsule()
                .stroke(isActive
                        ? VitalPalette.aureliaGlow.opacity(0.4)
                        : Color.clear,
                        lineWidth: 1)
        )
    }
}

// MARK: - Step 4: Smart Rules Demo

struct OnboardingSmartRulesStep: View {

    @State private var headerOpacity: Double = 0
    @State private var rulesVisible: [Bool] = [false, false, false]
    @State private var connectionLineHeight: CGFloat = 0

    private let demoRules: [(condition: String, arrow: String, result: String, badge: String)] = [
        ("🌧 Rain Expected", "→", "Umbrella added", "Smart Add"),
        ("🥾 Trekking", "→", "Blister Plasters added", "Smart Add"),
        ("🥾 Trekking", "→", "Hiking Boots marked critical", "Priority Up")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Rules Do the Thinking")
                .font(VitalTypography.vitalTitle())
                .foregroundColor(VitalPalette.ivoryBreath)
                .opacity(headerOpacity)
                .padding(.bottom, 8)

            Text("When a condition is on, rules\nautomatically adjust your list")
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.boneMarrow)
                .multilineTextAlignment(.center)
                .opacity(headerOpacity)
                .padding(.bottom, 36)

            // Rule demonstration cards
            VStack(spacing: 14) {
                ForEach(Array(demoRules.enumerated()), id: \.offset) { index, rule in
                    OnboardingRuleCard(
                        condition: rule.condition,
                        result: rule.result,
                        badge: rule.badge,
                        isVisible: rulesVisible[index]
                    )
                }
            }
            .padding(.horizontal, 28)

            // Explanation
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(VitalPalette.cyanVital)
                Text("Every smart addition shows why it's there")
                    .font(VitalTypography.microSignal())
                    .foregroundColor(VitalPalette.boneMarrow)
            }
            .padding(.top, 24)
            .opacity(rulesVisible.last == true ? 1 : 0)

            Spacer()
            Spacer()
        }
        .onAppear { animateRules() }
    }

    private func animateRules() {
        withAnimation(.easeOut(duration: 0.5)) { headerOpacity = 1.0 }

        for i in 0..<rulesVisible.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.35) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    rulesVisible[i] = true
                }
            }
        }
    }
}

struct OnboardingRuleCard: View {

    let condition: String
    let result: String
    let badge: String
    let isVisible: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Left: condition
            Text(condition)
                .font(VitalTypography.captionMurmur())
                .foregroundColor(VitalPalette.ivoryBreath)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(VitalPalette.aureliaGlow)

            // Right: result + badge
            VStack(alignment: .leading, spacing: 4) {
                Text(result)
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.ivoryBreath)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(badge)
                    .font(VitalTypography.microSignal())
                    .foregroundColor(VitalPalette.aureliaGlow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(VitalPalette.aureliaGlow.opacity(0.12))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalCardStyle(cornerRadius: 14)
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -30)
    }
}

// MARK: - Step 5: Ready

struct OnboardingReadyStep: View {

    var onStart: () -> Void

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var celebrationParticles: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Celebratory icon
            ZStack {
                // Rotating ring
                Circle()
                    .stroke(
                        VitalPalette.aureliaGlow.opacity(0.15),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 10])
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(ringRotation))

                Circle()
                    .fill(VitalPalette.midnightVein)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(VitalPalette.verdantPulse.opacity(0.4), lineWidth: 2)
                    )

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundColor(VitalPalette.verdantPulse)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .padding(.bottom, 36)

            Text("You're All Set!")
                .font(VitalTypography.vitalTitle())
                .foregroundColor(VitalPalette.ivoryBreath)
                .opacity(textOpacity)
                .padding(.bottom, 12)

            Text("Create your first packing session\nand experience smart organization")
                .font(VitalTypography.bodyRhythm())
                .foregroundColor(VitalPalette.boneMarrow)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)
                .padding(.bottom, 12)

            // Stats preview
            HStack(spacing: 24) {
                OnboardingStatPill(value: "4", label: "Trip Types")
                OnboardingStatPill(value: "7", label: "Conditions")
                OnboardingStatPill(value: "25+", label: "Smart Rules")
            }
            .opacity(textOpacity)
            .padding(.bottom, 40)

            // CTA Button
            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "suitcase.fill")
                        .font(.system(size: 16))
                    Text("Start Packing")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(VitalPalette.obsidianPulse)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(VitalPalette.aureliaGlow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: VitalPalette.aureliaGlow.opacity(0.3), radius: 12, y: 6)
            }
            .padding(.horizontal, 40)
            .opacity(buttonOpacity)
            .scaleEffect(buttonOpacity > 0 ? 1 : 0.9)

            Spacer()
            Spacer()
        }
        .onAppear { animateReady() }
    }

    private func animateReady() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.5)) { textOpacity = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                buttonOpacity = 1.0
            }
        }
    }
}

struct OnboardingStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(VitalPalette.aureliaGlow)
            Text(label)
                .font(VitalTypography.microSignal())
                .foregroundColor(VitalPalette.ashVeil)
        }
    }
}

// MARK: - Feature Row (used in Welcome step)

struct OnboardingFeatureRow: View {

    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(VitalPalette.aureliaGlow.opacity(0.10))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(VitalPalette.aureliaGlow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.ivoryBreath)

                Text(subtitle)
                    .font(VitalTypography.microSignal())
                    .foregroundColor(VitalPalette.ashVeil)
            }

            Spacer()
        }
    }
}

// MARK: - Flow Layout (for condition chips)

/// Simple flow/wrap layout for horizontally arranged chips.
struct FlowLayout: Layout {

    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var lineStartIndex = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Apply line offset for alignment before starting new line
                let lineWidth = currentX - spacing
                let offset = lineOffset(for: lineWidth, in: maxWidth)
                for i in lineStartIndex..<positions.count {
                    positions[i].x += offset
                }
                lineStartIndex = index
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        // Apply offset for last line
        let lineWidth = currentX - spacing
        let offset = lineOffset(for: lineWidth, in: maxWidth)
        for i in lineStartIndex..<positions.count {
            positions[i].x += offset
        }

        let totalHeight = currentY + lineHeight
        return LayoutResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions
        )
    }

    private func lineOffset(for lineWidth: CGFloat, in maxWidth: CGFloat) -> CGFloat {
        if lineWidth >= maxWidth { return 0 }
        switch alignment {
        case .leading: return 0
        case .trailing: return maxWidth - lineWidth
        case .center: return (maxWidth - lineWidth) / 2
        default: return (maxWidth - lineWidth) / 2
        }
    }

    struct LayoutResult {
        let size: CGSize
        var positions: [CGPoint]
    }
}

// MARK: - Preview

#if DEBUG
struct VitalOnboardingJourney_Previews: PreviewProvider {
    static var previews: some View {
        VitalOnboardingJourney(onComplete: {})
            .environmentObject(VitalDataVault.shared)
            .preferredColorScheme(.dark)
    }
}
#endif
