//
//  KitoPlaceSearchField.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import MapKit
import KitoCore

/// A place picked from search.
public struct KitoPlace: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var address: String
    public var coordinate: CLLocationCoordinate2D

    public init(id: String = UUID().uuidString, name: String, address: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
    }

    /// A teardrop pin for this place.
    public func pin(style: KitoMapPinStyle = .teardrop, tint: Color? = nil) -> KitoMapPin {
        KitoMapPin(id: id, coordinate: coordinate, title: name, subtitle: address, style: style, tint: tint)
    }

    public static func == (lhs: KitoPlace, rhs: KitoPlace) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.address == rhs.address
            && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

/// A search field with live Apple Maps suggestions. Matching text is bold; picking a suggestion
/// looks up its coordinate.
///
/// ```swift
/// KitoPlaceSearchField(near: nairobi) { place in
///     pins.append(place.pin())
/// }
/// ```
public struct KitoPlaceSearchField: View {
    let placeholder: String
    let region: MKCoordinateRegion?
    let onSelect: (KitoPlace) -> Void

    @State private var model = KitoPlaceSearchModel()
    @FocusState private var isFocused: Bool
    @Environment(\.kitoTheme) private var theme

    /// - Parameters:
    ///   - placeholder: The prompt.
    ///   - region: Suggestions near here come first.
    ///   - onSelect: Called with the chosen place.
    public init(_ placeholder: String = "Search places", near region: MKCoordinateRegion? = nil,
                onSelect: @escaping (KitoPlace) -> Void) {
        self.placeholder = placeholder
        self.region = region
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: theme.spacing.sm) {
            field
            if isFocused, !model.query.isEmpty, !model.suggestions.isEmpty {
                suggestions.transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: model.suggestions.map(\.id))
        .animation(.snappy, value: isFocused)
        .onAppear { model.region = region }
    }

    private var field: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(theme.colors.onSurface.opacity(0.5))
            TextField(placeholder, text: $model.query)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.onSurface)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { if let first = model.suggestions.first { pick(first) } }
            if model.isResolving {
                ProgressView().controlSize(.small)
            } else if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(theme.colors.onSurface.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .frame(height: 50)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(isFocused ? theme.colors.primary.opacity(0.6) : theme.colors.border.opacity(0.6), lineWidth: isFocused ? 1.5 : 0.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private var suggestions: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.suggestions.prefix(6).enumerated()), id: \.element.id) { index, suggestion in
                Button { pick(suggestion) } label: {
                    HStack(spacing: theme.spacing.md) {
                        Image(systemName: suggestion.subtitle.isEmpty ? "magnifyingglass" : "mappin.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(theme.colors.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.highlightedTitle).font(theme.typography.body).foregroundStyle(theme.colors.onSurface)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle).font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.onSurface.opacity(0.6)).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.left").font(.caption.weight(.semibold)).foregroundStyle(theme.colors.onSurface.opacity(0.3))
                    }
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical, theme.spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < min(model.suggestions.count, 6) - 1 {
                    Divider().padding(.leading, theme.spacing.lg + 34)
                }
            }
        }
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).stroke(theme.colors.border.opacity(0.5), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }

    private func pick(_ suggestion: KitoPlaceSuggestion) {
        Task {
            if let place = await model.resolve(suggestion) {
                isFocused = false
                model.query = place.name
                model.suggestions = []
                onSelect(place)
            }
        }
    }
}

/// One suggestion from the completer.
struct KitoPlaceSuggestion: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let highlightedTitle: AttributedString
    let completion: MKLocalSearchCompletion
}

@MainActor
@Observable
final class KitoPlaceSearchModel: NSObject {
    var query = "" {
        didSet {
            if query.isEmpty { suggestions = [] } else { completer.queryFragment = query }
        }
    }
    var suggestions: [KitoPlaceSuggestion] = []
    var isResolving = false
    var region: MKCoordinateRegion? {
        didSet { if let region { completer.region = region } }
    }

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func resolve(_ suggestion: KitoPlaceSuggestion) async -> KitoPlace? {
        isResolving = true
        defer { isResolving = false }
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: suggestion.completion))
        guard let item = try? await search.start().mapItems.first else { return nil }
        let coordinate = item.placemark.coordinate
        return KitoPlace(id: "\(suggestion.title)|\(suggestion.subtitle)", name: item.name ?? suggestion.title,
                         address: suggestion.subtitle, coordinate: coordinate)
    }

    fileprivate func update(_ results: [MKLocalSearchCompletion]) {
        suggestions = results.map { result in
            var title = AttributedString(result.title)
            for value in result.titleHighlightRanges {
                let range = value.rangeValue
                guard let swiftRange = Range(range, in: result.title),
                      let lower = AttributedString.Index(swiftRange.lowerBound, within: title),
                      let upper = AttributedString.Index(swiftRange.upperBound, within: title) else { continue }
                title[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
            }
            return KitoPlaceSuggestion(id: result.title + "|" + result.subtitle, title: result.title, subtitle: result.subtitle,
                                       highlightedTitle: title, completion: result)
        }
    }
}

extension KitoPlaceSearchModel: @preconcurrency MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        update(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
