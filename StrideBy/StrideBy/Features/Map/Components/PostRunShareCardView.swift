//
//  PostRunShareCardView.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/17/26.
//

import SwiftUI
import UIKit

struct PostRunShareCardView: View {
    @AppStorage("strideby_distance_unit") private var distanceUnitRawValue = DistanceUnit.miles.rawValue

    let route: RunRoute
    let locationName: String
    let milesAdvanced: Double
    let totalMilesOnRoute: Double

    private var distanceUnit: DistanceUnit {
        DistanceUnit(rawValue: distanceUnitRawValue) ?? .miles
    }

    private var milesAdvancedText: String {
        distanceUnit.convert(miles: milesAdvanced).formatted(.number.precision(.fractionLength(1)))
    }

    private var totalMilesText: String {
        distanceUnit.convert(miles: totalMilesOnRoute).formatted(.number.precision(.fractionLength(1)))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.12),
                    Color(red: 0.04, green: 0.18, blue: 0.26),
                    Color(red: 0.08, green: 0.42, blue: 0.38),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 26) {
                Text("STRIDEBY")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(1.8)

                VStack(alignment: .leading, spacing: 14) {
                    Text("I advanced \(milesAdvancedText) \(distanceUnit.abbreviation)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(3)

                    Text("and landed in \(locationName).")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineSpacing(2)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(route.name)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(route.origin) -> \(route.destination)")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))

                    Text("Now at \(totalMilesText) \(distanceUnit.abbreviation)")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 28))

                Spacer()

                Text("Run here. Travel there.")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(64)
        }
    }
}

@MainActor
enum PostRunShareCardRenderer {
    static func makeStoryImage(
        route: RunRoute,
        locationName: String,
        milesAdvanced: Double,
        totalMilesOnRoute: Double
    ) -> UIImage? {
        let content = PostRunShareCardView(
            route: route,
            locationName: locationName,
            milesAdvanced: milesAdvanced,
            totalMilesOnRoute: totalMilesOnRoute
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return renderer.uiImage
    }
}

#Preview {
    PostRunShareCardView(
        route: .parisCityLoop,
        locationName: "Louvre",
        milesAdvanced: 4.2,
        totalMilesOnRoute: 11.7
    )
}
