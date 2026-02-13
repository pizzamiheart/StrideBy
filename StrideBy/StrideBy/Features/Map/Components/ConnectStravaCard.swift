//
//  ConnectStravaCard.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

/// A prompt card that appears on the map when Strava isn't connected.
struct ConnectStravaCard: View {
    @Environment(StravaAuthService.self) private var stravaAuth

    // Strava brand orange
    private let stravaOrange = Color(red: 0.988, green: 0.298, blue: 0.012)

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "figure.run")
                    .font(.title3)
                    .foregroundStyle(stravaOrange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Strava")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Sync your runs to start your journey")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                Task { await stravaAuth.authorize() }
            } label: {
                HStack {
                    if stravaAuth.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Connect with Strava")
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(stravaOrange)
            .disabled(stravaAuth.isLoading)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
    }
}

#Preview {
    ConnectStravaCard()
        .padding()
        .environment(StravaAuthService())
}
