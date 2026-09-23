//
//  KitoMapSnapshot.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import MapKit
import KitoCore

/// Static map images for cards and lists — cheaper than a live map in every row.
@MainActor
public enum KitoMapSnapshotter {
    /// A map image of `region` with `pins` drawn on it.
    public static func image(region: MKCoordinateRegion, size: CGSize, pins: [KitoMapPin] = [],
                             colorScheme: ColorScheme = .light, theme: KitoTheme = .light,
                             displayScale: CGFloat = 3, pointsOfInterest: Bool = false) async throws -> UIImage {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = displayScale
        options.traitCollection = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
        configuration.pointOfInterestFilter = pointsOfInterest ? .includingAll : .excludingAll
        options.preferredConfiguration = configuration

        let snapshot = try await MKMapSnapshotter(options: options).start()
        let markers = pins.compactMap { pin in
            KitoPinRenderer.image(for: pin, theme: theme, colorScheme: colorScheme, displayScale: displayScale).map { (pin, $0) }
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = displayScale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            snapshot.image.draw(at: .zero)
            for (pin, marker) in markers {
                let point = snapshot.point(for: pin.coordinate)
                let origin = CGPoint(x: point.x - marker.anchor.x * marker.image.size.width,
                                     y: point.y - marker.anchor.y * marker.image.size.height)
                marker.image.draw(at: origin)
            }
        }
    }
}

/// A static map image that loads in the background with a shimmer, redrawn for dark mode.
///
/// ```swift
/// KitoMapSnapshot(center: carnivore, pins: [carnivorePin])
///     .frame(height: 140)
///     .clipShape(RoundedRectangle(cornerRadius: 20))
/// ```
public struct KitoMapSnapshot: View {
    let region: MKCoordinateRegion?
    let pins: [KitoMapPin]

    @State private var image: UIImage?
    @State private var size: CGSize = .zero
    @State private var shimmer = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A snapshot centred on `center`, about `meters` across.
    public init(center: CLLocationCoordinate2D, meters: CLLocationDistance = 1_200, pins: [KitoMapPin] = []) {
        self.region = MKCoordinateRegion(center: center, latitudinalMeters: meters, longitudinalMeters: meters)
        self.pins = pins
    }

    /// A snapshot framing every pin.
    public init(fitting pins: [KitoMapPin]) {
        self.region = KitoMapGeometry.region(fitting: pins.map(\.coordinate), paddingFactor: 1.6, minimumSpan: 0.008)
        self.pins = pins
    }

    public var body: some View {
        ZStack {
            theme.colors.surfaceMuted
            if let image {
                Image(uiImage: image).resizable().scaledToFill().transition(.opacity)
            } else {
                LinearGradient(colors: [.clear, theme.colors.surface.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                    .offset(x: shimmer ? size.width : -size.width)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { shimmer = true }
                    }
            }
        }
        .clipped()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .task(id: TaskKey(size: size, dark: colorScheme == .dark)) { await load() }
        .animation(.easeOut(duration: 0.25), value: image != nil)
        .accessibilityElement()
        .accessibilityLabel(pins.isEmpty ? "Map" : "Map showing \(pins.map(\.title).joined(separator: ", "))")
    }

    private func load() async {
        guard let region, size.width > 1, size.height > 1 else { return }
        image = try? await KitoMapSnapshotter.image(region: region, size: size, pins: pins, colorScheme: colorScheme,
                                                    theme: theme, displayScale: displayScale)
    }

    private struct TaskKey: Equatable {
        let size: CGSize
        let dark: Bool
    }
}
