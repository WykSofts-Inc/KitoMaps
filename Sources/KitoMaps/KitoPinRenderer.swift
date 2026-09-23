//
//  KitoPinRenderer.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UIKit
import KitoCore

/// A pin drawn into an image, with the point that sits on the coordinate.
public struct KitoPinImage {
    public let image: UIImage
    /// The anchor in unit coordinates of `image` (0,0 top-left; 0.5,1 bottom-centre).
    public let anchor: CGPoint
}

/// Draws `KitoMapPinView` and `KitoMapClusterView` into cached images, for map SDKs that take
/// marker images (Google Maps, MapLibre, snapshots).
@MainActor
public enum KitoPinRenderer {
    /// Room around the pin so badges and shadows aren't clipped.
    static let inset: CGFloat = 12
    private static let cache = NSCache<NSString, CachedImage>()

    /// The pin as an image. Selected pins are drawn larger, matching `KitoMapPinView`.
    public static func image(for pin: KitoMapPin, selected: Bool = false, theme: KitoTheme = .light,
                             colorScheme: ColorScheme = .light, avatarImage: UIImage? = nil,
                             displayScale: CGFloat = 3) -> KitoPinImage? {
        let key = [pin.id, "\(pin.style)", pin.tint.map { "\($0)" } ?? "-", pin.badge ?? "-", pin.systemImage ?? "-",
                   pin.heading.map { "\(Int($0.rounded()))" } ?? "-", selected ? "s" : "n", "\(colorScheme)",
                   avatarImage.map { "\(ObjectIdentifier($0).hashValue)" } ?? "-", "\(theme.colors.primary)", "\(displayScale)"]
            .joined(separator: "|") as NSString
        if let cached = cache.object(forKey: key) { return cached.value }
        let zoom = selected ? KitoMapPinView.selectedScale(for: pin.style) : 1
        let view = KitoMapPinView(pin: pin, isSelected: selected, avatarImage: avatarImage)
        guard let image = render(view, theme: theme, colorScheme: colorScheme, scale: displayScale, zoom: zoom) else { return nil }
        let result = KitoPinImage(image: image, anchor: anchor(pin.style.anchor, imageSize: image.size, zoom: zoom))
        cache.setObject(CachedImage(result), forKey: key)
        return result
    }

    /// A cluster bubble as an image, anchored at its centre.
    public static func clusterImage(count: Int, tint: Color? = nil, theme: KitoTheme = .light,
                                    colorScheme: ColorScheme = .light, displayScale: CGFloat = 3) -> KitoPinImage? {
        let key = "cluster|\(count)|\(tint.map { "\($0)" } ?? "-")|\(colorScheme)|\(theme.colors.primary)|\(displayScale)" as NSString
        if let cached = cache.object(forKey: key) { return cached.value }
        guard let image = render(KitoMapClusterView(count: count, tint: tint), theme: theme, colorScheme: colorScheme,
                                 scale: displayScale, zoom: 1) else { return nil }
        let result = KitoPinImage(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
        cache.setObject(CachedImage(result), forKey: key)
        return result
    }

    /// Empties the image cache.
    public static func removeAll() { cache.removeAllObjects() }

    private static func render<V: View>(_ view: V, theme: KitoTheme, colorScheme: ColorScheme, scale: CGFloat, zoom: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: view
            .padding(inset)
            .environment(\.kitoTheme, theme)
            .environment(\.colorScheme, colorScheme)
            .environment(\.kitoPinIsRendering, true))
        renderer.scale = scale * zoom
        guard let cgImage = renderer.cgImage else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    /// Converts the pin's anchor to the padded, zoomed image.
    static func anchor(_ unit: UnitPoint, imageSize: CGSize, zoom: CGFloat) -> CGPoint {
        let pad = inset * zoom
        let width = max(imageSize.width, 1), height = max(imageSize.height, 1)
        let contentWidth = max(width - 2 * pad, 0), contentHeight = max(height - 2 * pad, 0)
        return CGPoint(x: (pad + unit.x * contentWidth) / width, y: (pad + unit.y * contentHeight) / height)
    }

    private final class CachedImage {
        let value: KitoPinImage
        init(_ value: KitoPinImage) { self.value = value }
    }
}
