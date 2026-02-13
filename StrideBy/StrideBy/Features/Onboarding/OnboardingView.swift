//
//  OnboardingView.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            // Pages
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)
                ConceptPage()
                    .tag(1)
                SharePage()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom controls
            VStack(spacing: 28) {
                // Page indicator
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage
                                  ? StrideByTheme.accent
                                  : Color.gray.opacity(0.25))
                            .frame(
                                width: index == currentPage ? 24 : 6,
                                height: 6
                            )
                    }
                }
                .animation(StrideByTheme.defaultSpring, value: currentPage)

                // Action button
                Button {
                    if currentPage < pageCount - 1 {
                        withAnimation(StrideByTheme.defaultSpring) {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage < pageCount - 1 ? "Continue" : "Get Started")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(StrideByTheme.accent)
                .padding(.horizontal, 24)
                .animation(.none, value: currentPage)
            }
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    @State private var lineDrawn = false
    @State private var pinVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated route illustration
            ZStack {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    // Route line
                    routePath(in: geo.size)
                        .trim(from: 0, to: lineDrawn ? 1 : 0)
                        .stroke(
                            StrideByTheme.accent,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )

                    // Start dot
                    Circle()
                        .fill(.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .position(x: w * 0.12, y: h * 0.65)

                    // End pin — pops in after line finishes
                    ZStack {
                        Circle()
                            .fill(StrideByTheme.accent)
                            .frame(width: 14, height: 14)
                        Circle()
                            .fill(.white)
                            .frame(width: 5, height: 5)
                    }
                    .shadow(color: StrideByTheme.accent.opacity(0.4), radius: 6, y: 2)
                    .position(x: w * 0.88, y: h * 0.3)
                    .opacity(pinVisible ? 1 : 0)
                    .scaleEffect(pinVisible ? 1 : 0.2)
                }
            }
            .frame(height: 200)
            .padding(.horizontal, 40)

            Spacer().frame(height: 48)

            // Text
            VStack(spacing: 10) {
                Text("StrideBy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Every mile takes you\nsomewhere new.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).delay(0.4)) {
                lineDrawn = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(2.1)) {
                pinVisible = true
            }
        }
    }

    private func routePath(in size: CGSize) -> Path {
        let w = size.width
        let h = size.height
        return Path { path in
            path.move(to: CGPoint(x: w * 0.12, y: h * 0.65))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.42),
                control1: CGPoint(x: w * 0.25, y: h * 0.25),
                control2: CGPoint(x: w * 0.38, y: h * 0.62)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.3),
                control1: CGPoint(x: w * 0.62, y: h * 0.22),
                control2: CGPoint(x: w * 0.78, y: h * 0.52)
            )
        }
    }
}

// MARK: - Page 2: Concept

private struct ConceptPage: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Visual: run here → travel there
            HStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 44))
                        .foregroundStyle(StrideByTheme.accent)

                    Text("Run here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.quaternary)

                VStack(spacing: 12) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(StrideByTheme.accent)

                    Text("Travel there")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer().frame(height: 48)

            // Text
            VStack(spacing: 10) {
                Text("Run your neighborhood.\nTravel the world.")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Your daily miles move your pin along\nfamous routes across the globe.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 3: Discover & Share

private struct SharePage: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Mock postcard
            VStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 36))
                    .foregroundStyle(StrideByTheme.accent)

                Text("St. Louis, MO")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("847 miles in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 200, height: 150)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 20, y: 8)

            Spacer().frame(height: 48)

            // Text
            VStack(spacing: 10) {
                Text("Discover real places.")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Hit landmarks, earn passport stamps,\nand share postcards from your journey.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
