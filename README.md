# Inertia

Inertia is a native macOS app that turns the MacBook notch into a compact, interactive workspace. Click or hover over the notch to expand the island and access everyday tools without leaving your current app. It can also show brief, glanceable system-status updates in the same space.

## Features

- **Productivity tools:** Keep a task list, write and pin quick notes, schedule reminders, and view your calendar.
- **Focus timer:** Switch between work sessions and short or long breaks.
- **Music controls:** View and control supported media, with optional AppleScript control for Apple Music and Spotify.
- **Live status HUDs:** See volume, brightness, Focus, charging, and network updates around the notch.
- **Launcher and shelf:** Open the built-in launcher and access the island's shelf.
- **Customizable island:** Adjust its size and display, choose a built-in or main screen, and configure status displays and appearance in Settings.
- **Mac-native experience:** Built with Swift and SwiftUI, with AppKit integrations for display and system features.

## Requirements

- A Mac running **macOS 27.0 or later** (the deployment target configured by this project).
- Xcode with support for the project's macOS SDK and Swift Package Manager.

The app is designed around the MacBook notch. You can choose which display to use in Settings when working with multiple screens.

## Build and run

1. Clone this repository.
2. Open `NotchApp.xcodeproj` in Xcode.
3. Select the `NotchApp` scheme, then build and run the app.

Xcode resolves the project's Swift package dependencies, including Lottie, as part of the build.

## Permissions

Some integrations need macOS permission to work. For example, calendar features may request Calendar access, and Apple Music or Spotify control may require Automation access. You can review or change app permissions in **System Settings → Privacy & Security**.
