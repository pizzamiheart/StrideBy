//
//  RouteProgressCard.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct RouteProgressCard: View {
    let route: RunRoute
    let progress: UserProgress
    var isSyncing: Bool = false

    private var percentComplete: Double {
        guard route.totalDistanceMiles > 0 else { return 0 }
        return progress.completedMiles / route.totalDistanceMiles
    }

    private var upcomingLandmarks: [Landmark] {
        route.landmarks
            .filter { $0.distanceFromStartMiles > progress.completedMiles }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Route header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(route.origin) → \(route.destination)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        if progress.completedMiles > 0 {
                            Text("Near \(progress.nearestLocationName)")
                        } else {
                            Text("Starting in \(route.origin)")
                        }

                        if isSyncing {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(percentComplete * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(StrideByTheme.accent)
                    .contentTransition(.numericText())
                    .animation(StrideByTheme.defaultSpring, value: percentComplete)
            }

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)
                            .frame(height: 6)

                        // Fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(StrideByTheme.accent)
                            .frame(width: geo.size.width * percentComplete, height: 6)
                            .animation(StrideByTheme.defaultSpring, value: percentComplete)
                    }
                }
                .frame(height: 6)

                // Mile markers
                HStack {
                    Text("\(Int(progress.completedMiles)) mi")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(StrideByTheme.accent)
                        .contentTransition(.numericText())
                        .animation(StrideByTheme.defaultSpring, value: progress.completedMiles)

                    Spacer()

                    Text("\(Int(route.totalDistanceMiles)) mi")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Upcoming landmarks
            if !upcomingLandmarks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AHEAD")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                        .tracking(0.5)

                    ForEach(upcomingLandmarks) { landmark in
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundStyle(StrideByTheme.accent.opacity(0.6))

                            Text(landmark.name)
                                .font(.caption)
                                .foregroundStyle(.primary)

                            Spacer()

                            let milesAway = Int(landmark.distanceFromStartMiles - progress.completedMiles)
                            Text("\(milesAway) mi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
    }
}

#Preview {
    RouteProgressCard(
        route: .nycToLA,
        progress: UserProgress(completedMiles: 847, nearestLocationName: "Terre Haute, IN")
    )
    .padding()
}
