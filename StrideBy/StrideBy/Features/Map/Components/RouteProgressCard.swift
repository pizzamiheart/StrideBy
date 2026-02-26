//
//  RouteProgressCard.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct RouteProgressCard: View {
    @AppStorage("strideby_distance_unit") private var distanceUnitRawValue = DistanceUnit.miles.rawValue

    let route: RunRoute
    let progress: UserProgress
    var isSyncing: Bool = false
    var isComplete: Bool = false
    var onLookAroundHere: (() -> Void)?

    private var percentComplete: Double {
        guard route.totalDistanceMiles > 0 else { return 0 }
        return min(progress.completedMiles / route.totalDistanceMiles, 1.0)
    }

    private var upcomingLandmarks: [Landmark] {
        route.landmarks
            .filter { $0.distanceFromStartMiles > progress.completedMiles }
            .prefix(3)
            .map { $0 }
    }

    private var locationText: String {
        if isComplete {
            return "Route Complete"
        } else if progress.completedMiles > 0 {
            return progress.nearestLocationName
        } else {
            return route.origin
        }
    }

    private var distanceUnit: DistanceUnit {
        DistanceUnit(rawValue: distanceUnitRawValue) ?? .miles
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Route context + percentage
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("\(route.origin) → \(route.destination)")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .tracking(0.3)

                        if isSyncing {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }

                    // Hero location
                    Text(locationText)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(isComplete ? StrideByTheme.accent : .primary)
                }

                Spacer()

                if isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(StrideByTheme.accent)
                        .symbolEffect(.bounce, value: isComplete)
                } else {
                    Text("\(Int(percentComplete * 100))%")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.heavy)
                        .foregroundStyle(StrideByTheme.accent)
                        .contentTransition(.numericText())
                        .animation(StrideByTheme.defaultSpring, value: percentComplete)
                }
            }

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(StrideByTheme.accent)
                            .frame(width: geo.size.width * percentComplete, height: 8)
                            .animation(StrideByTheme.defaultSpring, value: percentComplete)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(distanceText(progress.completedMiles))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(StrideByTheme.accent)
                        .contentTransition(.numericText())
                        .animation(StrideByTheme.defaultSpring, value: progress.completedMiles)

                    Spacer()

                    Text(distanceText(route.totalDistanceMiles))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Look Around CTA — full-width prominent button
            if progress.completedMiles > 0 && !isComplete {
                if let onLookAroundHere {
                    Button {
                        onLookAroundHere()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "binoculars.fill")
                            Text("Look Around")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StrideByTheme.accent)
                }
            }

            // Completion or upcoming landmarks
            if isComplete {
                Text("You ran \(route.origin) to \(route.destination)!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else if !upcomingLandmarks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AHEAD")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.tertiary)
                        .tracking(0.8)

                    ForEach(upcomingLandmarks) { landmark in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(StrideByTheme.accent.opacity(0.12))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "mappin")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(StrideByTheme.accent)
                                )

                            Text(landmark.name)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            let milesAway = max(0, landmark.distanceFromStartMiles - progress.completedMiles)
                            Text(distanceText(milesAway))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius))
        .shadow(color: .black.opacity(0.1), radius: 24, y: 10)
    }

    private func distanceText(_ miles: Double) -> String {
        let converted = distanceUnit.convert(miles: miles)
        return "\(Int(converted.rounded())) \(distanceUnit.abbreviation)"
    }
}

#Preview("In Progress") {
    RouteProgressCard(
        route: .parisCityLoop,
        progress: UserProgress(completedMiles: 12, nearestLocationName: "Louvre, Paris"),
        onLookAroundHere: {}
    )
    .padding()
}

#Preview("Complete") {
    RouteProgressCard(
        route: .parisCityLoop,
        progress: UserProgress(completedMiles: 28, nearestLocationName: "Bastille, Paris"),
        isComplete: true
    )
    .padding()
}
