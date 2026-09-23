//
//  KitoMapScaffold.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// The chrome around a provider's map — floating controls and the card carousel — so Google
/// Maps and MapLibre look and behave exactly like `KitoMapView`.
@_spi(KitoMapsProvider)
public struct KitoMapScaffold<Style: KitoMapStyleOption, Map: View, Card: View>: View {
    let pins: [KitoMapPin]
    @Binding var selection: String?
    let options: KitoMapOptions
    @Binding var style: Style
    @Binding var is3D: Bool
    @Binding var bottomInset: CGFloat
    let controller: KitoMapController
    let showsControls: Bool
    let card: ((KitoMapPin) -> Card)?
    let map: () -> Map
    @Environment(\.kitoTheme) private var theme

    public init(pins: [KitoMapPin], selection: Binding<String?>, options: KitoMapOptions, style: Binding<Style>,
                is3D: Binding<Bool>, bottomInset: Binding<CGFloat>, controller: KitoMapController, showsControls: Bool = true,
                card: ((KitoMapPin) -> Card)?, @ViewBuilder map: @escaping () -> Map) {
        self.pins = pins
        self._selection = selection
        self.options = options
        self._style = style
        self._is3D = is3D
        self._bottomInset = bottomInset
        self.controller = controller
        self.showsControls = showsControls
        self.card = card
        self.map = map
    }

    public var body: some View {
        map()
            .overlay(alignment: .topTrailing) {
                if showsControls, !options.controls.isEmpty {
                    KitoMapControlStack(controls: options.controls, style: $style, is3D: $is3D,
                                        onLocate: { controller.move(to: .userLocation(zoom: 15)) },
                                        onFit: { controller.move(to: .fitPins) })
                }
            }
            .overlay(alignment: .bottom) {
                if let card {
                    KitoMapCardCarousel(pins: pins, selection: $selection, card: card)
                        .padding(.bottom, theme.spacing.lg)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomInset = $0 + theme.spacing.lg }
                }
            }
    }
}
