//
//  DocumentSplashScreenView.swift
//  Trip
//
//  Loading screen shown during document flow initialization.
//

import SwiftUI

struct DocumentSplashScreenView: View {
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var phraseOpacity: Double = 0
    @State private var progressValue: CGFloat = 0

    var body: some View {
        ZStack {
            LaunchPulseBackdropView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 64))
                    .foregroundColor(VitalPalette.aureliaGlow)
                    .opacity(logoOpacity)
                    .padding(.bottom, 24)

                Text("Ready Set: Easy Now")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(VitalPalette.aureliaGlow)
                    .opacity(titleOpacity)
                    .padding(.bottom, 8)

                Text("Preparing…")
                    .font(VitalTypography.captionMurmur())
                    .foregroundColor(VitalPalette.boneMarrow)
                    .opacity(phraseOpacity)
                    .padding(.bottom, 32)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VitalPalette.charcoalBreath)
                            .frame(height: 3)
                        Capsule()
                            .fill(VitalPalette.aureliaShimmer)
                            .frame(width: geo.size.width * progressValue, height: 3)
                            .animation(.easeInOut(duration: 0.4), value: progressValue)
                    }
                }
                .frame(height: 7)
                .padding(.horizontal, 60)

                Spacer()
                Spacer()
            }
        }
        .onAppear(perform: beginAnimation)
    }

    private func beginAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            logoOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                titleOpacity = 1.0
                phraseOpacity = 1.0
            }
        }
        for (delay, value) in [(0.5, 0.3), (1.0, 0.6), (1.5, 1.0)] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    progressValue = value
                }
            }
        }
    }
}

#if DEBUG
struct DocumentSplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentSplashScreenView()
            .preferredColorScheme(.dark)
    }
}
#endif
