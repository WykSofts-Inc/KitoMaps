//
//  KitoMapView.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import MapKit
import KitoCore

/// An Apple Maps view with Kito pins, clusters, routes, circles, floating controls and an
/// optional card carousel synced with the selected pin.
///
/// ```swift
/// @State private var selected: String?
///
/// KitoMapView(pins: places, selection: $selected) { pin in
///     KitoMapPinCard(pin: pin)
/// }
/// .clustering()
/// .controls(.all)
/// ```
///
/// `KitoGoogleMapView` (KitoMapsGoogle) and `KitoLibreMapView` (KitoMapsLibre) take the same
/// arguments and modifiers.
public struct KitoMapView<Card: View>: View, KitoMapConfigurable {
    public var options = KitoMapOptions()

    let pins: [KitoMapPin]
    let externalSelection: Binding<String?>?
    let initialStyle: KitoMapStyle
    let camera: KitoMapCamera
    let controller: KitoMapController?
    let card: ((KitoMapPin) -> Card)?

    @State private var position: MapCameraPosition = .automatic
    @State private var style: KitoMapStyle
    @State private var is3D = false
    @State private var localSelection: String?
    @State private var zoomLevel: Int?
    @State private var items: [KitoMapCluster] = []
    @State private var origins: [String: CLLocationCoordinate2D] = [:]
    @State private var size: CGSize = .zero
    @State private var cardHeight: CGFloat = 0
    @State private var hasFitted = false
    @State private var isFirstReveal = true
    @State private var box = CameraBox()
    @State private var location: KitoLocationProvider?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - pins: The places to show.
    ///   - selection: The selected pin's id. Tapping a pin or swiping the cards changes it.
    ///   - style: The starting map style; the style switcher can change it.
    ///   - camera: Where the camera starts. Defaults to framing every pin.
    ///   - controller: Moves the camera from outside.
    ///   - card: A card per pin, shown in a carousel along the bottom.
    public init(pins: [KitoMapPin], selection: Binding<String?>? = nil, style: KitoMapStyle = .standard,
                camera: KitoMapCamera = .fitPins, controller: KitoMapController? = nil,
                @ViewBuilder card: @escaping (KitoMapPin) -> Card) {
        self.pins = pins
        self.externalSelection = selection
        self.initialStyle = style
        self.camera = camera
        self.controller = controller
        self.card = card
        self._style = State(initialValue: style)
    }

    private var selection: Binding<String?> {
        externalSelection ?? $localSelection
    }

    public var body: some View {
        GeometryReader { geo in
            MapReader { proxy in
                Map(position: $position, interactionModes: .all) {
                    mapContent(proxy)
                }
                .mapStyle(style.mapStyle(in3D: is3D))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .continuous) { context in cameraMoved(context, ended: false) }
                .onMapCameraChange(frequency: .onEnd) { context in cameraMoved(context, ended: true) }
            }
            .onAppear {
                size = geo.size
                start()
            }
            .onChange(of: geo.size) { _, newSize in size = newSize }
        }
        .overlay(alignment: .topTrailing) {
            if !options.controls.isEmpty {
                KitoMapControlStack(controls: options.controls, style: $style, is3D: $is3D,
                                    onLocate: { locate(zoom: 15) }, onFit: { apply(.fitPins, animated: true) })
            }
        }
        .overlay(alignment: .bottom) {
            if let card {
                KitoMapCardCarousel(pins: pins, selection: selection, card: card)
                    .padding(.bottom, theme.spacing.lg)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 + theme.spacing.lg }
            }
        }
        .onChange(of: pins) { _, newPins in
            if !hasFitted, !newPins.isEmpty, case .fitPins = camera { apply(.fitPins, animated: true) }
            recluster()
        }
        .onChange(of: selection.wrappedValue) { _, id in
            recluster()
            follow(id)
        }
        .onChange(of: controller?.request) { _, request in
            if let request { apply(request.camera, animated: request.animated) }
        }
        .onChange(of: is3D) { _, on in tilt(on) }
        .onChange(of: initialStyle) { _, newStyle in style = newStyle }
        .onChange(of: options.clusterer) { _, _ in recluster() }
    }

    // MARK: Content

    @MapContentBuilder
    private func mapContent(_ proxy: MapProxy) -> some MapContent {
        ForEach(options.overlays.compactMap(PolylineOverlay.init)) { line in
            MapPolyline(coordinates: line.coordinates)
                .stroke(line.overlay.color, style: StrokeStyle(lineWidth: line.overlay.lineWidth, lineCap: .round, lineJoin: .round,
                                                               dash: line.overlay.isDashed ? [0.1, line.overlay.lineWidth * 2] : []))
        }
        ForEach(options.overlays.compactMap(CircleOverlay.init)) { circle in
            MapCircle(center: circle.center, radius: circle.radius)
                .foregroundStyle(circle.overlay.color.opacity(0.16))
                .stroke(circle.overlay.color, lineWidth: circle.overlay.lineWidth)
        }
        if options.showsUserLocation {
            UserAnnotation()
        }
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            Annotation(item.pin?.title ?? "\(item.count) places", coordinate: item.coordinate, anchor: item.pin?.style.anchor ?? .center) {
                annotation(item, index: index, proxy: proxy)
            }
            .annotationTitles(.hidden)
        }
    }

    @ViewBuilder
    private func annotation(_ item: KitoMapCluster, index: Int, proxy: MapProxy) -> some View {
        let popIn = KitoPopIn(from: flyOffset(for: item, proxy: proxy), delay: isFirstReveal ? min(Double(index) * 0.025, 0.45) : 0)
        if let pin = item.pin {
            let isSelected = selection.wrappedValue == pin.id
            Button { select(pin.id) } label: {
                KitoMapPinView(pin: pin, isSelected: isSelected)
            }
            .buttonStyle(KitoMapPressStyle())
            .modifier(popIn)
            .accessibilityLabel(pin.accessibilityText)
            .accessibilityHint("Shows this place")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            Button { zoom(into: item) } label: {
                KitoMapClusterView(count: item.count, tint: item.sharedTint)
            }
            .buttonStyle(KitoMapPressStyle())
            .modifier(popIn)
            .accessibilityLabel("\(item.count) places")
            .accessibilityHint("Zooms in to show them")
        }
    }

    private func flyOffset(for item: KitoMapCluster, proxy: MapProxy) -> CGSize {
        guard let origin = origins[item.id],
              let from = proxy.convert(origin, to: .local),
              let to = proxy.convert(item.coordinate, to: .local) else { return .zero }
        return CGSize(width: from.x - to.x, height: from.y - to.y)
    }

    // MARK: Behaviour

    private func start() {
        if options.clusterer == nil { recluster() }
        apply(camera, animated: false)
        if options.startsIn3D { is3D = true }
        if options.showsUserLocation {
            let provider = location ?? KitoLocationProvider()
            location = provider
            if provider.authorization == .notDetermined { provider.locate { _ in } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { isFirstReveal = false }
    }

    private func select(_ id: String) {
        withAnimation(reduceMotion ? nil : .snappy) { selection.wrappedValue = id }
    }

    private func cameraMoved(_ context: MapCameraUpdateContext, ended: Bool) {
        box.camera = context.camera
        box.region = context.region
        let zoom = KitoMapGeometry.zoom(longitudeDelta: context.region.span.longitudeDelta, width: Double(max(size.width, 1)))
        if ended {
            controller?.report(center: context.region.center, zoom: zoom)
            if box.pendingTilt { tilt(true) }
        }
        let level = Int(floor(zoom))
        if level != zoomLevel {
            zoomLevel = level
            recluster()
        }
    }

    private func recluster() {
        let newItems: [KitoMapCluster]
        if let clusterer = options.clusterer {
            guard let zoomLevel else { return }
            newItems = clusterer.clusters(for: pins, zoom: Double(zoomLevel), excluding: selection.wrappedValue)
        } else {
            newItems = pins.map { KitoMapCluster(pins: [$0]) }
        }
        guard newItems != items else { return }
        // Only animate when things appear or merge; a moving courier just moves.
        guard Set(newItems.map(\.id)) != Set(items.map(\.id)) else {
            items = newItems
            return
        }
        origins = KitoClusterer.splitOrigins(from: items, to: newItems)
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75)) { items = newItems }
    }

    private var fitPadding: EdgeInsets {
        var padding = options.fitPadding
        padding.bottom += cardHeight
        return padding
    }

    private func apply(_ camera: KitoMapCamera, animated: Bool) {
        guard size.width > 0 else { return }
        switch camera {
        case .fitPins:
            let coordinates = pins.isEmpty ? options.overlays.flatMap(\.fittingCoordinates) : pins.map(\.coordinate)
            guard !coordinates.isEmpty else { return }
            hasFitted = true
            fit(coordinates, animated: animated)
        case .fit(let coordinates):
            fit(coordinates, animated: animated)
        case .center(let coordinate, let zoom):
            move(to: .region(KitoMapGeometry.region(center: coordinate, zoom: zoom, size: size)), animated: animated)
        case .userLocation(let zoom):
            locate(zoom: zoom)
        }
    }

    private func fit(_ coordinates: [CLLocationCoordinate2D], animated: Bool) {
        guard let rect = KitoMapGeometry.mapRect(fitting: coordinates, in: size, padding: fitPadding) else { return }
        move(to: .rect(rect), animated: animated)
    }

    private func move(to target: MapCameraPosition, animated: Bool) {
        if animated, !reduceMotion {
            withAnimation(.smooth(duration: 0.85)) { position = target }
        } else {
            position = target
        }
    }

    private func zoom(into cluster: KitoMapCluster) {
        let coordinates = cluster.pins.map(\.coordinate)
        guard let rect = KitoMapGeometry.mapRect(fitting: coordinates, in: size, padding: fitPadding, minimumSize: 300) else { return }
        move(to: .rect(rect), animated: true)
    }

    private func follow(_ id: String?) {
        guard options.followsSelection, let id, let pin = pins.first(where: { $0.id == id }), size.height > 0 else { return }
        if let camera = box.camera, camera.pitch > 1 {
            move(to: .camera(MapCamera(centerCoordinate: pin.coordinate, distance: camera.distance, heading: camera.heading, pitch: camera.pitch)),
                 animated: true)
            return
        }
        let span = box.region?.span ?? KitoMapGeometry.region(center: pin.coordinate, zoom: 14, size: size).span
        // Nudge the pin up so it sits in the middle of the map above the cards.
        let shift = span.latitudeDelta * Double(cardHeight / 2 / size.height)
        let center = CLLocationCoordinate2D(latitude: pin.coordinate.latitude - shift, longitude: pin.coordinate.longitude)
        move(to: .region(MKCoordinateRegion(center: center, span: span)), animated: true)
    }

    private func tilt(_ on: Bool) {
        guard let camera = box.camera else {
            box.pendingTilt = on
            return
        }
        box.pendingTilt = false
        let target = MapCamera(centerCoordinate: camera.centerCoordinate, distance: on ? min(camera.distance, 3_000) : camera.distance,
                               heading: on ? camera.heading + 20 : 0, pitch: on ? 60 : 0)
        move(to: .camera(target), animated: true)
    }

    private func locate(zoom: Double) {
        let provider = location ?? KitoLocationProvider()
        location = provider
        provider.locate { found in
            guard let found else { return }
            move(to: .region(KitoMapGeometry.region(center: found.coordinate, zoom: zoom, size: size)), animated: true)
        }
    }
}

public extension KitoMapView where Card == EmptyView {
    /// A map without the card carousel.
    init(pins: [KitoMapPin], selection: Binding<String?>? = nil, style: KitoMapStyle = .standard,
         camera: KitoMapCamera = .fitPins, controller: KitoMapController? = nil) {
        self.pins = pins
        self.externalSelection = selection
        self.initialStyle = style
        self.camera = camera
        self.controller = controller
        self.card = nil
        self._style = State(initialValue: style)
    }
}

// MARK: - Helpers

/// The latest camera, kept outside SwiftUI state so continuous updates don't redraw the map.
private final class CameraBox {
    var camera: MapCamera?
    var region: MKCoordinateRegion?
    /// A 3D tilt asked for before the map reported its first camera.
    var pendingTilt = false
}

private struct PolylineOverlay: Identifiable {
    let overlay: KitoMapOverlay
    let coordinates: [CLLocationCoordinate2D]
    var id: String { overlay.id }

    init?(_ overlay: KitoMapOverlay) {
        guard case .polyline(let coordinates) = overlay.shape, coordinates.count > 1 else { return nil }
        self.overlay = overlay
        self.coordinates = coordinates
    }
}

private struct CircleOverlay: Identifiable {
    let overlay: KitoMapOverlay
    let center: CLLocationCoordinate2D
    let radius: CLLocationDistance
    var id: String { overlay.id }

    init?(_ overlay: KitoMapOverlay) {
        guard case .circle(let center, let radius) = overlay.shape else { return nil }
        self.overlay = overlay
        self.center = center
        self.radius = radius
    }
}

extension KitoMapOverlay {
    /// Points to frame when fitting the camera to this overlay.
    @_spi(KitoMapsProvider) public var fittingCoordinates: [CLLocationCoordinate2D] {
        switch shape {
        case .polyline(let coordinates): return coordinates
        case .circle(let center, let radius): return KitoMapGeometry.circle(center: center, radius: radius, segments: 8)
        }
    }
}
