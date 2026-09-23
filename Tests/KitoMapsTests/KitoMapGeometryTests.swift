//
//  KitoMapGeometryTests.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import SwiftUI
import MapKit
@testable import KitoMaps

final class KitoMapGeometryTests: XCTestCase {
    private let nairobi = CLLocationCoordinate2D(latitude: -1.2921, longitude: 36.8219)
    private let mombasa = CLLocationCoordinate2D(latitude: -4.0435, longitude: 39.6682)

    func testOneDegreeOfLatitude() {
        let d = KitoMapGeometry.distance(from: .init(latitude: 0, longitude: 0), to: .init(latitude: 1, longitude: 0))
        XCTAssertEqual(d, 111_195, accuracy: 5)
    }

    func testNairobiToMombasa() {
        XCTAssertEqual(KitoMapGeometry.distance(from: nairobi, to: mombasa) / 1000, 440, accuracy: 5)
    }

    func testBearingsOnTheEquator() {
        let origin = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        XCTAssertEqual(KitoMapGeometry.bearing(from: origin, to: .init(latitude: 1, longitude: 0)), 0, accuracy: 1e-6)
        XCTAssertEqual(KitoMapGeometry.bearing(from: origin, to: .init(latitude: 0, longitude: 1)), 90, accuracy: 1e-6)
        XCTAssertEqual(KitoMapGeometry.bearing(from: origin, to: .init(latitude: -1, longitude: 0)), 180, accuracy: 1e-6)
        XCTAssertEqual(KitoMapGeometry.bearing(from: origin, to: .init(latitude: 0, longitude: -1)), 270, accuracy: 1e-6)
    }

    func testNairobiToMombasaHeadsSouthEast() {
        let bearing = KitoMapGeometry.bearing(from: nairobi, to: mombasa)
        XCTAssertGreaterThan(bearing, 90)
        XCTAssertLessThan(bearing, 180)
    }

    func testInterpolateClampsAndFindsTheMidpoint() {
        let mid = KitoMapGeometry.interpolate(from: .init(latitude: 0, longitude: 0), to: .init(latitude: 2, longitude: 4), fraction: 0.5)
        XCTAssertEqual(mid.latitude, 1, accuracy: 1e-12)
        XCTAssertEqual(mid.longitude, 2, accuracy: 1e-12)
        let past = KitoMapGeometry.interpolate(from: .init(latitude: 0, longitude: 0), to: .init(latitude: 2, longitude: 4), fraction: 3)
        XCTAssertEqual(past.latitude, 2, accuracy: 1e-12)
    }

    func testAngleInterpolationTakesTheShortWay() {
        XCTAssertEqual(KitoMapGeometry.interpolateAngle(from: 350, to: 10, fraction: 0.5), 0, accuracy: 1e-9)
        XCTAssertEqual(KitoMapGeometry.interpolateAngle(from: 10, to: 350, fraction: 0.5), 0, accuracy: 1e-9)
        XCTAssertEqual(KitoMapGeometry.interpolateAngle(from: 90, to: 180, fraction: 0.5), 135, accuracy: 1e-9)
        XCTAssertEqual(KitoMapGeometry.normalizedDegrees(-90), 270, accuracy: 1e-9)
        XCTAssertEqual(KitoMapGeometry.normalizedDegrees(725), 5, accuracy: 1e-9)
    }

    func testZoomRoundTrip() {
        XCTAssertEqual(KitoMapGeometry.zoom(longitudeDelta: 360, width: 256), 0, accuracy: 1e-9)
        XCTAssertEqual(KitoMapGeometry.zoom(longitudeDelta: 180, width: 256), 1, accuracy: 1e-9)
        let delta = KitoMapGeometry.longitudeDelta(zoom: 14.3, width: 390)
        XCTAssertEqual(KitoMapGeometry.zoom(longitudeDelta: delta, width: 390), 14.3, accuracy: 1e-9)
        XCTAssertEqual(KitoMapGeometry.zoom(longitudeDelta: 0, width: 390), 0)
    }

    func testRegionFittingContainsEveryPoint() throws {
        let points = [nairobi, mombasa, CLLocationCoordinate2D(latitude: -0.0917, longitude: 34.7680)]
        let region = try XCTUnwrap(KitoMapGeometry.region(fitting: points, paddingFactor: 1.2))
        for point in points {
            XCTAssertLessThanOrEqual(abs(point.latitude - region.center.latitude), region.span.latitudeDelta / 2)
            XCTAssertLessThanOrEqual(abs(point.longitude - region.center.longitude), region.span.longitudeDelta / 2)
        }
        XCTAssertEqual(region.span.longitudeDelta, (39.6682 - 34.7680) * 1.2, accuracy: 1e-9)
    }

    func testRegionFittingMinimumSpanAndEmpty() throws {
        let single = try XCTUnwrap(KitoMapGeometry.region(fitting: [nairobi], minimumSpan: 0.02))
        XCTAssertEqual(single.span.latitudeDelta, 0.02, accuracy: 1e-12)
        XCTAssertEqual(single.center.latitude, nairobi.latitude, accuracy: 1e-12)
        XCTAssertNil(KitoMapGeometry.region(fitting: []))
    }

    func testMapRectFittingKeepsPointsInsideThePaddedArea() throws {
        let size = CGSize(width: 390, height: 700)
        let padding = EdgeInsets(top: 60, leading: 40, bottom: 220, trailing: 40)
        let points = [nairobi, mombasa]
        let rect = try XCTUnwrap(KitoMapGeometry.mapRect(fitting: points, in: size, padding: padding))
        XCTAssertEqual(rect.size.width / rect.size.height, Double(size.width / size.height), accuracy: 1e-9)
        let scale = rect.size.width / Double(size.width)
        for point in points.map(MKMapPoint.init) {
            let x = (point.x - rect.origin.x) / scale, y = (point.y - rect.origin.y) / scale
            XCTAssertGreaterThanOrEqual(x, Double(padding.leading) - 0.5)
            XCTAssertLessThanOrEqual(x, Double(size.width - padding.trailing) + 0.5)
            XCTAssertGreaterThanOrEqual(y, Double(padding.top) - 0.5)
            XCTAssertLessThanOrEqual(y, Double(size.height - padding.bottom) + 0.5)
        }
        XCTAssertNil(KitoMapGeometry.mapRect(fitting: [], in: size, padding: padding))
    }

    func testCircleRingIsClosedAndOnTheRadius() {
        let ring = KitoMapGeometry.circle(center: nairobi, radius: 2_000, segments: 32)
        XCTAssertEqual(ring.count, 33)
        XCTAssertEqual(ring.first?.latitude ?? 0, ring.last?.latitude ?? 1, accuracy: 1e-9)
        for point in ring {
            XCTAssertEqual(KitoMapGeometry.distance(from: nairobi, to: point), 2_000, accuracy: 1)
        }
    }

    func testProjectionPutsNullIslandInTheMiddle() {
        let point = KitoMapGeometry.project(.init(latitude: 0, longitude: 0), worldSize: 256)
        XCTAssertEqual(Double(point.x), 128, accuracy: 1e-9)
        XCTAssertEqual(Double(point.y), 128, accuracy: 1e-9)
    }

    func testPathLength() {
        let path = [CLLocationCoordinate2D(latitude: 0, longitude: 0), .init(latitude: 1, longitude: 0), .init(latitude: 2, longitude: 0)]
        XCTAssertEqual(KitoMapGeometry.length(of: path), 2 * 111_195, accuracy: 10)
        XCTAssertEqual(KitoMapGeometry.length(of: []), 0)
    }
}
