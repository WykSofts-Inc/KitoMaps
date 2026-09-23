//
//  KitoMapPin.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import CoreLocation

/// A place on the map. The same pin renders on Apple Maps, Google Maps and MapLibre.
///
/// ```swift
/// KitoMapPin(id: "java", coordinate: .init(latitude: -1.2890, longitude: 36.7820),
///            title: "Java House", subtitle: "Coffee · 0.8 km", style: .bubble("KSh 650"))
/// ```
public struct KitoMapPin: Identifiable, Equatable, Sendable {
    public var id: String
    public var coordinate: CLLocationCoordinate2D
    public var title: String
    public var subtitle: String?
    public var style: KitoMapPinStyle
    /// The pin's accent. `nil` uses the theme's primary colour.
    public var tint: Color?
    /// A small label on the pin's corner, e.g. `"4.8"` or `"2"`.
    public var badge: String?
    /// A glyph for `.teardrop`, `.pulse` and the default card. `.icon` carries its own.
    public var systemImage: String?
    /// Direction of travel in degrees (0 = north). Drawn as a heading cone on `.pulse` pins.
    public var heading: Double?

    public init(
        id: String,
        coordinate: CLLocationCoordinate2D,
        title: String,
        subtitle: String? = nil,
        style: KitoMapPinStyle = .teardrop,
        tint: Color? = nil,
        badge: String? = nil,
        systemImage: String? = nil,
        heading: Double? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.tint = tint
        self.badge = badge
        self.systemImage = systemImage
        self.heading = heading
    }

    /// The price text of a `.bubble` pin.
    public var priceText: String? {
        if case .bubble(let text) = style { return text }
        return nil
    }

    /// The initials of an `.avatar` pin.
    public var initials: String? {
        if case .avatar(let initials, _) = style { return initials }
        return nil
    }

    /// What VoiceOver reads for the pin.
    public var accessibilityText: String {
        [title, priceText, subtitle, badge.map { "Badge \($0)" }].compactMap { $0 }.joined(separator: ", ")
    }

    public static func == (lhs: KitoMapPin, rhs: KitoMapPin) -> Bool {
        lhs.id == rhs.id && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle && lhs.style == rhs.style && lhs.tint == rhs.tint
            && lhs.badge == rhs.badge && lhs.systemImage == rhs.systemImage && lhs.heading == rhs.heading
    }
}

/// How a pin looks.
public enum KitoMapPinStyle: Hashable, Sendable {
    /// A small dot with a white ring.
    case dot
    /// A round badge with an SF Symbol.
    case icon(String)
    /// A capsule with text and a tail, like a price on a stays map.
    case bubble(String)
    /// A round photo or initials with a pointer.
    case avatar(initials: String, imageURL: URL? = nil)
    /// The classic map pin, with the pin's `systemImage` inside.
    case teardrop
    /// A live-location dot with a pulsing halo, for couriers and the user.
    case pulse

    /// The point of the pin that sits on the coordinate, in unit coordinates.
    public var anchor: UnitPoint {
        switch self {
        case .bubble, .avatar, .teardrop: return .bottom
        case .dot, .icon, .pulse: return .center
        }
    }
}
