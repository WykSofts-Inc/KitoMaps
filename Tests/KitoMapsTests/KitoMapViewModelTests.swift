//
//  KitoMapViewModelTests.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import SwiftUI
import CoreLocation
@_spi(KitoMapsProvider) @testable import KitoMaps

@MainActor
final class KitoMapViewModelTests: XCTestCase {
    private let route: [CLLocationCoordinate2D] = [.init(latitude: -1.2864, longitude: 36.8172), .init(latitude: -1.2921, longitude: 36.8219),
                                                   .init(latitude: -1.3000, longitude: 36.8300)]

    func testTrackerFollowsTheRoute() {
        let tracker = KitoLiveTracker(route: route, duration: 120)
        XCTAssertEqual(tracker.coordinate.latitude, route[0].latitude, accuracy: 1e-9)
        tracker.update(progress: 1)
        XCTAssertTrue(tracker.hasArrived)
        XCTAssertEqual(tracker.coordinate.latitude, route[2].latitude, accuracy: 1e-9)
        XCTAssertEqual(tracker.remainingDistance, 0, accuracy: 1e-6)
        XCTAssertEqual(tracker.formattedCountdown, "00:00")
        XCTAssertEqual(tracker.formattedETA, "Arrived")
    }

    func testTrackerHalfway() {
        let tracker = KitoLiveTracker(route: route, duration: 120)
        tracker.update(progress: 0.5)
        XCTAssertEqual(tracker.remainingTime, 60, accuracy: 1e-9)
        XCTAssertEqual(tracker.formattedCountdown, "01:00")
        XCTAssertEqual(tracker.remainingDistance, tracker.path.length / 2, accuracy: 1e-6)
        let overlays = tracker.overlays(color: .green)
        XCTAssertEqual(overlays.map(\.id), ["courier-travelled", "courier-remaining"])
        XCTAssertGreaterThan(tracker.bearing, 90)
        XCTAssertLessThan(tracker.bearing, 180)
    }

    func testTrackerResetAndClamp() {
        let tracker = KitoLiveTracker(route: route, duration: 30)
        tracker.update(progress: 4)
        XCTAssertEqual(tracker.progress, 1)
        tracker.reset()
        XCTAssertEqual(tracker.progress, 0)
        XCTAssertFalse(tracker.isRunning)
    }

    func testControllerIssuesNewRequests() {
        let controller = KitoMapController()
        XCTAssertNil(controller.request)
        controller.move(to: .fitPins)
        let first = controller.request
        controller.move(to: .fitPins)
        XCTAssertNotEqual(first, controller.request)
        controller.report(center: route[0], zoom: 12)
        XCTAssertEqual(controller.zoom, 12)
    }

    func testModifiersConfigureOptions() {
        let map = KitoMapView(pins: [])
            .clustering(cellSize: 80)
            .controls(.all)
            .showsUserLocation()
            .overlays([.circle(center: route[0], radius: 500)])
            .followsSelection(false)
        XCTAssertEqual(map.options.clusterer?.cellSize, 80)
        XCTAssertEqual(map.options.controls, .all)
        XCTAssertTrue(map.options.showsUserLocation)
        XCTAssertEqual(map.options.overlays.count, 1)
        XCTAssertFalse(map.options.followsSelection)
        XCTAssertNil(map.clustering(false).options.clusterer)
    }

    func testPinConveniences() {
        let price = KitoMapPin(id: "a", coordinate: route[0], title: "Loft", subtitle: "Kilimani", style: .bubble("KSh 4,500"), badge: "4.9")
        XCTAssertEqual(price.priceText, "KSh 4,500")
        XCTAssertNil(price.initials)
        XCTAssertEqual(price.accessibilityText, "Loft, KSh 4,500, Kilimani, Badge 4.9")
        let person = KitoMapPin(id: "b", coordinate: route[0], title: "Amina", style: .avatar(initials: "AW"))
        XCTAssertEqual(person.initials, "AW")
        XCTAssertEqual(person.style.anchor, .bottom)
        XCTAssertEqual(KitoMapPinStyle.pulse.anchor, .center)
    }

    func testRendererDrawsPinsAndCachesThem() throws {
        let pin = KitoMapPin(id: "java", coordinate: route[0], title: "Java House", style: .bubble("KSh 650"), badge: "4.6")
        let normal = try XCTUnwrap(KitoPinRenderer.image(for: pin))
        let selected = try XCTUnwrap(KitoPinRenderer.image(for: pin, selected: true))
        XCTAssertGreaterThan(normal.image.size.width, 40)
        XCTAssertGreaterThan(selected.image.size.width, normal.image.size.width)
        XCTAssertGreaterThan(normal.anchor.y, 0.6)
        XCTAssertTrue(KitoPinRenderer.image(for: pin)?.image === normal.image)
        let cluster = try XCTUnwrap(KitoPinRenderer.clusterImage(count: 12))
        XCTAssertEqual(cluster.anchor, CGPoint(x: 0.5, y: 0.5))
    }

    func testRendererAnchorMath() {
        let anchor = KitoPinRenderer.anchor(.bottom, imageSize: CGSize(width: 64, height: 74), zoom: 1)
        XCTAssertEqual(anchor.x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(anchor.y, 62.0 / 74.0, accuracy: 1e-9)
    }
}
