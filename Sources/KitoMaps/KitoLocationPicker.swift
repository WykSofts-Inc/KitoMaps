//
//  KitoLocationPicker.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import MapKit
import KitoCore

/// The location chosen in `KitoLocationPicker`.
public struct KitoPickedLocation: Equatable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    /// The first line, e.g. "Kenyatta Avenue".
    public var name: String
    /// The rest, e.g. "Central Business District, Nairobi".
    public var address: String

    public init(coordinate: CLLocationCoordinate2D, name: String, address: String) {
        self.coordinate = coordinate
        self.name = name
        self.address = address
    }

    public static func == (lhs: KitoPickedLocation, rhs: KitoPickedLocation) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.name == rhs.name && lhs.address == rhs.address
    }
}

/// Drag the map under a fixed pin to choose a spot — the delivery-app "set your location"
/// screen. The pin lifts while the map moves, drops when it stops, and the address under it
/// is looked up.
///
/// ```swift
/// KitoLocationPicker(initialCoordinate: nairobi) { picked in
///     order.dropOff = picked
/// }
/// ```
public struct KitoLocationPicker: View {
    let title: String
    let confirmTitle: String
    let systemImage: String
    let onConfirm: (KitoPickedLocation) -> Void

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D
    @State private var picked: KitoPickedLocation?
    @State private var isMoving = false
    @State private var isLookingUp = false
    @State private var drops = 0
    @State private var lookup: Task<Void, Never>?
    @State private var geocoder = CLGeocoder()
    @State private var location: KitoLocationProvider?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - initialCoordinate: Where the map starts.
    ///   - zoom: The starting zoom level (16 ≈ a few streets).
    ///   - title: The heading on the card.
    ///   - confirmTitle: The button title.
    ///   - systemImage: The glyph in the centre pin.
    ///   - onConfirm: Called with the chosen location.
    public init(initialCoordinate: CLLocationCoordinate2D, zoom: Double = 16, title: String = "Deliver here",
                confirmTitle: String = "Confirm location", systemImage: String = "house.fill",
                onConfirm: @escaping (KitoPickedLocation) -> Void) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.systemImage = systemImage
        self.onConfirm = onConfirm
        let delta = KitoMapGeometry.longitudeDelta(zoom: zoom, width: 390)
        _position = State(initialValue: .region(MKCoordinateRegion(center: initialCoordinate,
                                                                   span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta))))
        _center = State(initialValue: initialCoordinate)
    }

    public var body: some View {
        // The card overlaps the map's bottom edge; the pin stays on the map view's true centre.
        VStack(spacing: -theme.radii.xl) {
            mapLayer
            card
        }
        .sensoryFeedback(.impact(weight: .light), trigger: drops)
    }

    private var mapLayer: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .continuous) { context in
                center = context.region.center
                if !isMoving { withAnimation(lift) { isMoving = true } }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                center = context.region.center
                withAnimation(lift) { isMoving = false }
                drops += 1
                lookUp(context.region.center)
            }
            .onAppear { lookUp(center) }

            centrePin.allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            KitoMapControlButton(systemImage: "location.fill", label: "Use my location") { locate() }
                .padding(theme.spacing.lg)
        }
    }

    private var lift: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.55)
    }

    private var centrePin: some View {
        let pin = KitoMapPin(id: "picker", coordinate: center, title: title, style: .teardrop, systemImage: systemImage)
        return ZStack {
            Ellipse()
                .fill(.black.opacity(isMoving ? 0.12 : 0.25))
                .frame(width: isMoving ? 10 : 16, height: isMoving ? 4 : 6)
                .blur(radius: isMoving ? 2 : 1)
            KitoMapPinView(pin: pin)
                .scaleEffect(1.2, anchor: .bottom)
                .offset(y: -21 - (isMoving ? 18 : 0))
        }
        .accessibilityHidden(true)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Capsule().fill(theme.colors.border).frame(width: 36, height: 5).frame(maxWidth: .infinity)
            Text(title).font(theme.typography.caption.weight(.semibold)).textCase(.uppercase)
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
            HStack(spacing: theme.spacing.md) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.colors.primary)
                    .frame(width: 44, height: 44)
                    .background(theme.colors.primary.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(picked?.name ?? "Finding address…")
                        .font(theme.typography.bodyEmphasized)
                        .foregroundStyle(theme.colors.onSurface)
                        .lineLimit(1)
                    Text(picked?.address ?? "Move the map to place the pin")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                        .lineLimit(2)
                }
                .redacted(reason: isMoving || isLookingUp ? .placeholder : [])
                .contentTransition(.opacity)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            Button {
                onConfirm(picked ?? KitoPickedLocation(coordinate: center, name: Self.coordinateText(center), address: ""))
            } label: {
                Text(confirmTitle)
                    .font(theme.typography.button)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(theme.colors.surface)
                    .background(theme.colors.onSurface, in: Capsule())
            }
            .buttonStyle(KitoMapPressStyle())
            .disabled(isMoving)
            .opacity(isMoving ? 0.5 : 1)
        }
        .padding(theme.spacing.xl)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: theme.radii.xl + 8, topTrailingRadius: theme.radii.xl + 8, style: .continuous)
                .fill(theme.colors.surface)
                .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(.snappy, value: picked)
        .animation(.snappy, value: isMoving)
    }

    private func lookUp(_ coordinate: CLLocationCoordinate2D) {
        lookup?.cancel()
        isLookingUp = true
        lookup = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            geocoder.cancelGeocode()
            let placemark = try? await geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)).first
            guard !Task.isCancelled else { return }
            picked = Self.location(from: placemark, at: coordinate)
            isLookingUp = false
        }
    }

    private func locate() {
        let provider = location ?? KitoLocationProvider()
        location = provider
        provider.locate { found in
            guard let found else { return }
            let delta = KitoMapGeometry.longitudeDelta(zoom: 16.5, width: 390)
            let region = MKCoordinateRegion(center: found.coordinate, span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta))
            if reduceMotion { position = .region(region) } else { withAnimation(.smooth(duration: 0.8)) { position = .region(region) } }
        }
    }

    static func location(from placemark: CLPlacemark?, at coordinate: CLLocationCoordinate2D) -> KitoPickedLocation {
        guard let placemark else {
            return KitoPickedLocation(coordinate: coordinate, name: coordinateText(coordinate), address: "Address unavailable")
        }
        let name = placemark.name ?? placemark.thoroughfare ?? coordinateText(coordinate)
        var parts: [String] = []
        for part in [placemark.thoroughfare, placemark.subLocality, placemark.locality, placemark.country] {
            if let part, !part.isEmpty, part != name, !parts.contains(part) { parts.append(part) }
        }
        return KitoPickedLocation(coordinate: coordinate, name: name, address: parts.joined(separator: ", "))
    }

    static func coordinateText(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}
