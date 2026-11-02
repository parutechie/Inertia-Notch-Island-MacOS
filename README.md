# Inertia

Inertia is a native macOS app that turns the MacBook notch into a compact, interactive workspace. Click or hover over the notch to expand the island and access everyday tools without leaving your current app. It can also show brief, glanceable system-status updates in the same space.

---

## Screenshots

## Screenshots

<p align="center">
  <img src="Assests/Screenshot 2026-11-02 at 6.34.35 PM.png" alt="Screenshot 1">
  <img src="Assests/Screenshot 2026-11-02 at 6.35.27 PM.png" alt="Screenshot 2">
  <img src="Assests/Screenshot 2026-11-02 at 6.35.47 PM.png" alt="Screenshot 3">
  <img src="Assests/Screenshot 2026-11-02 at 6.35.50 PM.png" alt="Screenshot 4">
  <img src="Assests/Screenshot 2026-11-02 at 6.35.53 PM.png" alt="Screenshot 5">
  <img src="Assests/Screenshot 2026-11-02 at 6.35.56 PM.png" alt="Screenshot 6">
  <img src="Assests/Screenshot 2026-11-02 at 6.35.58 PM.png" alt="Screenshot 7">
  <img src="Assests/Screenshot 2026-11-02 at 6.36.01 PM.png" alt="Screenshot 8">
  <img src="Assests/Screenshot 2026-11-02 at 6.36.04 PM.png" alt="Screenshot 9">
  <img src="Assests/Screenshot 2026-11-02 at 6.36.06 PM.png" alt="Screenshot 10">
  <img src="Assests/Screenshot 2026-11-02 at 6.36.08 PM.png" alt="Screenshot 11">
  <img src="Assests/Screenshot 2026-11-02 at 6.36.16 PM.png" alt="Screenshot 12">
</p>

---

## Features

- **Productivity tools:** Keep a task list, write and pin quick notes, schedule reminders, and view your calendar.
- **Focus timer:** Switch between work sessions and short or long breaks.
- **Music controls:** View and control supported media, with optional AppleScript control for Apple Music and Spotify.
- **Live status HUDs:** See volume, brightness, Focus, charging, and network updates around the notch.
- **Launcher and shelf:** Open the built-in launcher and access the island's shelf.
- **Customizable island:** Adjust its size and display, choose a built-in or main screen, and configure status displays and appearance in Settings.
- **Mac-native experience:** Built with Swift and SwiftUI, with AppKit integrations for display and system features.

---

## Requirements

- A Mac running **macOS 27.0 or later** (the deployment target configured by this project).
- Xcode with support for the project's macOS SDK and Swift Package Manager.

The app is designed around the MacBook notch. You can choose which display to use in Settings when working with multiple screens.

---

## Build and Run

1. Clone this repository.

   ```bash
   git clone <YOUR_REPOSITORY_URL>
   ```

2. Open `NotchApp.xcodeproj` in Xcode.

3. Select the `NotchApp` scheme.

4. Build and run the app.

Xcode resolves the project's Swift package dependencies, including Lottie, as part of the build.

---

## Permissions

Some integrations need macOS permission to work.

- **Calendar:** Calendar access may be required for calendar features.
- **Automation:** Apple Music or Spotify control may require Automation access.

You can review or change app permissions in:

**System Settings → Privacy & Security**

---

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Platform Integration:** AppKit
- **Animations:** Lottie
- **Dependency Management:** Swift Package Manager

---

<p align="center">
  Made with ❤️ for macOS
</p>
