# ``KitoMaps``

Apple Maps for SwiftUI with animated pins, clustering, card carousels, routes, live tracking and place search.

## Overview

KitoMaps builds on MapKit to give maps pins that feel alive: price bubbles, avatars and live
couriers that spring when tapped, clusters that split apart as you zoom, and a card carousel that
stays in sync with the selected pin. ``KitoMapView`` takes an array of ``KitoMapPin`` values, an
optional selection binding and an optional card builder.

```swift
let places = [
    KitoMapPin(id: "java", coordinate: .init(latitude: -1.2635, longitude: 36.8030),
               title: "Java House", subtitle: "Coffee · Westlands", style: .bubble("KSh 650"), badge: "4.6"),
    KitoMapPin(id: "carnivore", coordinate: .init(latitude: -1.3281, longitude: 36.8054),
               title: "Carnivore", subtitle: "Nyama choma", style: .icon("fork.knife"), tint: .orange),
]

@State private var selected: String?

KitoMapView(pins: places, selection: $selected) { pin in
    KitoMapPinCard(pin: pin, detail: "Open until 23:00")
}
.clustering()
.controls(.all)
```

Configuration methods such as `clustering(_:cellSize:)`, `overlays(_:)` and `controls(_:)` come
from ``KitoMapConfigurable``, so they work the same on every provider. ``KitoMapController``
moves the camera from outside the map, and ``KitoMapStyle`` switches between standard, muted,
imagery and hybrid styles.

``KitoRouteService`` fetches Apple Maps directions as a ``KitoMapRoute``, which you can draw with a
``KitoMapOverlay`` alongside trails and geofence circles. ``KitoLiveTracker`` moves a courier pin
along a route for delivery tracking. ``KitoPlaceSearchField``, ``KitoLocationPicker`` and
``KitoMapSnapshot`` cover search, pick-a-location and static map previews.

The same pins, options and modifiers also drive Google Maps through KitoMapsGoogle and
OpenStreetMap tiles through KitoMapsLibre. Add `NSLocationWhenInUseUsageDescription` to your
Info.plist if you show the user's location.

## Topics

### Essentials

- ``KitoMapView``
- ``KitoMapPin``
- ``KitoMapPinStyle``
- ``KitoMapPinCard``
- ``KitoMapCardCarousel``

### Camera and Options

- ``KitoMapController``
- ``KitoMapCamera``
- ``KitoMapConfigurable``
- ``KitoMapOptions``
- ``KitoMapControls``
- ``KitoMapStyle``
- ``KitoMapStyleOption``

### Pins and Clusters

- ``KitoMapPinView``
- ``KitoMapClusterView``
- ``KitoClusterer``
- ``KitoMapCluster``
- ``KitoPinRenderer``
- ``KitoPinImage``

### Routes and Tracking

- ``KitoRouteService``
- ``KitoMapRoute``
- ``KitoTransport``
- ``KitoMapOverlay``
- ``KitoPolyline``
- ``KitoLiveTracker``
- ``KitoRoutePath``

### Search, Picking and Snapshots

- ``KitoPlaceSearchField``
- ``KitoPlace``
- ``KitoLocationPicker``
- ``KitoPickedLocation``
- ``KitoMapSnapshot``
- ``KitoMapSnapshotter``

### Helpers

- ``KitoMapControlButton``
- ``KitoMapGeometry``
- ``KitoMapFormat``
