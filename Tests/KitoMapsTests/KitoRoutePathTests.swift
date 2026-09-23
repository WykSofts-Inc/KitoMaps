//
//  KitoRoutePathTests.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import CoreLocation
@testable import KitoMaps

final class KitoRoutePathTests: XCTestCase {
    /// North one degree, then east one degree, along the equator.
    private let path = KitoRoutePath([.init(latitude: 0, longitude: 0), .init(latitude: 1, longitude: 0), .init(latitude: 1, longitude: 1)])

    func testCumulativeDistances() {
        XCTAssertEqual(path.cumulativeDistances.count, 3)
        XCTAssertEqual(path.cumulativeDistances[0], 0)
        XCTAssertEqual(path.cumulativeDistances[1], 111_195, accuracy: 5)
        XCTAssertGreaterThan(path.length, path.cumulativeDistances[1])
    }

    func testPositionAlongTheFirstLeg() throws {
        let halfway = try XCTUnwrap(path.position(atDistance: path.cumulativeDistances[1] / 2))
        XCTAssertEqual(halfway.coordinate.latitude, 0.5, accuracy: 1e-6)
        XCTAssertEqual(halfway.coordinate.longitude, 0, accuracy: 1e-9)
        XCTAssertEqual(halfway.bearing, 0, accuracy: 1e-6)
    }

    func testPositionOnTheSecondLegFacesEast() throws {
        let late = try XCTUnwrap(path.position(atFraction: 0.9))
        XCTAssertEqual(late.coordinate.latitude, 1, accuracy: 1e-9)
        XCTAssertEqual(late.bearing, 90, accuracy: 0.1)
    }

    func testPositionClampsToTheEnds() throws {
        XCTAssertEqual(try XCTUnwrap(path.position(atFraction: -1)).coordinate.latitude, 0, accuracy: 1e-12)
        let end = try XCTUnwrap(path.position(atFraction: 2)).coordinate
        XCTAssertEqual(end.latitude, 1, accuracy: 1e-12)
        XCTAssertEqual(end.longitude, 1, accuracy: 1e-12)
    }

    func testSplitSharesTheSplitPoint() {
        let parts = path.split(atFraction: 0.25)
        XCTAssertEqual(parts.travelled.count, 2)
        XCTAssertEqual(parts.remaining.count, 3)
        XCTAssertEqual(parts.travelled.last?.latitude ?? 0, parts.remaining.first?.latitude ?? 1, accuracy: 1e-12)
        let total = KitoMapGeometry.length(of: parts.travelled) + KitoMapGeometry.length(of: parts.remaining)
        XCTAssertEqual(total, path.length, accuracy: 1)
    }

    func testDegeneratePaths() {
        XCTAssertNil(KitoRoutePath([]).position(atFraction: 0.5))
        let single = KitoRoutePath([.init(latitude: 3, longitude: 4)])
        XCTAssertEqual(single.length, 0)
        XCTAssertEqual(single.position(atFraction: 0.5)?.coordinate.latitude, 3)
    }
}
