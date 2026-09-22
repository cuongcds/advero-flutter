# advero_flutter

Flutter SDK that publishers embed in their apps (Android + iOS) to display
Advero ads. Talks to the Ad Serving Engine's `/ads/*` routes
(`backend/application/controllers/Ads.php`), authenticated by
`placementCode` — not by cookie/session.

The Dart package name is `advero_flutter` (snake_case, required by Dart
package naming conventions), while the repo/directory is `advero-flutter`
(dash, GitHub convention) — same package, just two different naming rules
for two different contexts.

## Install

### Via pub.dev (once published)

```yaml
dependencies:
  advero_flutter: ^0.1.0
```

### Via git dependency (available now, before publishing)

```yaml
dependencies:
  advero_flutter:
    git:
      url: https://github.com/cuongcds/advero-flutter.git
```

Then:

```bash
flutter pub get
```

## Usage

The SDK never assumes or defaults the Advero backend's domain — you must
pass your own `baseUrl` explicitly. Replace `https://ads-advero.domain.com`
below with the actual ad-serving endpoint for your Advero account (this is a
placeholder, not a real host).

```dart
import 'package:advero_flutter/advero_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  AdveroSDK.init(
    baseUrl: 'https://ads-advero.domain.com', // your Advero ad-serving endpoint — required, no default
  );
  runApp(const MyApp());
}
```

Then drop `AdveroAdView` anywhere in your widget tree, one per ad slot:

```dart
AdveroAdView(
  placementCode: 'YOUR_PLACEMENT_CODE', // required, no default
)
```

Call `AdveroSDK.init()` once per app (e.g. in `main()` before `runApp()`).
Use one `AdveroAdView` per ad slot — each slot has its own `placementCode`.

### Getting your baseUrl/placementCode

- `baseUrl` is the ad-serving endpoint for your Advero account — ask whoever
  manages your Advero account/deployment for this URL; the SDK has no
  default and will refuse to run without it.
- `placementCode` is a single opaque value (`propertyCode-randomCode`, e.g.
  `ap-0123456789abcdef01234567-89abcdef`) generated for each placement — you
  copy it as-is, never construct or split it yourself:
  1. Log in to Advero and go to your Property's **Placements** list
     (Properties (`/property`) → open your app's Property → **Placements**).
  2. Next to the placement you want to embed, click the copy icon under
     **Placement code**.
  3. Paste that value as `placementCode` above. It only works for the
     property it belongs to — a code copied for one property will not serve
     ads for another.

## `AdveroSDK.init({ required String baseUrl })`

| Parameter | Required | Description |
| --- | --- | --- |
| `baseUrl` | yes | Origin of the Advero ad-serving endpoint, e.g. `https://ads-advero.domain.com`. Must be supplied by you — the SDK does not hardcode or default to any Advero domain. |

Throws an `ArgumentError` immediately if `baseUrl` is missing or empty —
this is a configuration error meant to be caught during integration, not at
runtime in front of real users.

## `AdveroAdView` widget parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `placementCode` | yes | The placement's code (`propertyCode-randomCode`), copied from the Placements list. Must be supplied by you — no default. Throws `ArgumentError` if empty. |
| `showPlaceholder` | no | When there's no eligible advertiser creative, the API returns a placeholder ("Advertise here" banner linking to this placement's Marketplace listing) instead of leaving the slot empty. Defaults to `true`. Pass `false` to render nothing in that case instead of the placeholder. |
| `onAdLoaded` | no | Called once a real ad (or an allowed placeholder) has been fetched and is about to be shown. |
| `onEmpty` | no | Called when there is nothing to display (204, network/parse error, or a placeholder suppressed by `showPlaceholder: false`). |

### Behavior

- On success (`200` with `creative_url`/`click_url`), renders the creative as
  a tappable image (`Image.network`) — tapping opens `click_url` in an
  external browser via `url_launcher`. This also covers the placeholder
  response (`placeholder: true`) unless `showPlaceholder: false` was passed.
- On `204 No Content`, any network error, or a malformed/unparseable
  response, the widget silently collapses to `SizedBox.shrink()` — this is
  normal (no eligible campaign for that placement right now), not a failure,
  and never throws or surfaces a `FlutterError`.
- Throws only for integration mistakes: missing/empty `placementCode` at
  construction time, or using `AdveroAdView` before calling
  `AdveroSDK.init()`.

## Dependencies

- [`http`](https://pub.dev/packages/http) — official Dart team package, used
  for the single `GET` request per ad slot.
- [`url_launcher`](https://pub.dev/packages/url_launcher) — opens
  `click_url` in the device's browser/external app on tap.
- Images are rendered with Flutter's built-in `Image.network`, which already
  caches through the framework's default `ImageCache` — no extra caching
  dependency is included to keep the dependency footprint minimal. If you
  need stronger disk caching, swap in
  [`cached_network_image`](https://pub.dev/packages/cached_network_image)
  yourself.

## Example

A runnable example app lives in [`example/`](example/):

```bash
cd example
flutter run
```

## Versioning

Semver.
