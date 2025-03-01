# ScreenButler TestFlight Submission Guide

## Fixing Validation Issues

This document provides solutions for the TestFlight validation errors you encountered.

### 1. Invalid Code Signing Entitlements

The entitlement `com.apple.security.files.desktop.read-write` is not supported for App Store distribution. Use these alternatives:

- **Modified in this fix**: Removed the unsupported entitlement from `ScreenButler.entitlements`
- **Sandbox-friendly alternatives**:
  - Use `com.apple.security.files.user-selected.read-write` (already included)
  - Use file pickers and security-scoped bookmarks for desktop access

### 2. Missing LSApplicationCategoryType

The Info.plist must include an LSApplicationCategoryType key for App Store submission.

- **Fix applied**: Added Info.plist with the required key set to `public.app-category.utilities`
- **Other category options**:
  - `public.app-category.productivity`
  - `public.app-category.utilities` 
  - `public.app-category.developer-tools`

### 3. Missing Required App Icon

The app must include proper app icons in ICNS format with 512x512 and 512x512@2x (1024x1024) sizes.

- **Partial fix applied**: Updated the asset catalog to include filenames for the required icons
- **Required actions**:
  1. Create proper PNG images for your app icon (512x512 and 1024x1024 sizes)
  2. Replace the placeholder files in `Assets.xcassets/AppIcon.appiconset/`

## Building for TestFlight

1. Open the project in Xcode
2. Select Product > Archive
3. In the Organizer window, select the archive and click "Distribute App"
4. Choose "App Store Connect" and follow the prompts
5. Select "Upload" to send your app to App Store Connect
6. Once processed, you can add the build to TestFlight

## Additional Tips

- Keep all entitlements compatible with App Store requirements
- Ensure your privacy descriptions match app functionality
- Add more app icon sizes for a complete set
- Test on multiple macOS versions before submission 