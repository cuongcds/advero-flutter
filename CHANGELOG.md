## Unreleased

- Request the house placeholder as PNG (`.png` suffix) since `Image.network` can't render SVG, and size it from the response's `width`/`height`.

## 0.2.1

- Send the app's package name / bundle ID in the `app` request parameter (override with `AdveroSDK.init(appId:)`); the server serves real ads only to verified apps.
- Add the `package_info_plus` dependency.

## 0.2.0

- Add the "Ads by Advero" badge on advertiser creatives.
- Report viewable impressions to the signed `view_url`.
- Add `lazy` to `AdveroAdView` to request the ad only near the viewport.
- Add `AdveroViewer` and the `viewer` parameter for signed viewer signals.

## 0.1.0

- Initial release.
