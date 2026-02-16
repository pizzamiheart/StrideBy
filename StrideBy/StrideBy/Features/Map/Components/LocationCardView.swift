//
//  LocationCardView.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/15/26.
//

import MapKit
import SwiftUI

/// A rich fallback view shown when Look Around has no street-level coverage.
///
/// Instead of a sad "no coverage" message, this shows:
/// - A satellite map snapshot as a hero image (uses `MKMapSnapshotter`, free tile rendering)
/// - Location name, mile progress, and next upcoming landmark
/// - "Explore Nearest Town" buttons linking to curated POIs that are more likely to have coverage
@MainActor
struct LocationCardView: View {
    let locationName: String
    let coordinate: CLLocationCoordinate2D
    let completedMiles: Double
    let routeName: String
    let route: RunRoute
    let onExplorePOI: (Landmark) -> Void

    @Environment(\.displayScale) private var displayScale

    @State private var snapshotImage: UIImage?
    @State private var isLoadingSnapshot = true

    private var nearbyPOIs: [Landmark] {
        route.nearestPOIs(atMiles: completedMiles, limit: 3)
    }

    private var nextLandmark: Landmark? {
        route.landmarks.first { $0.distanceFromStartMiles > completedMiles }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    // Hero satellite snapshot
                    satelliteHero
                        .frame(maxWidth: .infinity)
                        .frame(height: geo.size.height * 0.38)
                        .clipped()

                    // Info card
                    infoCard
                        .padding(.top, -32)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color(.systemBackground))
        .task {
            await loadSnapshot()
        }
    }

    // MARK: - Satellite Hero

    private var satelliteHero: some View {
        ZStack(alignment: .bottom) {
            if let snapshotImage {
                Image(uiImage: snapshotImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoadingSnapshot {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                    }
            } else {
                Rectangle()
                    .fill(.quaternary)
            }

            // Gradient fade at bottom for smooth transition to card
            LinearGradient(
                colors: [.clear, Color(.systemBackground).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 20) {
            // Location badge
            VStack(spacing: 8) {
                Text(locationName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Mile \(Int(completedMiles)) of \(Int(route.totalDistanceMiles)) on \(routeName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Next landmark
            if let next = nextLandmark {
                let milesAway = Int(next.distanceFromStartMiles - completedMiles)
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(StrideByTheme.accent)
                    Text("Next: \(next.name), \(next.state)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("(\(milesAway) mi)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }

            // Explore Nearest Town section
            if !nearbyPOIs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("EXPLORE NEARBY")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                        .tracking(0.5)

                    ForEach(nearbyPOIs) { poi in
                        let milesAway = abs(Int(poi.distanceFromStartMiles - completedMiles))
                        Button {
                            onExplorePOI(poi)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "binoculars.fill")
                                    .font(.caption)
                                    .foregroundStyle(StrideByTheme.accent)

                                Text("\(poi.name), \(poi.state)")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text("\(milesAway) mi away")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Snapshot Loading

    private func loadSnapshot() async {
        isLoadingSnapshot = true

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 5_000,
            longitudinalMeters: 5_000
        )
        options.mapType = .satellite
        options.size = CGSize(width: 400, height: 300)
        options.scale = displayScale

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            snapshotImage = snapshot.image
        } catch {
            // Satellite snapshot failed — not critical, the card still works
            #if DEBUG
            print("LocationCardView: snapshot failed: \(error.localizedDescription)")
            #endif
        }

        isLoadingSnapshot = false
    }
}

#Preview {
    LocationCardView(
        locationName: "Hellertown, PA",
        coordinate: CLLocationCoordinate2D(latitude: 40.6627, longitude: -75.1418),
        completedMiles: 50,
        routeName: "Coast to Coast",
        route: .nycToLA,
        onExplorePOI: { poi in
            print("Explore: \(poi.name)")
        }
    )
}
