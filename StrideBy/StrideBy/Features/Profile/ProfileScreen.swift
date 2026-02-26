//
//  ProfileScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI
import UserNotifications
import UIKit

struct ProfileScreen: View {
    @Environment(StravaAuthService.self) private var stravaAuth
    @Environment(RunProgressManager.self) private var progressManager
    @Environment(RouteManager.self) private var routeManager
    @AppStorage("strideby_distance_unit") private var distanceUnitRawValue = DistanceUnit.miles.rawValue
    @AppStorage("strideby_notifications_enabled") private var notificationsEnabled = false
    @AppStorage("strideby_notifications_route_discovery_enabled") private var routeDiscoveryNotificationsEnabled = true
    @AppStorage("strideby_notifications_milestones_enabled") private var milestoneNotificationsEnabled = true
    @AppStorage("strideby_notifications_social_enabled") private var socialNotificationsEnabled = true

    @State private var showingNotificationsAlert = false
    @State private var notificationsExpanded = true

    private var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRawValue) ?? .miles }
        set { distanceUnitRawValue = newValue.rawValue }
    }

    private var percentComplete: Int {
        guard let route = routeManager.activeRoute,
              route.totalDistanceMiles > 0 else { return 0 }
        let progress = routeManager.progressMiles(totalMiles: progressManager.totalMiles)
        return Int(min(progress, route.totalDistanceMiles)
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
                            statItem(
                                value: "\(Int(distanceUnit.convert(miles: progressManager.totalMiles)))",
                                label: distanceUnit.displayName
                            )
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

                    if let syncError = progressManager.errorMessage {
                        Text(syncError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Settings
                Section("Settings") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notifications", systemImage: "bell")
                    }
                    .onChange(of: notificationsEnabled) { _, enabled in
                        handleNotificationToggle(enabled)
                    }

                    DisclosureGroup("Notification Preferences", isExpanded: $notificationsExpanded) {
                        Toggle("Route Discovery Nudges", isOn: $routeDiscoveryNotificationsEnabled)
                        Toggle("Milestone Alerts", isOn: $milestoneNotificationsEnabled)
                        Toggle("Social Alerts", isOn: $socialNotificationsEnabled)
                    }
                    .disabled(!notificationsEnabled)

                    Picker(selection: $distanceUnitRawValue) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit.rawValue)
                        }
                    } label: {
                        Label("Units", systemImage: "ruler")
                    }
                }
            }
            .navigationTitle("Profile")
            .task {
                await refreshNotificationStatus()
            }
            .alert("Notifications Disabled", isPresented: $showingNotificationsAlert) {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in iOS Settings to receive StrideBy alerts.")
            }
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

    private func handleNotificationToggle(_ enabled: Bool) {
        guard enabled else { return }
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if !granted {
                await MainActor.run {
                    notificationsEnabled = false
                    showingNotificationsAlert = true
                }
            }
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral

        await MainActor.run {
            if !isAuthorized {
                notificationsEnabled = false
            }
        }
    }
}

#Preview {
    ProfileScreen()
        .environment(StravaAuthService())
        .environment(RunProgressManager())
        .environment(RouteManager())
}
