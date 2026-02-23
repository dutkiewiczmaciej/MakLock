<p align="center">
  <img src="Resources/icon.png" width="128" height="128" alt="MakLock icon">
</p>

<h1 align="center">MakLock</h1>

<p align="center">
  <strong>Lock any macOS app with Touch ID, Apple Watch, or password.</strong><br>
  Free, open source, and more powerful than paid alternatives.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-black?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9%2B-FFD213?style=flat-square" alt="Swift">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-white?style=flat-square" alt="License"></a>
  <a href="https://github.com/dutkiewiczmaciej/MakLock/stargazers"><img src="https://img.shields.io/github/stars/dutkiewiczmaciej/MakLock?style=flat-square&color=FFD213" alt="Stars"></a>
  <a href="https://github.com/dutkiewiczmaciej/MakLock/releases/latest"><img src="https://img.shields.io/github/v/release/dutkiewiczmaciej/MakLock?style=flat-square&label=release" alt="Release"></a>
</p>

---

## What is MakLock?

MakLock is a lightweight menu bar app that protects your macOS applications with Touch ID, Apple Watch proximity, or a backup password. When someone tries to open or switch to a protected app, MakLock blocks access with a blur overlay and requires authentication.

Unlike App Store alternatives, MakLock is distributed directly — giving it full overlay and process management capabilities that sandboxed apps simply cannot offer.

## Why MakLock?

| Feature | MakLock | AppLocker ($17.99) | Cisdem AppCrypt ($19.99/yr) |
|---------|:-------:|:------------------:|:---------------------------:|
| **Price** | **Free forever** | 1 app free, paid for more | Trial only |
| **Open source** | **Yes** | No | No |
| **Touch ID** | **Yes** | Paid only | No |
| **Lock on app switch** | **Yes** | No (launch only) | Yes |
| **Apple Watch unlock** | **Yes** (wrist detection) | No | No |
| **Modern blur overlay** | **Yes** (all monitors) | Basic panel | Dialog box |
| **Auto-close apps** | **Yes** | No (sandbox) | No (sandbox) |
| **Close apps on sleep** | **Yes** | No | No |
| **Auto-lock on idle** | **Yes** | No | Yes |
| **Auto-lock on sleep** | **Yes** | No | No |
| **Panic key** | **Yes** | No | No |
| **Multi-monitor** | **Yes** | Unknown | No |
| **Bypass resistant** | **Yes** | No (Bundle ID edit) | Unknown |

AppLocker only locks apps on launch — if an app is already open, switching back to it shows content without authentication. MakLock watches for app activation, not just launch, so protection works even when switching between open apps.

## Features

- [x] Lock apps with Touch ID (single prompt)
- [x] Password fallback for Macs without Touch ID
- [x] Apple Watch proximity unlock with wrist detection
- [x] Full-screen blur overlay on all monitors
- [x] Auto-lock after idle timeout (configurable)
- [x] Auto-lock on sleep/wake
- [x] Auto-close inactive apps (prevents notification snooping)
- [x] Close protected apps on sleep (privacy on shared laptops)
- [x] Menu bar app (no Dock icon, runs silently)
- [x] Panic key emergency exit (`Cmd+Opt+Shift+Ctrl+U`)
- [x] System app blacklist (Terminal, Xcode, etc. can never be locked)
- [x] Multi-monitor support
- [x] First launch onboarding
- [x] Settings with tabbed UI
- [x] Automatic updates via Sparkle 2
- [ ] Trusted Wi-Fi auto-unlock *(coming in v1.1)*
- [ ] Per-window overlay *(coming in v1.2)*

## Screenshots

<p align="center">
  <img src="Resources/screenshots/overlay.png" width="720" alt="Lock overlay">
  <br><em>Full-screen blur overlay with Touch ID unlock</em>
</p>

<p align="center">
  <img src="Resources/screenshots/settings.png" width="560" alt="Settings window">
  <br><em>Settings with protected apps management</em>
</p>

<p align="center">
  <img src="Resources/screenshots/menubar.png" width="280" alt="Menu bar">
  <br><em>Menu bar with quick toggle and status</em>
</p>

## Installation

### Download

Download the latest `.dmg` from [**Releases**](https://github.com/dutkiewiczmaciej/MakLock/releases/latest).

> MakLock is notarized by Apple for safe distribution outside the App Store.

### Homebrew

```bash
brew install --cask maklock   # coming soon
```

### Build from Source

```bash
git clone https://github.com/dutkiewiczmaciej/MakLock.git
cd MakLock
open MakLock.xcodeproj
```

Build and run with `Cmd+R`. Requires Xcode 15+ and macOS 13+.

## How It Works

1. **App Monitor** — watches for protected app launches and activations via NSWorkspace
2. **Lock Overlay** — instantly shows a full-screen blur overlay on all displays
3. **Authentication** — prompts Touch ID, checks Apple Watch proximity, or asks for password
4. **Auto-lock** — re-locks on idle timeout, sleep, or when Apple Watch leaves range
5. **Auto-close** — optionally terminates inactive protected apps to prevent notification snooping

## Architecture

MakLock is a native Swift/SwiftUI application distributed outside the App Store for full system access.

```
MakLock/
  App/        Entry point, AppDelegate
  Core/       Services (AppMonitor, Auth, Watch, Overlay, Idle, Sleep, Inactivity)
  UI/         Design system, Components, Settings, Lock Overlay
  Models/     Data models (ProtectedApp, AppSettings, LockSession)
  Resources/  Assets, Info.plist, Entitlements
```

**Key frameworks:** SwiftUI, AppKit, LocalAuthentication, CoreBluetooth, IOKit, ServiceManagement, HotKey (SPM), Sparkle 2 (SPM)

## Safety

MakLock includes multiple safety mechanisms to ensure you never get locked out:

- **Panic key** — `Cmd+Option+Shift+Control+U` instantly dismisses all overlays
- **System blacklist** — Terminal, Xcode, Activity Monitor, and other critical apps can never be locked
- **Timeout failsafe** — overlays auto-dismiss after 60 seconds without interaction
- **Dev mode** — DEBUG builds include a Skip button and 10-second auto-dismiss

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac
- Touch ID recommended (password fallback available)
- Apple Watch with watchOS 9+ for proximity unlock (optional)

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) — Made by [MakMak](https://github.com/dutkiewiczmaciej)
