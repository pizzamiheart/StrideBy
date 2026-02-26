//
//  PostRunCelebrationCard.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/17/26.
//

import SwiftUI

struct PostRunCelebrationCard: View {
    @AppStorage("strideby_distance_unit") private var distanceUnitRawValue = DistanceUnit.miles.rawValue

    let milesAdvanced: Double
    let locationName: String
    var onDismiss: (() -> Void)?
    var onShare: (() -> Void)?

    private var milesText: String {
        let unit = DistanceUnit(rawValue: distanceUnitRawValue) ?? .miles
        let value = unit.convert(miles: milesAdvanced)
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    private var unitText: String {
        (DistanceUnit(rawValue: distanceUnitRawValue) ?? .miles).abbreviation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label("New Progress", systemImage: "sparkles")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(StrideByTheme.accent)

                Spacer()

                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss celebration")
                }
            }

            Text("You advanced \(milesText) \(unitText) to \(locationName).")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                Button("Nice") {
                    onDismiss?()
                }
                .buttonStyle(.bordered)

                if let onShare {
                    Button {
                        onShare()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StrideByTheme.accent)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius)
                .stroke(.white.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }
}

#Preview {
    PostRunCelebrationCard(milesAdvanced: 4.3, locationName: "Versailles")
        .padding()
}
