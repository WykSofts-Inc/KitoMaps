//
//  KitoMapStyle.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import MapKit

/// Apple Maps styles.
public enum KitoMapStyle: String, CaseIterable, Identifiable, KitoMapStyleOption {
    /// Roads, places and points of interest.
    case standard
    /// Quiet colours and no points of interest, so your pins stand out.
    case muted
    /// Satellite imagery.
    case imagery
    /// Satellite imagery with roads and labels.
    case hybrid

    public var id: String { rawValue }
    public static var presets: [KitoMapStyle] { allCases }

    public var title: String {
        switch self {
        case .standard: return "Standard"
        case .muted: return "Muted"
        case .imagery: return "Satellite"
        case .hybrid: return "Hybrid"
        }
    }

    public var systemImage: String {
        switch self {
        case .standard: return "map"
        case .muted: return "map.circle"
        case .imagery: return "globe.europe.africa.fill"
        case .hybrid: return "square.2.layers.3d"
        }
    }

    /// The MapKit style, with realistic elevation in 3D.
    public func mapStyle(in3D: Bool = false) -> MapStyle {
        let elevation: MapStyle.Elevation = in3D ? .realistic : .automatic
        switch self {
        case .standard: return .standard(elevation: elevation, pointsOfInterest: .all)
        case .muted: return .standard(elevation: elevation, emphasis: .muted, pointsOfInterest: .excludingAll)
        case .imagery: return .imagery(elevation: elevation)
        case .hybrid: return .hybrid(elevation: elevation)
        }
    }
}
