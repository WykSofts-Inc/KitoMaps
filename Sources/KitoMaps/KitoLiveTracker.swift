//
//  KitoLiveTracker.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import CoreLocation
import Observation

/// Moves a courier smoothly along a route with a live ETA — the delivery-tracking map.
///
/// ```swift
/// @State private var rider = KitoLiveTracker(route: path, duration: 90)
///
/// KitoMapView(pins: [shop, home, rider.pin])
///     .overlays(rider.overlays(color: .green))
///     .onAppear { rider.start() }
/// Text("Arriving in \(rider.formattedCountdown)")
/// ```
///
/// For a real courier, call `update(progress:)` from your location feed instead of `start()`.
@MainActor
@Observable
public final class KitoLiveTracker {
    public let path: KitoRoutePath
    /// How long the whole trip takes when simulated with `start()`.
    public var duration: TimeInterval
    /// The courier pin; its coordinate and heading follow the route.
    public private(set) var pin: KitoMapPin
    /// 0 at the start, 1 on arrival.
    public private(set) var progress: Double = 0
    public private(set) var isRunning = false

    private var task: Task<Void, Never>?
    private var startedAt: Date?
    private var progressAtStart: Double = 0

    /// - Parameters:
    ///   - route: The path to follow.
    ///   - duration: Seconds from start to arrival for the simulation.
    ///   - pin: The courier. Its coordinate and heading are replaced as it moves.
    public init(route: [CLLocationCoordinate2D], duration: TimeInterval = 60,
                pin: KitoMapPin = KitoMapPin(id: "courier", coordinate: CLLocationCoordinate2D(),
                                             title: "Courier", style: .pulse, systemImage: "bicycle")) {
        self.path = KitoRoutePath(route)
        self.duration = max(duration, 1)
        var courier = pin
        if let start = path.position(atFraction: 0) {
            courier.coordinate = start.coordinate
            courier.heading = start.bearing
        }
        self.pin = courier
    }

    /// The courier's position.
    public var coordinate: CLLocationCoordinate2D { pin.coordinate }
    /// Degrees clockwise from north.
    public var bearing: Double { pin.heading ?? 0 }
    public var hasArrived: Bool { progress >= 1 }
    /// Metres still to go.
    public var remainingDistance: CLLocationDistance { path.length * (1 - progress) }
    /// Seconds still to go at the simulated pace.
    public var remainingTime: TimeInterval { duration * (1 - progress) }
    /// "04:05"
    public var formattedCountdown: String { KitoMapFormat.countdown(remainingTime) }
    /// "3 min"
    public var formattedETA: String { hasArrived ? "Arrived" : KitoMapFormat.duration(remainingTime) }
    /// The route behind and ahead of the courier.
    public var travelledPath: [CLLocationCoordinate2D] { path.split(atFraction: progress).travelled }
    public var remainingPath: [CLLocationCoordinate2D] { path.split(atFraction: progress).remaining }

    /// The route ahead in `color` and the part already covered greyed out.
    public func overlays(color: Color = .blue) -> [KitoMapOverlay] {
        let parts = path.split(atFraction: progress)
        return [
            .polyline(parts.travelled, id: "\(pin.id)-travelled", color: .gray.opacity(0.45), lineWidth: 6),
            .polyline(parts.remaining, id: "\(pin.id)-remaining", color: color, lineWidth: 6),
        ]
    }

    /// Simulates the trip from the current progress, about 30 updates a second.
    public func start() {
        guard !isRunning, progress < 1 else { return }
        isRunning = true
        startedAt = Date()
        progressAtStart = progress
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(self.startedAt ?? Date())
                self.update(progress: self.progressAtStart + elapsed / self.duration)
                if self.progress >= 1 { self.stopTask(); return }
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    /// Stops where it is.
    public func pause() {
        stopTask()
    }

    /// Back to the start.
    public func reset() {
        stopTask()
        update(progress: 0)
    }

    /// Moves the courier to `progress` (0…1), turning smoothly to the new heading.
    public func update(progress newValue: Double) {
        progress = min(max(newValue, 0), 1)
        guard let position = path.position(atFraction: progress) else { return }
        pin.coordinate = position.coordinate
        pin.heading = KitoMapGeometry.interpolateAngle(from: pin.heading ?? position.bearing, to: position.bearing, fraction: 0.25)
    }

    private func stopTask() {
        task?.cancel()
        task = nil
        isRunning = false
    }
}
