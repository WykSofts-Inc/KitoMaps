//
//  KitoMapCardCarousel.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Swipeable cards along the bottom of a map, one per pin, synced both ways with the selection:
/// tapping a pin scrolls to its card, swiping to a card selects its pin.
///
/// Map views show it for you when you pass a `card` builder; use it directly for custom layouts.
public struct KitoMapCardCarousel<Card: View>: View {
    let pins: [KitoMapPin]
    @Binding var selection: String?
    let card: (KitoMapPin) -> Card
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(pins: [KitoMapPin], selection: Binding<String?>, @ViewBuilder card: @escaping (KitoMapPin) -> Card) {
        self.pins = pins
        self._selection = selection
        self.card = card
    }

    public var body: some View {
        let reduceMotion = reduceMotion
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: theme.spacing.md) {
                ForEach(pins) { pin in
                    card(pin)
                        .containerRelativeFrame(.horizontal) { width, _ in max(width - 2 * theme.spacing.xxl - theme.spacing.md, 200) }
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(reduceMotion || phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.75)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.snappy) { selection = pin.id } }
                        .accessibilityAddTraits(selection == pin.id ? .isSelected : [])
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, theme.spacing.xxl + theme.spacing.xs, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selection, anchor: .center)
        .scrollClipDisabled()
    }
}

/// A ready-made card for a pin: artwork, title, subtitle, badge and price.
public struct KitoMapPinCard: View {
    let pin: KitoMapPin
    var detail: String?
    @Environment(\.kitoTheme) private var theme

    /// `detail` is an extra line such as "Open until 22:00" or "1.2 km · 12 min".
    public init(pin: KitoMapPin, detail: String? = nil) {
        self.pin = pin
        self.detail = detail
    }

    public var body: some View {
        let tint = pin.tint ?? theme.colors.primary
        HStack(spacing: theme.spacing.md) {
            artwork(tint)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pin.title).font(theme.typography.bodyEmphasized).foregroundStyle(theme.colors.onSurface).lineLimit(1)
                    Spacer(minLength: theme.spacing.xs)
                    if let badge = pin.badge {
                        // A decimal badge reads as a rating; anything else as plain text.
                        let isRating = badge.contains(".") && Double(badge) != nil
                        Label(badge, systemImage: isRating ? "star.fill" : "tag.fill")
                            .labelStyle(.titleAndIcon)
                            .font(theme.typography.caption.weight(.semibold))
                            .foregroundStyle(theme.colors.onSurface)
                    }
                }
                if let subtitle = pin.subtitle {
                    Text(subtitle).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.6)).lineLimit(1)
                }
                HStack {
                    if let detail {
                        Text(detail).font(theme.typography.caption).foregroundStyle(tint).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let price = pin.priceText {
                        Text(price).font(theme.typography.bodyEmphasized).monospacedDigit().foregroundStyle(theme.colors.onSurface)
                    }
                }
            }
        }
        .padding(theme.spacing.md)
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).stroke(theme.colors.border.opacity(0.5), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
        .accessibilityElement(children: .combine)
    }

    private func artwork(_ tint: Color) -> some View {
        RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 64, height: 64)
            .overlay {
                if let initials = pin.initials {
                    Text(initials.prefix(2).uppercased()).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                } else {
                    Image(systemName: pin.systemImage ?? symbol).font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                }
            }
            .accessibilityHidden(true)
    }

    private var symbol: String {
        if case .icon(let name) = pin.style { return name }
        return "mappin.and.ellipse"
    }
}
