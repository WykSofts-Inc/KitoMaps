//
//  KitoMapChrome.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import CoreLocation
import KitoCore

/// A round floating map button, like the ones in the corner of every Kito map.
public struct KitoMapControlButton: View {
    let systemImage: String
    let label: String
    var isActive: Bool
    let action: () -> Void
    @Environment(\.kitoTheme) private var theme

    public init(systemImage: String, label: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            KitoMapControlGlyph(systemImage: systemImage, isActive: isActive)
        }
        .buttonStyle(KitoMapPressStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

struct KitoMapControlGlyph: View {
    let systemImage: String
    var isActive = false
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isActive ? theme.colors.primary : theme.colors.onSurface)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 44, height: 44)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().stroke(theme.colors.border.opacity(0.6), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
    }
}

/// A button style that shrinks slightly while pressed.
struct KitoMapPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// The column of floating buttons every provider shows. Shared so all maps look the same.
@_spi(KitoMapsProvider)
public struct KitoMapControlStack<Style: KitoMapStyleOption>: View {
    let controls: KitoMapControls
    @Binding var style: Style
    @Binding var is3D: Bool
    let onLocate: () -> Void
    let onFit: () -> Void
    @Environment(\.kitoTheme) private var theme

    public init(controls: KitoMapControls, style: Binding<Style>, is3D: Binding<Bool>,
                onLocate: @escaping () -> Void, onFit: @escaping () -> Void) {
        self.controls = controls
        self._style = style
        self._is3D = is3D
        self.onLocate = onLocate
        self.onFit = onFit
    }

    public var body: some View {
        VStack(spacing: theme.spacing.sm) {
            if controls.contains(.styleSwitcher) {
                Menu {
                    Picker("Map style", selection: $style) {
                        ForEach(Style.presets, id: \.self) { option in
                            Label(option.title, systemImage: option.systemImage).tag(option)
                        }
                    }
                } label: {
                    KitoMapControlGlyph(systemImage: "square.3.layers.3d")
                }
                .accessibilityLabel("Map style, \(style.title)")
            }
            if controls.contains(.pitch) {
                KitoMapControlButton(systemImage: is3D ? "view.3d" : "view.2d", label: is3D ? "Show in 2D" : "Show in 3D", isActive: is3D) {
                    is3D.toggle()
                }
            }
            if controls.contains(.fitAll) {
                KitoMapControlButton(systemImage: "scope", label: "Show all places", action: onFit)
            }
            if controls.contains(.userLocation) {
                KitoMapControlButton(systemImage: "location.fill", label: "Show my location", action: onLocate)
            }
        }
        .padding(theme.spacing.md)
    }
}

/// Asks for when-in-use location permission and reports the latest fix.
@_spi(KitoMapsProvider)
@MainActor
@Observable
public final class KitoLocationProvider: NSObject {
    public private(set) var location: CLLocation?
    public private(set) var authorization: CLAuthorizationStatus
    private let manager = CLLocationManager()
    private var pending: [(CLLocation?) -> Void] = []

    public override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    public var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }

    /// Requests permission if needed, then calls back with a location (or `nil` if denied).
    public func locate(_ completion: @escaping (CLLocation?) -> Void) {
        if let location, isAuthorized { completion(location); return }
        pending.append(completion)
        switch authorization {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: flush(nil)
        }
    }

    private func flush(_ location: CLLocation?) {
        let callbacks = pending
        pending.removeAll()
        callbacks.forEach { $0(location) }
    }
}

extension KitoLocationProvider: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        switch authorization {
        case .authorizedAlways, .authorizedWhenInUse: if !pending.isEmpty { manager.requestLocation() }
        case .notDetermined: break
        default: flush(nil)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last ?? location
        flush(location)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        flush(location)
    }
}

/// Makes a pin fly out from the cluster it split from and pop in with a spring.
struct KitoPopIn: ViewModifier {
    let from: CGSize
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    func body(content: Content) -> some View {
        content
            .offset(settled || reduceMotion ? .zero : from)
            .scaleEffect(settled ? 1 : (reduceMotion ? 1 : 0.4))
            .opacity(settled ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.62).delay(delay)) {
                    settled = true
                }
            }
    }
}
