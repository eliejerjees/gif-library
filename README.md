# GIF Library for Messages

Personal iPhone-only GIF and media library built with Swift, SwiftUI, a lightweight host app, and a Messages extension as the main experience.

## What ships in this MVP

- SwiftUI host iOS app for setup, fallback management, and imports
- iMessage extension that is the primary browsing, management, and sending surface
- Local on-device storage only through a shared App Group container
- Metadata persisted as a lightweight JSON file in the shared container
- GIF, still image, and video import support
- Video-to-GIF conversion using `AVFoundation` + `ImageIO`
- Two main tabs in the extension: `Recent` and `Folders`
- Folder create, rename, move, remove, and delete flows
- Preview/composer sheet with optional caption history

## Project structure

- `App/HostApp`: minimal host app entry point, assets, plist, and entitlements
- `App/MessagesExtension`: `MSMessagesAppViewController`, attachment insertion, assets, plist, and entitlements
- `Shared/Models`: local metadata models
- `Shared/Storage`: shared container setup and JSON-backed library store
- `Shared/Services`: thumbnail generation, Photos import handoff, remote download, and video-to-GIF conversion
- `Shared/ViewModels`: SwiftUI state and library actions
- `Shared/Views`: shared SwiftUI UI used by both the host app and the extension
- `Scripts/generate_project.rb`: regenerates the `.xcodeproj`

## How to run on a real iPhone

1. Open [`GifLibrary.xcodeproj`](/Users/eliejerjees/Desktop/Personal Projects/gif-library/GifLibrary.xcodeproj) in Xcode.
2. Replace the placeholder bundle identifiers:
   - Host app: `com.example.GifLibrary`
   - Messages extension: `com.example.GifLibrary.MessagesExtension`
3. In Signing & Capabilities, add the same App Group to both targets.
4. Replace the shared App Group build setting `APP_GROUP_IDENTIFIER` if you use a different identifier than `group.com.example.GifLibrary.shared`.
5. Select your personal team for both targets.
6. Build and run the host app on a physical iPhone once.
7. Open Messages, start a conversation, open the app drawer, and launch the Messages extension.

## Permissions and entitlements

- `NSPhotoLibraryUsageDescription` is included for Photos imports.
- Both targets include App Group entitlements and expect the same App Group to be configured in Xcode.
- No network backend, analytics, authentication, or cloud entitlements are used.

## Import methods implemented

- Fully implemented:
  - Photos import for still images and videos
  - Files import for GIFs, still images, and videos
  - Direct `http` / `https` URL download when the URL points to a supported GIF, image, or video file
- Structured for later:
  - A full system share extension is not included in this MVP, but the shared storage/import layers are isolated so a share extension can write into the same library later.

## Sending behavior and Messages limitations

- The extension preview sheet lets you add an optional caption and then inserts the caption plus media into the current Messages compose field.
- The user still taps the standard Messages send button afterward.
- This is the cleanest practical fallback for media attachments in a Messages extension because the extension APIs focus on insertion into the active conversation UI rather than a guaranteed one-tap send for arbitrary local GIF/image attachments.

## Known limitations

- The shared App Group must be configured before the app and extension can see the same library.
- The video-to-GIF conversion intentionally clips long videos to a short GIF-friendly duration to stay responsive in an extension context.
- Remote URL import works best for direct media file URLs, not HTML pages or social media landing pages.
- This repo does not include a share extension yet.

## What a future share extension would need

- A new share-extension target
- Target-specific UI for receiving `NSItemProvider` content from outside the app
- The same App Group entitlement so the share extension can write into the shared `LibraryStore`
- A small routing surface to let the user choose a folder before saving
