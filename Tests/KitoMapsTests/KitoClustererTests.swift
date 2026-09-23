//
//  KitoClustererTests.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import CoreLocation
@_spi(KitoMapsProvider) @testable import KitoMaps

final class KitoClustererTests: XCTestCase {
    private func pin(_ id: String, _ lat: Double, _ lon: Double) -> KitoMapPin {
        KitoMapPin(id: id, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), title: id)
    }

    /// Three cafés within a few hundred metres in Westlands, and one at the coast.
    private lazy var pins = [
        pin("java", -1.2635, 36.8030),
        pin("artcaffe", -1.2641, 36.8045),
        pin("connect", -1.2629, 36.8021),
        pin("diani", -4.2797, 39.5947),
    ]

    func testNearbyPinsMergeWhenZoomedOut() {
        let clusters = KitoClusterer().clusters(for: pins, zoom: 8)
        XCTAssertEqual(clusters.count, 2)
        let westlands = clusters.first { $0.isCluster }
        XCTAssertEqual(westlands?.count, 3)
        XCTAssertEqual(westlands?.id, "cluster:artcaffe")
        XCTAssertEqual(clusters.first { !$0.isCluster }?.pin?.id, "diani")
    }

    func testPinsSplitWhenZoomedIn() {
        let clusters = KitoClusterer().clusters(for: pins, zoom: 19)
        XCTAssertEqual(clusters.count, 4)
        XCTAssertTrue(clusters.allSatisfy { !$0.isCluster })
    }

    func testMaximumZoomDisablesClustering() {
        let clusters = KitoClusterer(maximumZoom: 6).clusters(for: pins, zoom: 7)
        XCTAssertEqual(clusters.count, 4)
    }

    func testResultIsDeterministicRegardlessOfInputOrder() {
        let clusterer = KitoClusterer()
        let a = clusterer.clusters(for: pins, zoom: 8)
        let b = clusterer.clusters(for: pins.reversed(), zoom: 8)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.map(\.id), a.map(\.id).sorted())
    }

    func testFractionalZoomIsFloored() {
        let clusterer = KitoClusterer()
        XCTAssertEqual(clusterer.clusters(for: pins, zoom: 8.1), clusterer.clusters(for: pins, zoom: 8.9))
    }

    func testExcludedPinStaysSingle() {
        let clusters = KitoClusterer().clusters(for: pins, zoom: 8, excluding: "java")
        XCTAssertNotNil(clusters.first { $0.pin?.id == "java" })
        XCTAssertEqual(clusters.first { $0.isCluster }?.count, 2)
    }

    func testMinimumClusterSize() {
        let clusters = KitoClusterer(minimumClusterSize: 4).clusters(for: pins, zoom: 8)
        XCTAssertEqual(clusters.count, 4)
    }

    func testClusterCoordinateIsTheMeanOfItsMembers() {
        let cluster = KitoMapCluster(pins: [pin("a", 0, 0), pin("b", 2, 4)])
        XCTAssertEqual(cluster.coordinate.latitude, 1, accuracy: 1e-9)
        XCTAssertEqual(cluster.coordinate.longitude, 2, accuracy: 1e-9)
        XCTAssertNil(cluster.pin)
    }

    func testSplitOriginsPointBackAtTheParentCluster() {
        let clusterer = KitoClusterer()
        let before = clusterer.clusters(for: pins, zoom: 8)
        let after = clusterer.clusters(for: pins, zoom: 19)
        let origins = KitoClusterer.splitOrigins(from: before, to: after)
        let parent = before.first { $0.isCluster }
        XCTAssertEqual(Set(origins.keys), ["java", "artcaffe", "connect"])
        XCTAssertEqual(origins["java"]?.latitude ?? 0, parent?.coordinate.latitude ?? 1, accuracy: 1e-9)
        XCTAssertNil(origins["diani"])
    }

    func testDiffTracksSplitsAndMerges() {
        let clusterer = KitoClusterer()
        let zoomedOut = clusterer.clusters(for: pins, zoom: 8)
        let zoomedIn = clusterer.clusters(for: pins, zoom: 19)

        let split = KitoClusterDiff(from: zoomedOut, to: zoomedIn)
        XCTAssertEqual(split.removed.map(\.id), ["cluster:artcaffe"])
        XCTAssertEqual(Set(split.inserted.map(\.id)), ["artcaffe", "connect", "java"])
        XCTAssertEqual(split.kept.map(\.id), ["diani"])
        XCTAssertEqual(split.origins.count, 3)

        let merge = KitoClusterDiff(from: zoomedIn, to: zoomedOut)
        XCTAssertEqual(Set(merge.mergeTargets.keys), ["artcaffe", "connect", "java"])
        XCTAssertTrue(merge.origins.isEmpty)
    }

    func testVisualKeyChangesWithSelectionAndCount() {
        let single = KitoMapCluster(pins: [pins[0]])
        XCTAssertNotEqual(single.visualKey(selected: true), single.visualKey(selected: false))
        let two = KitoMapCluster(pins: Array(pins.prefix(2)))
        let three = KitoMapCluster(pins: Array(pins.prefix(3)))
        XCTAssertNotEqual(two.visualKey(selected: false), three.visualKey(selected: false))
    }

    func testEmptyInput() {
        XCTAssertTrue(KitoClusterer().clusters(for: [], zoom: 10).isEmpty)
    }
}
