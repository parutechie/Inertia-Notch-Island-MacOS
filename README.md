# Inertia

**Inertia** is a native macOS app that transforms the MacBook notch into a compact, interactive workspace. Click or hover over the notch to expand the island and access everyday tools without leaving your current app. It can also display brief, glanceable system-status updates in the same space.

<p align="center">
  <img src="Assests/Screenshot 2026-11-02 at 6.34.35 PM.png" alt="Inertia macOS App Preview" width="850">
</p>

<p align="center">
  <b>A smarter workspace. Right at your notch.</b>
</p>

---

## Features

### Productivity Tools
- **Task Manager:** Keep track of your daily tasks.
- **Quick Notes:** Write, save, and pin important notes.
- **Reminders:** Schedule reminders for important activities.
- **Calendar:** View your calendar events without switching applications.

### Focus Timer
- Dedicated focus timer for productive work sessions.
- Short and long break modes.
- Helps maintain a structured workflow using focused work intervals.

### Music Controls
- View and control supported media playback.
- Optional AppleScript integration for Apple Music and Spotify.

### Live Status HUDs
- Volume level updates.
- Brightness status.
- Focus mode updates.
- Battery and charging status.
- Network status updates.

### Launcher & Shelf
- Access the built-in application launcher.
- Quickly access items through the island's shelf.

### Customizable Island
- Adjust island size and appearance.
- Choose between built-in and main displays.
- Configure status displays and visual preferences through Settings.

### Mac-Native Experience
- Built using Swift and SwiftUI.
- AppKit integrations for macOS system features.
- Designed to provide a seamless macOS experience.

---

## Requirements

- A Mac running **macOS 27.0 or later**.
- Xcode with support for the project's macOS SDK.
- Swift Package Manager.

The application is designed around the MacBook notch. You can choose which display to use in Settings when working with multiple screens.

---

## Build and Run

1. Clone this repository:

   ```bash
   git clone <YOUR_REPOSITORY_URL>
   ```

2. Open the project in Xcode:

   ```bash
   open NotchApp.xcodeproj
   ```

3. Select the **NotchApp** scheme.
4. Build and run the application.

Xcode automatically resolves the project's Swift package dependencies, including Lottie.

---

## Permissions

Some integrations require macOS permissions to function correctly.

Examples include:

- **Calendar Access:** Required for calendar features.
- **Automation Access:** May be required for Apple Music and Spotify controls.

You can review or modify application permissions under:

**System Settings → Privacy & Security**

---

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Platform Integration:** AppKit
- **Animation:** Lottie
- **Dependency Management:** Swift Package Manager

---

## Project Structure

```text
Inertia/
├── Assets/
│   └── inertia-preview.png
├── NotchApp.xcodeproj/
├── NotchApp/
├── .gitignore
└── README.md
```

---

<p align="center">
  Made with ❤️ for macOS
</p>
