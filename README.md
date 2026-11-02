<div align="center">

# 🏝️ Inertia

**Turn your MacBook notch into a compact, interactive workspace.**

Click or hover over the notch to expand the island and reach everyday tools without leaving your current app, plus brief, glanceable system-status updates in the same space.

![Platform](https://img.shields.io/badge/platform-macOS%2027%2B-000000?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0A84FF?style=for-the-badge&logo=swift&logoColor=white)

[Features](#-features) · [Requirements](#-requirements) · [Build and Run](#-build-and-run) · [Permissions](#-permissions) · [Tech Stack](#-tech-stack)

</div>

---

## 📸 Screenshots

<div align="center">

<table>
  <tr>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.34.35%20PM.png" width="250"></td>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.35.27%20PM.png" width="250"></td>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.35.47%20PM.png" width="250"></td>
  </tr>
  <tr>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.35.50%20PM.png" width="250"></td>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.35.53%20PM.png" width="250"></td>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.35.56%20PM.png" width="250"></td>
  </tr>
  <tr>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.35.58%20PM.png" width="250"></td>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.36.01%20PM.png" width="250"></td>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.36.04%20PM.png" width="250"></td>
  </tr>
  <tr>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.36.06%20PM.png" width="250"></td>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.36.08%20PM.png" width="250"></td>
    <td><img src="Assests/Screenshot%202026-11-02%20at%206.36.16%20PM.png" width="250"></td>
  </tr>
</table>

</div>

---

## ✨ Features

| | Feature | What it does |
|---|---|---|
| ✅ | **Productivity tools** | Keep a task list, write and pin quick notes, schedule reminders, and view your calendar. |
| ⏱️ | **Focus timer** | Switch between work sessions and short or long breaks. |
| 🎵 | **Music controls** | View and control supported media, with optional AppleScript control for Apple Music and Spotify. |
| 📡 | **Live status HUDs** | See volume, brightness, Focus, charging, and network updates around the notch. |
| 🚀 | **Launcher and shelf** | Open the built-in launcher and access the island's shelf. |
| 🎛️ | **Customizable island** | Adjust size and display, choose a built-in or main screen, and configure status displays and appearance in Settings. |
| 🍎 | **Mac-native experience** | Built with Swift and SwiftUI, with AppKit integrations for display and system features. |

---

## 💻 Requirements

- A Mac running **macOS 27.0 or later** (the deployment target configured by this project)
- **Xcode** with support for the project's macOS SDK and Swift Package Manager

> [!NOTE]
> The app is designed around the MacBook notch. You can choose which display to use in Settings when working with multiple screens.

---

## 🛠️ Build and Run

1. **Clone** this repository:

   ```bash
   git clone <YOUR_REPOSITORY_URL>
   ```

2. **Open** `NotchApp.xcodeproj` in Xcode.
3. **Select** the `NotchApp` scheme.
4. **Build and run** the app.

Xcode resolves the project's Swift package dependencies, including Lottie, as part of the build.

---

## 🔐 Permissions

Some integrations need macOS permission to work.

| Permission | Needed for |
|---|---|
| **Calendar** | Calendar features |
| **Automation** | Apple Music or Spotify control |

You can review or change app permissions in **System Settings → Privacy & Security**.

---

## 🧰 Tech Stack

| Area | Technology |
|---|---|
| Language | Swift |
| UI Framework | SwiftUI |
| Platform Integration | AppKit |
| Animations | Lottie |
| Dependency Management | Swift Package Manager |

---

<div align="center">

Made with ❤️ for macOS

</div>
