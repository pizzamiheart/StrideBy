# Local Strava Config

1. Copy `StravaSecrets.example.xcconfig` to `StravaSecrets.xcconfig`.
2. Fill in your Strava app credentials.
3. In Xcode, set these values on the app target's `Info.plist` entries:
   - `STRAVA_CLIENT_ID`
   - `STRAVA_CLIENT_SECRET`

`StravaSecrets.xcconfig` is gitignored and intended for local-only credentials.
