//
//  KitoPolylineTests.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import CoreLocation
@testable import KitoMaps

final class KitoPolylineTests: XCTestCase {
    /// The example from Google's polyline algorithm documentation.
    private let encoded = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"

    func testDecodesTheReferenceExample() throws {
        let points = try XCTUnwrap(KitoPolyline.decode(encoded))
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].latitude, 38.5, accuracy: 1e-6)
        XCTAssertEqual(points[0].longitude, -120.2, accuracy: 1e-6)
        XCTAssertEqual(points[1].latitude, 40.7, accuracy: 1e-6)
        XCTAssertEqual(points[1].longitude, -120.95, accuracy: 1e-6)
        XCTAssertEqual(points[2].latitude, 43.252, accuracy: 1e-6)
        XCTAssertEqual(points[2].longitude, -126.453, accuracy: 1e-6)
    }

    func testEncodesTheReferenceExample() {
        let points = [CLLocationCoordinate2D(latitude: 38.5, longitude: -120.2),
                      .init(latitude: 40.7, longitude: -120.95), .init(latitude: 43.252, longitude: -126.453)]
        XCTAssertEqual(KitoPolyline.encode(points), encoded)
    }

    func testRoundTripAtPrecisionSix() throws {
        let points = [CLLocationCoordinate2D(latitude: -1.292066, longitude: 36.821946),
                      .init(latitude: -1.286389, longitude: 36.817223), .init(latitude: -4.043477, longitude: 39.668206)]
        let decoded = try XCTUnwrap(KitoPolyline.decode(KitoPolyline.encode(points, precision: 6), precision: 6))
        XCTAssertEqual(decoded.count, points.count)
        for (a, b) in zip(decoded, points) {
            XCTAssertEqual(a.latitude, b.latitude, accuracy: 1e-6)
            XCTAssertEqual(a.longitude, b.longitude, accuracy: 1e-6)
        }
    }

    func testEmptyAndMalformedInput() {
        XCTAssertEqual(KitoPolyline.decode("")?.count, 0)
        XCTAssertNil(KitoPolyline.decode("_p~iF"))
        XCTAssertNil(KitoPolyline.decode("  "))
    }
}
