//
//  RouteGeneratorSheet.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/14/26.
//

#if DEBUG

import SwiftUI

/// Debug sheet for generating pre-baked route geometry via MKDirections.
///
/// Tap "Generate All Routes" to process every route sequentially, or tap an
/// individual route to regenerate just that one. Results are written as JSON
/// files into the project's Core/RouteGeometry/ directory — rebuild the app
/// to bundle them.
struct RouteGeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var generator = RouteGeometryGenerator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status banner
                statusBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Route buttons
                List {
                    Section("Generate") {
                        Button {
                            Task { await generator.generateAll() }
                        } label: {
                            Label("Generate All Routes", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(generator.state.isRunning)

                        ForEach(RunRoute.allRoutes) { route in
                            Button {
                                Task { await generator.generateSingle(route) }
                            } label: {
                                Label(route.name, systemImage: route.icon)
                            }
                            .disabled(generator.state.isRunning)
                        }
                    }

                    Section("Log") {
                        if generator.log.isEmpty {
                            Text("No activity yet. Tap a button above to start.")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(Array(generator.log.enumerated()), id: \.offset) { _, entry in
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Route Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        switch generator.state {
        case .idle:
            EmptyView()

        case .generating(let routeId, let segment, let total):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("\(routeId): segment \(segment)/\(total)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

        case .retrying(let routeId, let segment, let attempt):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("\(routeId): retrying segment \(segment) (attempt \(attempt))")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

        case .finished(let routeId, let count):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(routeId): \(count) coordinates saved")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

        case .failed(let routeId, let message):
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("\(routeId): \(message)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    RouteGeneratorSheet()
}

#endif
