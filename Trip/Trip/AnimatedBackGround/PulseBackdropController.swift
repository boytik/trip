// PulseBackdropController.swift
// c13 — Smart Packing Companion
//
// UIKit-based animated background with subtle gold particles and
// breathing pulse effects. Designed to feel alive without distracting
// from the main content layer. Wrapped as SwiftUI View for easy use.

import UIKit
import SwiftUI

// MARK: - UIKit Backdrop Controller

/// A full-screen UIKit view controller that renders animated particles
/// and a soft radial pulse on a deep obsidian canvas.
final class PulseBackdropController: UIViewController {

    // MARK: — Configuration

    /// How many floating orbs drift across the canvas.
    private let orbCount: Int = 12

    /// How many micro-particles shimmer in the background.
    private let dustCount: Int = 30

    /// Whether the radial pulse ring is active.
    private let showPulseRing: Bool

    /// Intensity multiplier (0.0…1.0) for all animations.
    private let vitalIntensity: CGFloat

    // MARK: — Layers

    private var orbLayers: [CAShapeLayer] = []
    private var dustLayers: [CAShapeLayer] = []
    private var pulseRingLayer: CAShapeLayer?
    private var gradientLayer: CAGradientLayer?
    private var displayLink: CADisplayLink?
    private var phaseAccumulator: CGFloat = 0

    // MARK: — Palette (UIColor mirrors of VitalPalette)

    private let obsidianUIColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
    private let midnightUIColor = UIColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 1.0)
    private let goldUIColor     = UIColor(red: 0.89, green: 0.75, blue: 0.30, alpha: 1.0)
    private let honeyUIColor    = UIColor(red: 0.80, green: 0.68, blue: 0.35, alpha: 1.0)

    // MARK: — Init

    init(showPulseRing: Bool = true, vitalIntensity: CGFloat = 0.6) {
        self.showPulseRing = showPulseRing
        self.vitalIntensity = min(max(vitalIntensity, 0), 1)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.showPulseRing = true
        self.vitalIntensity = 0.6
        super.init(coder: coder)
    }

    // MARK: — Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = obsidianUIColor
        view.isUserInteractionEnabled = false

        setupGradientLayer()
        setupDustParticles()
        setupOrbParticles()

        if showPulseRing {
            setupPulseRing()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimations()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopAnimations()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = view.bounds
        repositionPulseRing()
    }

    // MARK: — Background Gradient

    private func setupGradientLayer() {
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [
            obsidianUIColor.cgColor,
            midnightUIColor.withAlphaComponent(0.95).cgColor,
            obsidianUIColor.cgColor
        ]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        view.layer.addSublayer(gradient)
        self.gradientLayer = gradient
    }

    // MARK: — Dust Particles (micro shimmer)

    private func setupDustParticles() {
        for _ in 0..<dustCount {
            let size = CGFloat.random(in: 1.0...2.5)
            let layer = CAShapeLayer()
            layer.path = UIBezierPath(
                ovalIn: CGRect(x: 0, y: 0, width: size, height: size)
            ).cgPath
            layer.fillColor = goldUIColor.withAlphaComponent(
                CGFloat.random(in: 0.03...0.10) * vitalIntensity
            ).cgColor

            let x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
            let y = CGFloat.random(in: 0...UIScreen.main.bounds.height)
            layer.position = CGPoint(x: x, y: y)

            view.layer.addSublayer(layer)
            dustLayers.append(layer)
        }
    }

    // MARK: — Orb Particles (floating gold spheres)

    private func setupOrbParticles() {
        for _ in 0..<orbCount {
            let radius = CGFloat.random(in: 3...8)
            let layer = CAShapeLayer()
            layer.path = UIBezierPath(
                ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
            ).cgPath

            let isGold = Bool.random()
            let baseColor = isGold ? goldUIColor : honeyUIColor
            layer.fillColor = baseColor.withAlphaComponent(
                CGFloat.random(in: 0.04...0.12) * vitalIntensity
            ).cgColor

            // Soft glow via shadow
            layer.shadowColor = goldUIColor.cgColor
            layer.shadowOpacity = Float(0.15 * vitalIntensity)
            layer.shadowRadius = radius * 2
            layer.shadowOffset = .zero

            let x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
            let y = CGFloat.random(in: 0...UIScreen.main.bounds.height)
            layer.position = CGPoint(x: x, y: y)

            view.layer.addSublayer(layer)
            orbLayers.append(layer)

            // Start drift animation
            animateOrbDrift(layer: layer)
        }
    }

    // MARK: — Pulse Ring (radial heartbeat)

    private func setupPulseRing() {
        let layer = CAShapeLayer()
        let ringRadius: CGFloat = 120
        layer.path = UIBezierPath(
            arcCenter: .zero,
            radius: ringRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).cgPath
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = goldUIColor.withAlphaComponent(0.06 * vitalIntensity).cgColor
        layer.lineWidth = 1.5
        layer.opacity = 0

        view.layer.addSublayer(layer)
        self.pulseRingLayer = layer

        repositionPulseRing()
        animatePulseRing()
    }

    private func repositionPulseRing() {
        pulseRingLayer?.position = CGPoint(
            x: view.bounds.width * 0.5,
            y: view.bounds.height * 0.35
        )
    }

    // MARK: — Animations

    private func startAnimations() {
        displayLink = CADisplayLink(target: self, selector: #selector(tickBreathCycle))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 15, maximum: 30, preferred: 20
        )
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopAnimations() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Subtle opacity breathing for dust particles.
    @objc private func tickBreathCycle() {
        phaseAccumulator += 0.008

        for (index, dust) in dustLayers.enumerated() {
            let offset = CGFloat(index) * 0.4
            let breath = (sin(phaseAccumulator + offset) + 1) / 2 // 0…1
            let baseAlpha: CGFloat = CGFloat.random(in: 0.02...0.08) * vitalIntensity
            dust.opacity = Float(baseAlpha + breath * 0.06 * vitalIntensity)
        }
    }

    /// Infinite slow drift for each orb.
    private func animateOrbDrift(layer: CAShapeLayer) {
        let bounds = UIScreen.main.bounds
        let duration = TimeInterval.random(in: 18...35)

        let destX = CGFloat.random(in: 20...(bounds.width - 20))
        let destY = CGFloat.random(in: 20...(bounds.height - 20))

        let anim = CABasicAnimation(keyPath: "position")
        anim.toValue = CGPoint(x: destX, y: destY)
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.isRemovedOnCompletion = false
        anim.fillMode = .forwards

        // Chain: when done, drift again
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            layer.position = CGPoint(x: destX, y: destY)
            layer.removeAllAnimations()
            self?.animateOrbDrift(layer: layer)
        }
        layer.add(anim, forKey: "orbDrift_\(ObjectIdentifier(layer).hashValue)")
        CATransaction.commit()
    }

    /// Repeating scale + fade pulse ring.
    private func animatePulseRing() {
        guard let ring = pulseRingLayer else { return }

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.6
        scaleAnim.toValue = 1.4

        let fadeAnim = CAKeyframeAnimation(keyPath: "opacity")
        fadeAnim.values = [0.0, Float(0.15 * vitalIntensity), 0.0]
        fadeAnim.keyTimes = [0.0, 0.35, 1.0]

        let group = CAAnimationGroup()
        group.animations = [scaleAnim, fadeAnim]
        group.duration = 5.0
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        ring.add(group, forKey: "pulseRing")
    }

    // MARK: — Cleanup

    deinit {
        stopAnimations()
    }
}

// MARK: - SwiftUI Bridge

/// A SwiftUI representable that embeds the animated UIKit backdrop.
/// Place this as a `.background()` or in a `ZStack` behind content.
struct PulseBackdropView: UIViewControllerRepresentable {

    var showPulseRing: Bool = true
    var vitalIntensity: CGFloat = 0.6

    func makeUIViewController(context: Context) -> PulseBackdropController {
        PulseBackdropController(
            showPulseRing: showPulseRing,
            vitalIntensity: vitalIntensity
        )
    }

    func updateUIViewController(_ uiViewController: PulseBackdropController, context: Context) {
        // Static configuration — no live updates needed
    }
}

// MARK: - View Extension for Easy Application

extension View {

    /// Applies the animated vital backdrop behind this view.
    ///
    /// Usage:
    /// ```swift
    /// MyContentView()
    ///     .vitalAnimatedBackground()
    /// ```
    func vitalAnimatedBackground(
        showPulseRing: Bool = true,
        intensity: CGFloat = 0.6
    ) -> some View {
        ZStack {
            PulseBackdropView(
                showPulseRing: showPulseRing,
                vitalIntensity: intensity
            )
            .ignoresSafeArea()

            self
        }
    }
}

// MARK: - Launch Screen Backdrop Variant

/// Enhanced backdrop specifically for the launch/loading screen
/// with a brighter central glow and more visible particles.
struct LaunchPulseBackdropView: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> PulseBackdropController {
        PulseBackdropController(
            showPulseRing: true,
            vitalIntensity: 1.0
        )
    }

    func updateUIViewController(_ uiViewController: PulseBackdropController, context: Context) {}
}
