//
//  KitoMapPinView.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UIKit
import KitoCore

/// The SwiftUI drawing of a pin. Selected pins grow with a spring; `.pulse` pins breathe.
/// Google Maps and MapLibre render this same view into marker images.
public struct KitoMapPinView: View {
    public let pin: KitoMapPin
    public var isSelected: Bool
    /// A preloaded photo for `.avatar` pins, used instead of downloading `imageURL`.
    public var avatarImage: UIImage?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.kitoPinIsRendering) private var isRendering
    @State private var pulsing = false

    public init(pin: KitoMapPin, isSelected: Bool = false, avatarImage: UIImage? = nil) {
        self.pin = pin
        self.isSelected = isSelected
        self.avatarImage = avatarImage
    }

    /// How much a selected pin grows.
    public static func selectedScale(for style: KitoMapPinStyle) -> CGFloat {
        switch style {
        case .dot: return 1.5
        case .icon: return 1.28
        case .bubble: return 1.12
        case .avatar: return 1.22
        case .teardrop: return 1.25
        case .pulse: return 1.15
        }
    }

    private var tint: Color { pin.tint ?? theme.colors.primary }
    /// Glyphs and initials sit on tinted fills, so they stay white in both modes.
    private let ink = Color.white
    private var ring: Color { theme.colors.surface }

    public var body: some View {
        let scale = isRendering || !isSelected ? 1 : Self.selectedScale(for: pin.style)
        shape
            .overlay(alignment: .topTrailing) { badge }
            .scaleEffect(scale, anchor: pin.style.anchor)
            .offset(y: isSelected && !isRendering && pin.style == .teardrop ? -6 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.5), value: isSelected)
    }

    @ViewBuilder private var shape: some View {
        switch pin.style {
        case .dot: dot
        case .icon(let symbol): icon(symbol)
        case .bubble(let text): bubble(text)
        case .avatar(let initials, let url): avatar(initials, url: url)
        case .teardrop: teardrop
        case .pulse: pulse
        }
    }

    // MARK: Styles

    private var dot: some View {
        Circle()
            .fill(tint)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(ring, lineWidth: 3))
            .background(Circle().fill(tint.opacity(isSelected ? 0.28 : 0)).frame(width: 30, height: 30))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .frame(width: 30, height: 30)
    }

    private func icon(_ symbol: String) -> some View {
        Circle()
            .fill(tint.gradient)
            .frame(width: 36, height: 36)
            .overlay(Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(ink))
            .overlay(Circle().stroke(ring, lineWidth: isSelected ? 3 : 2.5))
            .shadow(color: .black.opacity(isSelected ? 0.32 : 0.22), radius: isSelected ? 7 : 4, y: isSelected ? 4 : 2)
            .padding(2)
    }

    private func bubble(_ text: String) -> some View {
        let fill = isSelected ? (pin.tint ?? theme.colors.onSurface) : theme.colors.surface
        let label = isSelected ? theme.colors.surface : theme.colors.onSurface
        return VStack(spacing: -1) {
            HStack(spacing: 4) {
                if let symbol = pin.systemImage {
                    Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                }
                Text(text).font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1)
            }
            .foregroundStyle(label)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(theme.colors.border.opacity(isSelected ? 0 : 1), lineWidth: 1))
            KitoPinTail().fill(fill).frame(width: 12, height: 6)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(isSelected ? 0.3 : 0.18), radius: isSelected ? 8 : 4, y: isSelected ? 4 : 2)
    }

    private func avatar(_ initials: String, url: URL?) -> some View {
        VStack(spacing: -2) {
            ZStack {
                Circle().fill(tint.gradient)
                Text(initials.prefix(2).uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                if let avatarImage {
                    Image(uiImage: avatarImage).resizable().scaledToFill()
                } else if let url, !isRendering {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill().transition(.opacity) }
                    }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(Circle().stroke(isSelected ? tint : ring, lineWidth: 3))
            KitoPinTail().fill(isSelected ? tint : ring).frame(width: 10, height: 6)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(isSelected ? 0.32 : 0.22), radius: isSelected ? 8 : 4, y: 3)
    }

    private var teardrop: some View {
        KitoTeardropShape()
            .fill(tint.gradient)
            .overlay(KitoTeardropShape().stroke(ring, lineWidth: 2))
            .frame(width: 32, height: 42)
            .overlay(alignment: .top) {
                Circle()
                    .fill(ink)
                    .frame(width: 18, height: 18)
                    .overlay {
                        if let symbol = pin.systemImage {
                            Image(systemName: symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
                        } else {
                            Circle().fill(tint).frame(width: 7, height: 7)
                        }
                    }
                    .padding(.top, 7)
            }
            .shadow(color: .black.opacity(isSelected ? 0.3 : 0.2), radius: isSelected ? 8 : 3, y: isSelected ? 8 : 2)
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(.black.opacity(isSelected ? 0.14 : 0.22))
                    .frame(width: isSelected ? 10 : 14, height: 4)
                    .offset(y: 2)
                    .blur(radius: 1)
            }
    }

    private var pulse: some View {
        let animates = !isRendering && !reduceMotion
        let core: CGFloat = pin.systemImage == nil ? 18 : 34
        return ZStack {
            if let heading = pin.heading {
                KitoHeadingCone()
                    .fill(RadialGradient(colors: [tint.opacity(0.6), tint.opacity(0)], center: .center,
                                         startRadius: core * 0.3, endRadius: core * 1.2))
                    .frame(width: core * 2.4, height: core * 2.4)
                    .rotationEffect(.degrees(heading))
                    // Compass headings are physical; rotation would run backwards in right-to-left layouts.
                    .environment(\.layoutDirection, .leftToRight)
            }
            Circle()
                .fill(tint.opacity(animates ? (pulsing ? 0 : 0.35) : 0.18))
                .frame(width: core, height: core)
                .scaleEffect(animates ? (pulsing ? 2.8 : 1) : 2)
            Circle()
                .fill(tint)
                .frame(width: core, height: core)
                .overlay {
                    if let symbol = pin.systemImage {
                        Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                    }
                }
                .overlay(Circle().stroke(ring, lineWidth: 3))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .frame(width: core * 2.4, height: core * 2.4)
        .onAppear {
            guard animates else { return }
            withAnimation(.easeOut(duration: 1.7).repeatForever(autoreverses: false)) { pulsing = true }
        }
    }

    @ViewBuilder private var badge: some View {
        if let badge = pin.badge {
            Text(badge)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(theme.colors.danger))
                .overlay(Capsule().stroke(ring, lineWidth: 1.5))
                .fixedSize()
                .offset(x: 8, y: -6)
        }
    }
}

/// The count bubble for a cluster. Bigger clusters are bigger; the number rolls as it changes.
public struct KitoMapClusterView: View {
    public let count: Int
    public var tint: Color?
    @Environment(\.kitoTheme) private var theme

    public init(count: Int, tint: Color? = nil) {
        self.count = count
        self.tint = tint
    }

    public var body: some View {
        let color = tint ?? theme.colors.primary
        let size = 34 + min(log2(Double(max(count, 1))) * 6, 26)
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: size > 50 ? 16 : 14, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(count)))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color.gradient))
            .overlay(Circle().stroke(theme.colors.surface, lineWidth: 3))
            .background(Circle().fill(color.opacity(0.22)).frame(width: size + 14, height: size + 14))
            .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
            .padding(7)
            .animation(.snappy, value: count)
    }
}

// MARK: - Shapes

/// A classic map pin: a circle tapering to a point at the bottom.
struct KitoTeardropShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.minY + r)
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        // The tangent points from the tip sit ±θ either side of straight down, where cos θ = r / d.
        let theta = acos(min(r / max(tip.y - center.y, r), 1))
        var path = Path()
        path.move(to: tip)
        path.addArc(center: center, radius: r, startAngle: .radians(.pi / 2 + theta),
                    endAngle: .radians(.pi / 2 - theta), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// The small triangle under bubbles and avatars.
struct KitoPinTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.minY + rect.height * 0.35))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.minY + rect.height * 0.35))
        return path
    }
}

/// A wedge from the centre pointing up, rotated to show a heading.
struct KitoHeadingCone: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: origin)
        path.addArc(center: origin, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(-90 - 30),
                    endAngle: .degrees(-90 + 30), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Rendering flag

private struct KitoPinIsRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set while a pin is drawn into an image: no animation, no downloads, no selection scale.
    var kitoPinIsRendering: Bool {
        get { self[KitoPinIsRenderingKey.self] }
        set { self[KitoPinIsRenderingKey.self] = newValue }
    }
}
