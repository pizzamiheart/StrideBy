//
//  ProfileScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct ProfileScreen: View {
    @Environment(StravaAuthService.self) private var stravaAuth
    @Environment(RunProgressManager.self) private var progressManager

    private let route: RunRoute = .nycToLA

    private var percentComplete: Int {
        guard route.totalDistanceMiles > 0 else { return 0 }
        return Int(min(progressManager.totalMiles, route.totalDistanceMiles)
                   / route.totalDistanceMiles * 100)
    }

    var body: some View {
        NavigationStack {
            List {
                // Stats header
                Section {
                    VStack(spacing: 20) {
                        // Avatar
                        Circle()
                            .fill(StrideByTheme.accent.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "figure.run")
                                    .font(.title)
                                    .foregroundStyle(StrideByTheme.accent)
                            )

                        if let name = stravaAuth.athleteName {
                            Text(name)
                                .font(.headline)
                        }

                        // Stats row
                        HStack(spacing: 0) {
                            statItem(value: "\(Int(progressManager.totalMiles))", label: "Miles")
                            Divider().frame(height: 30)
                            statItem(value: "\(percentComplete)%", label: "Complete")
                            Divider().frame(height: 30)
                            statItem(value: "\(progressManager.runCount)", label: "Runs")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // Strava connection
                Section("Strava") {
                    if stravaAuth.isAuthenticated {
                        HStack {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            if progressManager.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button("Resync") {
                                    Task { await progressManager.sync(using: stravaAuth) }
                                }
                                .font(.caption)
                            }
                        }

                        Button("Disconnect", role: .destructive) {
                            stravaAuth.disconnect()
                        }
                    } else {
                        Button {
                            Task { await stravaAuth.authorize() }
                        } label: {
                            HStack {
                                Label("Connect Strava", systemImage: "link")
                                Spacer()
                                if stravaAuth.isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .disabled(stravaAuth.isLoading)
                    }

                    if let error = stravaAuth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Settings
                Section("Settings") {
                    Label("Notifications", systemImage: "bell")
                    Label("Units", systemImage: "ruler")
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileScreen()
        .environment(StravaAuthService())
        .environment(RunProgressManager())
}
