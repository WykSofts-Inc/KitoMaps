// swift-tools-version: 5.9
//
//  Package.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "KitoMaps",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoMaps", targets: ["KitoMaps"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoCore.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "KitoMaps", dependencies: [.product(name: "KitoCore", package: "KitoCore")]),
        .testTarget(name: "KitoMapsTests", dependencies: ["KitoMaps"]),
    ]
)
