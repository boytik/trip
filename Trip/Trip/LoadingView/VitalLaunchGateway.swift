

import SwiftUI

// MARK: - Launch Gateway View

struct VitalLaunchGateway: View {

    @State private var phaseIndex: Int = 0
    @State private var logoScale: CGFloat = 0.4
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var phraseOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var particlesVisible: Bool = false
    @State private var progressValue: CGFloat = 0
    @State private var currentPhraseIndex: Int = 0
    @State private var dismissGateway: Bool = false

    /// Abstract, aspirational loading phrases.
    private let vitalPhrases: [String] = [
        "Preparing your journey…",
        "Aligning essentials…",
        "Calibrating readiness…",
        "Syncing your compass…",
        "Almost there…"
    ]

    /// Minimum time the launch screen is shown (seconds).
    private let minimumDisplayTime: TimeInterval = 3.2

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            // Animated UIKit backdrop (enhanced intensity for launch)
            LaunchPulseBackdropView()
                .ignoresSafeArea()

            // Radial glow behind logo
            radialGlowLayer

            // Floating gold particles
            if particlesVisible {
                LaunchParticleField()
                    .transition(.opacity)
            }

            // Main content stack
            VStack(spacing: 0) {
                Spacer()

                // Spinning orbit ring
                orbitRing
                    .padding(.bottom, 24)

                // Logo / Icon
                logoElement
                    .padding(.bottom, 16)

                // App title
                Text("Ready Set: Easy Now")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(VitalPalette.aureliaGlow)
                    .opacity(titleOpacity)
                    .padding(.bottom, 6)

                // Tagline
                Text("Pack with confidence")
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.boneMarrow)
                    .opacity(subtitleOpacity)
                    .padding(.bottom, 48)

                // Progress bar
                progressBar
                    .padding(.horizontal, 80)
                    .padding(.bottom, 16)

                // Rotating phrases
                Text(vitalPhrases[currentPhraseIndex])
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.ashVeil)
                    .opacity(phraseOpacity)
                    .animation(.easeInOut(duration: 0.5), value: currentPhraseIndex)
                    .id("phrase_\(currentPhraseIndex)")
                    .transition(.opacity)

                Spacer()
                Spacer()
            }
        }
        .opacity(dismissGateway ? 0 : 1)
        .scaleEffect(dismissGateway ? 1.1 : 1.0)
        .onAppear(perform: beginLaunchSequence)
    }

    // MARK: — Logo Element

    private var logoElement: some View {
        ZStack {
            // Outer glow circle
            Circle()
                .fill(VitalPalette.aureliaGlow.opacity(0.08))
                .frame(width: 110, height: 110)
                .scaleEffect(logoScale * 1.3)

            // Inner circle
            Circle()
                .fill(VitalPalette.midnightVein)
                .frame(width: 88, height: 88)
                .overlay(
                    Circle()
                        .stroke(VitalPalette.aureliaGlow.opacity(0.4), lineWidth: 1.5)
                )
                .scaleEffect(logoScale)

            // Icon
            Image(systemName: "suitcase.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(VitalPalette.aureliaGlow)
                .scaleEffect(logoScale)
        }
        .opacity(logoOpacity)
    }

    // MARK: — Orbit Ring

    private var orbitRing: some View {
        ZStack {
            // Outer dashed ring
            Circle()
                .stroke(
                    VitalPalette.aureliaGlow.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 8])
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(ringRotation))

            // Inner thin ring
            Circle()
                .stroke(VitalPalette.honeyElixir.opacity(0.08), lineWidth: 0.5)
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(-ringRotation * 0.6))

            // Orbiting dot
            Circle()
                .fill(VitalPalette.aureliaGlow)
                .frame(width: 6, height: 6)
                .shadow(color: VitalPalette.aureliaGlow.opacity(0.6), radius: 4)
                .offset(x: 80)
                .rotationEffect(.degrees(ringRotation * 1.5))
        }
        .scaleEffect(ringScale)
        .opacity(logoOpacity * 0.8)
    }

    // MARK: — Radial Glow

    private var radialGlowLayer: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                VitalPalette.aureliaGlow.opacity(0.06),
                Color.clear
            ]),
            center: .center,
            startRadius: 20,
            endRadius: 250
        )
        .scaleEffect(logoScale * 2)
        .opacity(logoOpacity)
        .ignoresSafeArea()
    }

    // MARK: — Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(VitalPalette.charcoalBreath)
                    .frame(height: 3)

                // Fill
                Capsule()
                    .fill(VitalPalette.aureliaShimmer)
                    .frame(width: geo.size.width * progressValue, height: 3)
                    .animation(.easeInOut(duration: 0.4), value: progressValue)

                // Glow dot at progress tip
                Circle()
                    .fill(VitalPalette.aureliaGlow)
                    .frame(width: 7, height: 7)
                    .shadow(color: VitalPalette.aureliaGlow.opacity(0.5), radius: 4)
                    .offset(x: max(0, geo.size.width * progressValue - 3.5))
                    .opacity(progressValue > 0.05 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: progressValue)
            }
        }
        .frame(height: 7)
    }

    // MARK: — Launch Sequence

    private func beginLaunchSequence() {
        // Phase 1: Logo appears (0.0s)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            logoScale = 1.0
            logoOpacity = 1.0
            ringScale = 1.0
        }

        // Start ring rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        // Phase 2: Title + subtitle (0.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.6)) {
                titleOpacity = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.5)) {
                subtitleOpacity = 1.0
                phraseOpacity = 1.0
                particlesVisible = true
            }
        }

        // Phase 3: Progress animation (0.8s → 3.0s)
        startProgressAnimation()

        // Phase 4: Cycle through phrases
        startPhraseCycling()

        // Phase 5: Dismiss and transition (3.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumDisplayTime) {
            withAnimation(.easeInOut(duration: 0.5)) {
                dismissGateway = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onFinished()
            }
        }
    }

    private func startProgressAnimation() {
        let steps: [(TimeInterval, CGFloat)] = [
            (0.8, 0.15),
            (1.2, 0.35),
            (1.6, 0.55),
            (2.0, 0.72),
            (2.4, 0.88),
            (2.8, 1.0)
        ]

        for (delay, value) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                progressValue = value
            }
        }
    }

    private func startPhraseCycling() {
        for i in 1..<vitalPhrases.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.65) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    phraseOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    currentPhraseIndex = i
                    withAnimation(.easeInOut(duration: 0.3)) {
                        phraseOpacity = 1
                    }
                }
            }
        }
    }
}

// MARK: - Launch Particle Field

/// Lightweight SwiftUI particle effect for the launch screen.
/// Gold dots that drift upward and fade — like embers rising.
struct LaunchParticleField: View {

    private let particleCount = 18

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                LaunchParticle(index: index)
            }
        }
        .ignoresSafeArea()
    }
}

struct LaunchParticle: View {

    let index: Int

    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0

    private var initialX: CGFloat {
        CGFloat.random(in: 30...(UIScreen.main.bounds.width - 30))
    }

    private var initialY: CGFloat {
        CGFloat.random(in: UIScreen.main.bounds.height * 0.4...UIScreen.main.bounds.height * 0.9)
    }

    private var particleSize: CGFloat {
        CGFloat.random(in: 2...5)
    }

    private var driftDuration: Double {
        Double.random(in: 3...6)
    }

    var body: some View {
        Circle()
            .fill(VitalPalette.aureliaGlow)
            .frame(width: particleSize, height: particleSize)
            .shadow(color: VitalPalette.aureliaGlow.opacity(0.4), radius: 3)
            .position(x: initialX, y: initialY)
            .offset(y: yOffset)
            .opacity(opacity)
            .onAppear {
                let delay = Double(index) * 0.12

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(
                        .easeOut(duration: driftDuration)
                        .repeatForever(autoreverses: false)
                    ) {
                        yOffset = -UIScreen.main.bounds.height * 0.5
                    }

                    withAnimation(
                        .easeInOut(duration: driftDuration * 0.4)
                        .repeatForever(autoreverses: true)
                    ) {
                        opacity = Double.random(in: 0.15...0.4)
                    }
                }
            }
    }
}

// MARK: - Preview

#if DEBUG
struct VitalLaunchGateway_Previews: PreviewProvider {
    static var previews: some View {
        VitalLaunchGateway(onFinished: {})
            .preferredColorScheme(.dark)
    }
}
#endif
