//
//  DropPinComposerScreen.swift
//  StrideBy
//
//  Created by Codex on 2/25/26.
//

import MapKit
import SwiftUI
import UIKit

struct DropPinComposerScreen: View {
    let draft: DropPinDraft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    @State private var style = DropPinCardStyle()
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isRendering = false
    @State private var renderError: String?
    @State private var selectedScene: MKLookAroundScene?
    @State private var fallbackImage: UIImage
    @State private var previewCardSize = CGSize(width: 360, height: 640)
    @State private var showingViewEditor = false

    init(draft: DropPinDraft) {
        self.draft = draft
        _selectedScene = State(initialValue: draft.initialScene)
        _fallbackImage = State(initialValue: draft.capturedImage)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let previewWidth = min(proxy.size.width - 28, 360)
                let previewHeight = previewWidth * (16.0 / 9.0)

                VStack(spacing: 14) {
                    Spacer(minLength: 4)

                    DropPinShareCardView(
                        lookAroundImage: fallbackImage,
                        route: draft.route,
                        routeName: draft.routeName,
                        locationName: draft.locationName,
                        completedMiles: draft.completedMiles,
                        lastRunMiles: draft.lastRunMiles,
                        style: style
                    )
                    .frame(width: previewWidth, height: previewHeight)
                    .overlay(alignment: .topLeading) {
                        Text("Tap Map to Edit")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.34), in: Capsule())
                            .padding(14)
                    }
                    .onTapGesture {
                        if selectedScene != nil {
                            showingViewEditor = true
                        }
                    }

                    Spacer(minLength: 8)

                    controlsPanel
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .onAppear {
                    previewCardSize = CGSize(width: previewWidth, height: previewHeight)
                }
                .onChange(of: previewWidth) { _, newWidth in
                    previewCardSize = CGSize(width: newWidth, height: newWidth * (16.0 / 9.0))
                }
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea())
            .navigationTitle("Share The View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        shareCard()
                    } label: {
                        if isRendering {
                            ProgressView()
                        } else {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isRendering)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .alert("Couldn’t Capture View", isPresented: Binding(
            get: { renderError != nil },
            set: { isPresented in
                if !isPresented { renderError = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(renderError ?? "Try moving the scene and sharing again.")
        }
        .fullScreenCover(isPresented: $showingViewEditor) {
            if let selectedScene {
                DropPinViewEditorScreen(initialScene: selectedScene) { newScene, capturedImage in
                    self.selectedScene = newScene
                    Task { @MainActor in
                        if let capturedImage {
                            fallbackImage = capturedImage
                        } else if let captured = await snapshotImage(
                            for: newScene,
                            cardSize: previewCardSize,
                            scale: displayScale
                        ) {
                            fallbackImage = captured
                        }
                    }
                }
            }
        }
    }

    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if selectedScene != nil {
                Label("Click the Map to frame your shot", systemImage: "hand.draw")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
            }

            Text("Color Palette")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
                .textCase(.uppercase)
                .tracking(1.1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DropPinBackdropPreset.allCases) { preset in
                        Button {
                            style.backdrop = preset
                        } label: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: preset.colors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            style.backdrop == preset
                                            ? .white.opacity(0.95)
                                            : .white.opacity(0.35),
                                            lineWidth: style.backdrop == preset ? 3 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(preset.displayName))
                    }
                }
            }

            Text(style.backdrop.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            Text("Route Outline")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
                .textCase(.uppercase)
                .tracking(1.1)
                .padding(.top, 2)

            HStack(spacing: 8) {
                ForEach(DropPinOutlineStyle.allCases) { option in
                    Button {
                        style.outlineStyle = option
                    } label: {
                        Text(option.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                style.outlineStyle == option
                                ? .white.opacity(0.26)
                                : .white.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func shareCard() {
        guard !isRendering else { return }
        isRendering = true

        Task { @MainActor in
            guard let image = DropPinShareCardRenderer.makeStoryImage(
                lookAroundImage: fallbackImage,
                route: draft.route,
                routeName: draft.routeName,
                locationName: draft.locationName,
                completedMiles: draft.completedMiles,
                lastRunMiles: draft.lastRunMiles,
                style: style,
                cardSize: previewCardSize,
                scale: displayScale
            ) else {
                renderError = "Couldn’t render the share card."
                isRendering = false
                return
            }

            let caption = [
                "Dropped a pin on my StrideBy route in \(draft.locationName).",
                "strideby://join"
            ].joined(separator: "\n")

            shareItems = [caption, image]
            showingShareSheet = true
            isRendering = false
        }
    }

    private func snapshotImage(
        for scene: MKLookAroundScene,
        cardSize: CGSize,
        scale: CGFloat
    ) async -> UIImage? {
        let stageHeight = cardSize.height * 0.58
        let imageWidth = max(260, (cardSize.width - 100) * scale)
        let imageHeight = max(330, (stageHeight - 60) * scale)

        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: imageWidth, height: imageHeight)

        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
        do {
            let snapshot = try await snapshotter.snapshot
            return snapshot.image
        } catch {
            return nil
        }
    }
}

private struct DropPinViewEditorScreen: View {
    let initialScene: MKLookAroundScene
    var onSave: (MKLookAroundScene, UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedScene: MKLookAroundScene?
    @State private var saveCaptureRequestID = 0
    @State private var pendingSave = false

    var body: some View {
        DropPinLiveLookAroundStage(
            initialScene: initialScene,
            saveCaptureRequestID: saveCaptureRequestID,
            onSceneDidChange: { updatedScene in
                editedScene = updatedScene
            },
            onSnapshotCaptured: { snapshot in
                guard pendingSave else { return }
                pendingSave = false
                onSave(editedScene ?? initialScene, snapshot)
                dismiss()
            }
        )
        .ignoresSafeArea()
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.36), in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                pendingSave = true
                saveCaptureRequestID += 1
            } label: {
                Label("Save View", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [StrideByTheme.accent, Color(red: 0.08, green: 0.32, blue: 0.66)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            }
            .padding(.bottom, 8)
        }
    }
}

private struct DropPinLiveLookAroundStage: UIViewControllerRepresentable {
    let initialScene: MKLookAroundScene
    let saveCaptureRequestID: Int
    var onSceneDidChange: (MKLookAroundScene) -> Void
    var onSnapshotCaptured: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSceneDidChange: onSceneDidChange,
            onSnapshotCaptured: onSnapshotCaptured
        )
    }

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let controller = MKLookAroundViewController(scene: initialScene)
        controller.isNavigationEnabled = true
        controller.showsRoadLabels = true
        controller.badgePosition = .bottomTrailing
        controller.delegate = context.coordinator
        context.coordinator.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: MKLookAroundViewController, context: Context) {
        context.coordinator.onSceneDidChange = onSceneDidChange
        context.coordinator.onSnapshotCaptured = onSnapshotCaptured
        if controller.scene == nil {
            controller.scene = initialScene
        }
        context.coordinator.captureIfRequested(saveCaptureRequestID)
    }

    final class Coordinator: NSObject, MKLookAroundViewControllerDelegate {
        var onSceneDidChange: (MKLookAroundScene) -> Void
        var onSnapshotCaptured: (UIImage?) -> Void
        weak var controller: MKLookAroundViewController?
        private var lastSaveCaptureRequestID = 0

        init(
            onSceneDidChange: @escaping (MKLookAroundScene) -> Void,
            onSnapshotCaptured: @escaping (UIImage?) -> Void
        ) {
            self.onSceneDidChange = onSceneDidChange
            self.onSnapshotCaptured = onSnapshotCaptured
        }

        func lookAroundViewControllerDidUpdateScene(_ viewController: MKLookAroundViewController) {
            if let scene = viewController.scene {
                onSceneDidChange(scene)
            }
        }

        func captureIfRequested(_ requestID: Int) {
            guard requestID > lastSaveCaptureRequestID else { return }
            lastSaveCaptureRequestID = requestID
            DispatchQueue.main.async {
                self.onSnapshotCaptured(self.captureCurrentView())
            }
        }

        private func captureCurrentView() -> UIImage? {
            guard let view = controller?.view else { return nil }
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = view.traitCollection.displayScale
            let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
            return renderer.image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }
        }
    }
}
