//
//  KitoMapFormatTests.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoMaps

final class KitoMapFormatTests: XCTestCase {
    func testMetricDistances() {
        XCTAssertEqual(KitoMapFormat.distance(0), "0 m")
        XCTAssertEqual(KitoMapFormat.distance(43), "45 m")
        XCTAssertEqual(KitoMapFormat.distance(847), "850 m")
        XCTAssertEqual(KitoMapFormat.distance(996), "1.0 km")
        XCTAssertEqual(KitoMapFormat.distance(1_240), "1.2 km")
        XCTAssertEqual(KitoMapFormat.distance(9_960), "10 km")
        XCTAssertEqual(KitoMapFormat.distance(12_400), "12 km")
        XCTAssertEqual(KitoMapFormat.distance(-5), "0 m")
    }

    func testImperialDistances() {
        XCTAssertEqual(KitoMapFormat.distance(100, units: .imperial), "330 ft")
        XCTAssertEqual(KitoMapFormat.distance(804.672, units: .imperial), "0.5 mi")
        XCTAssertEqual(KitoMapFormat.distance(19_312, units: .imperial), "12 mi")
    }

    func testDurationsRoundUpToTheMinute() {
        XCTAssertEqual(KitoMapFormat.duration(0), "1 min")
        XCTAssertEqual(KitoMapFormat.duration(61), "2 min")
        XCTAssertEqual(KitoMapFormat.duration(12 * 60), "12 min")
        XCTAssertEqual(KitoMapFormat.duration(3_600), "1 h")
        XCTAssertEqual(KitoMapFormat.duration(3_900), "1 h 5 min")
    }

    func testCountdown() {
        XCTAssertEqual(KitoMapFormat.countdown(245), "04:05")
        XCTAssertEqual(KitoMapFormat.countdown(244.2), "04:05")
        XCTAssertEqual(KitoMapFormat.countdown(3_723), "1:02:03")
        XCTAssertEqual(KitoMapFormat.countdown(-3), "00:00")
    }

    func testArrivalTime() {
        let midnight = Date(timeIntervalSince1970: 0)
        let utc = TimeZone(identifier: "UTC") ?? .current
        XCTAssertEqual(KitoMapFormat.arrivalTime(after: 750, from: midnight, locale: Locale(identifier: "en_GB"), timeZone: utc), "00:12")
        let us = KitoMapFormat.arrivalTime(after: 750, from: midnight, locale: Locale(identifier: "en_US"), timeZone: utc)
        XCTAssertTrue(us.hasPrefix("12:12"), us)
    }

    func testSummary() {
        XCTAssertEqual(KitoMapFormat.summary(distance: 1_240, duration: 720), "1.2 km · 12 min")
    }
}
