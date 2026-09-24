# KitoMaps

**[Documentation](https://wyksofts-inc.github.io/KitoMaps/documentation/kitomaps/)**

Maps for SwiftUI with pins that feel alive: price bubbles, avatars and live couriers that spring
when tapped, clusters that split apart as you zoom, a card carousel synced with the selected pin,
routes, geofences, place search and a delivery-style location picker. Built on Apple Maps, with the
same API on Google Maps ([KitoMapsGoogle](https://github.com/WykSofts-Inc/KitoMapsGoogle)) and free
OpenStreetMap tiles ([KitoMapsLibre](https://github.com/WykSofts-Inc/KitoMapsLibre)). Part of the
[Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem.

## A map with cards

```swift
import KitoMaps

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
.controls(.all)        // user location, style switcher, 3D, fit all
```

Tap a pin and its card scrolls into view; swipe the cards and the map follows. Leave out the card
builder for a plain map.

## Pins

| Style | Looks like |
|---|---|
| `.dot` | A small dot with a white ring |
| `.icon("cup.and.saucer.fill")` | A round badge with a symbol |
| `.bubble("KSh 4,500")` | A price bubble with a tail — fills in when selected |
| `.avatar(initials: "WN", imageURL: url)` | A photo or initials with a pointer |
| `.teardrop` | The classic pin, with `systemImage` inside; lifts when selected |
| `.pulse` | A live dot with a breathing halo and a heading cone (`heading:`) |

Every pin takes a `tint`, a corner `badge` and a `systemImage`. Selected pins grow with a spring,
pins pop in when they appear, and Reduce Motion swaps the springs for fades. Each pin is an
accessibility element labelled with its title, price and subtitle.

`KitoMapPinView(pin:isSelected:)` and `KitoMapClusterView(count:)` are the views themselves, for
lists and legends.

## Clusters

```swift
KitoMapView(pins: hundredsOfStays).clustering(cellSize: 72)
```

Nearby pins merge into a count bubble and fly apart as you zoom in; tap a cluster to zoom into it.
The selected pin never hides inside a cluster. `KitoClusterer` is the pure, deterministic grid behind
it if you need clusters elsewhere.

## Routes, trails and geofences

```swift
let route = try await KitoRouteService.route(from: shop, to: home)   // Apple Maps directions
Text("\(route.formattedDistance) · \(route.formattedTravelTime)")      // "4.2 km · 12 min"

KitoMapView(pins: [shopPin, homePin])
    .overlays([
        .route(route, color: .blue),
        .polyline(walkingPath, id: "walk", color: .green, dashed: true),
        .circle(center: store, radius: 2_000, color: .orange),        // delivery zone
    ])
```

`KitoPolyline.decode(_:)` turns Google/OSRM encoded polylines into coordinates.

## Live delivery tracking

```swift
@State private var rider = KitoLiveTracker(route: route.coordinates, duration: 90)

KitoMapView(pins: [shopPin, homePin, rider.pin])
    .overlays(rider.overlays(color: .green))     // covered part greys out
    .onAppear { rider.start() }

Text("Arriving in \(rider.formattedCountdown)")   // "01:24"
```

The courier glides along the route about 30 times a second and turns smoothly into each bend. For a
real courier, feed `rider.update(progress:)` from your backend instead of `start()`.

## Search, pick and snapshot

```swift
KitoPlaceSearchField("Search Nairobi", near: nairobiRegion) { place in
    pins.append(place.pin(style: .teardrop))
}

KitoLocationPicker(initialCoordinate: nairobi) { picked in
    order.dropOff = picked            // coordinate, name, address
}

KitoMapSnapshot(center: carnivore.coordinate, pins: [carnivore])
    .frame(height: 140)
    .clipShape(RoundedRectangle(cornerRadius: 20))
```

The picker keeps a pin fixed in the centre: it lifts while you drag, drops with a light haptic
when you stop, and the address under it is looked up.

## Moving the camera

```swift
@State private var map = KitoMapController()

KitoMapView(pins: places, style: .muted, camera: .center(nairobi, zoom: 13), controller: map)

Button("Show all") { map.move(to: .fitPins) }
Button("Carnivore") { map.focus(on: carnivore) }
```

Styles: `.standard`, `.muted`, `.imagery`, `.hybrid`. Zoom levels are the familiar 256-point tile
levels (11 ≈ a city, 16 ≈ a few streets) on every provider.

## Switching provider

The three map views take the same arguments and the same modifiers:

```swift
KitoMapView(pins: pins, selection: $selected) { KitoMapPinCard(pin: $0) }         // Apple Maps
KitoGoogleMapView(pins: pins, selection: $selected) { KitoMapPinCard(pin: $0) }   // import KitoMapsGoogle
KitoLibreMapView(pins: pins, selection: $selected) { KitoMapPinCard(pin: $0) }    // import KitoMapsLibre
```

## Helpers

```swift
KitoMapFormat.distance(1_240)                 // "1.2 km"
KitoMapFormat.duration(725)                   // "13 min"
KitoMapFormat.arrivalTime(after: 725)         // "14:32"
KitoMapGeometry.distance(from: a, to: b)      // metres
KitoMapGeometry.bearing(from: a, to: b)       // degrees
```

## Migrating from 0.1

0.2.0 renames `KitoRoute` (the directions result from `KitoRouteService`) to `KitoMapRoute`, so
KitoMaps can be imported next to KitoNavigation, whose `KitoRoute` is the router protocol, without
"ambiguous" errors. Its properties are unchanged. If you use KitoMapsGoogle or KitoMapsLibre,
update them to 0.2.0 at the same time.

## Info.plist

Add `NSLocationWhenInUseUsageDescription` if you show the user's location, the locate button or the
picker's "use my location".

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoMaps.git", from: "0.2.0")
```

iOS 17+. Depends on [KitoCore](https://github.com/WykSofts-Inc/KitoCore) for theming.

## License

MIT — see [LICENSE](LICENSE).
