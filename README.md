# omarchy-sony

A modern, lightweight Omarchy bar-widget plugin and headless C++20 background daemon to manage **Sony WH-1000XM5** (and compatible Sony MDR v2) headphones on Linux.

Provides real-time battery monitoring, Noise Cancellation (ANC / Ambient / Off) mode switching, granular ambient sound level controls, Equalizer presets, and smart feature toggles directly from the Omarchy desktop shell or command line.

---

## Features

- 🔋 **Live Battery & Codec Monitoring:** Real-time battery percentage, charging state, and active Bluetooth audio codec (e.g. LDAC, AAC, SBC).
- 🎧 **Noise Control Modes:** Seamless hardware switching between **ANC (Noise Canceling)**, **Ambient Sound**, and **Off** (passive).
- 🔊 **Ambient Sound Level Slider:** Granular adjustment of ambient passthrough (levels 0–20) with Focus on Voice support.
- 🎛️ **Equalizer Profiles:** Switch presets (*Off, Bright, Excited, Mellow, Relaxed, Vocal, Treble Boost, Bass Boost, Speech, Custom*) and configure 5-band custom EQ + Clear Bass.
- ⚙️ **Smart Features:** Speak-to-Chat, DSEE Extreme upscaling, Multipoint Bluetooth connection, and Wear/Ear Detection toggles.
- ⌨️ **Keyboard Navigation:** Full vim-style navigation (`h`/`j`/`k`/`l`, `Enter`, `Esc`) inside the panel dropdown.
- 💻 **Standalone CLI (`sony-ctl`):** Full terminal and scripting interface for all headphone controls.
- ⚡ **Zero Polling & Lightweight:** Native BlueZ RFCOMM transport with reactive file-view event updates.

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                   Omarchy Shell (QML)                  │
│   ┌───────────────┐ ┌─────────────┐ ┌──────────────┐   │
│   │   SonyIcon    │ │  Service    │ │    Panel     │   │
│   └───────▲───────┘ └──────▲──────┘ └──────▲───────┘   │
│           │                │               │           │
│           └────────────────┼───────────────┘           │
│                            │ watches                   │
│                            │ (FileView)                │
│                 ~/.local/state/sony-headphones/        │
│                           status.json                  │
│                                ▲                       │
│                                │ writes                │
└────────────────────────────────┼───────────────────────┘
                                 │
┌────────────────────────────────┼───────────────────────┐
│  Headless Daemon               │   Companion CLI       │
│  (sony-headphones-daemon)      │   (sony-ctl)          │
│                                │           │           │
│   UNIX Domain Socket ◄─────────┴───────────┘           │
│   (/run/user/$UID/sony-headphones.sock)                │
│                 │                                      │
│                 ▼                                      │
│   Bluetooth RFCOMM Stack (MDR v2 Protocol)             │
│                 │ (Channel 9)                          │
│                 ▼                                      │
│       Sony WH-1000XM5 Headset                          │
└────────────────────────────────────────────────────────┘
```

- **`plugin/`**: Quickshell / QML plugin conforming to Omarchy manifest specification version 1.
- **`daemon/`**: Headless C++20 background daemon managing Bluetooth RFCOMM connection and UNIX socket IPC.
- **`cli/`**: Lightweight CLI tool (`sony-ctl`) for terminal queries and control scripts.

---

## Prerequisites

On Arch Linux / Omarchy:
```bash
sudo pacman -S --needed base-devel cmake ninja bluez bluez-libs dbus jq
```

On Debian / Ubuntu:
```bash
sudo apt update && sudo apt install -y build-essential cmake ninja-build libbluetooth-dev libdbus-1-dev jq
```

---

## Installation & Setup

Clone the repository and run the automated setup script:

```bash
git clone https://github.com/andROYdified/omarchy-sony.git
cd omarchy-sony
./setup
```

The `./setup` script will:
1. Verify system dependencies.
2. Build the daemon and CLI binaries with CMake and Ninja.
3. Install `sony-headphones-daemon` and `sony-ctl` to `~/.local/bin/`.
4. Register and start the `sony-headphones.service` user systemd unit.
5. Deploy the QML plugin to `~/.config/omarchy/plugins/io.github.androydified.omasony`.

### Bar widget options

Set options inline on the widget's entry in `~/.config/omarchy/shell.json`. The shell reloads them on save.

| Option | Default | Effect |
| --- | --- | --- |
| `hideWhenDisconnected` | `false` | Hide the bar icon while the headphones are disconnected |

```json
{
  "id": "io.github.androydified.omasony",
  "hideWhenDisconnected": true
}
```

---

## CLI Usage (`sony-ctl`)

You can query or control your headphones from anywhere via `sony-ctl`:

```bash
# Query full headphone status as JSON
sony-ctl status

# Switch Noise Cancellation Modes
sony-ctl noise anc          # Turn on Active Noise Cancellation
sony-ctl noise ambient      # Switch to Ambient Sound mode
sony-ctl noise off          # Turn off noise processing

# Adjust Ambient Sound Level (0 - 20)
sony-ctl ambient-level 12

# Equalizer Presets
sony-ctl eq bright
sony-ctl eq vocal
sony-ctl eq bass
sony-ctl eq custom 0 2 4 2 0 5  # 5 bands (-10..10) + Clear Bass (-10..10)

# Toggle Smart Features
sony-ctl speak-to-chat on
sony-ctl dsee on
sony-ctl multipoint on
sony-ctl ear-detection on
```

---

## Systemd Service Management

The background daemon is managed automatically via user systemd:

```bash
# Check daemon status and logs
systemctl --user status sony-headphones.service
journalctl --user -u sony-headphones.service -f

# Restart daemon
systemctl --user restart sony-headphones.service
```

---

## Testing

Run unit tests and end-to-end integration tests:

```bash
# C++ Protocol Unit Tests
cmake --build build --target test

# JavaScript Model Unit Tests (requires Deno or Node.js)
deno run --allow-read tests/model.test.js

# End-to-End Simulation Tests
./tests/integration.sh
```

---

## Documentation

For low-level protocol packet specifications, framing definitions, and RFCOMM channel mapping details, see the [Sony MDR Protocol Guide](docs/protocol-guide.md).

---

## Acknowledgments & References

This project builds upon and draws inspiration from two open-source projects:

1. **[thisisgm/omarchy-pods](https://github.com/thisisgm/omarchy-pods)**:
   - Architecture reference for the Omarchy bar widget + headless background daemon + atomic state file design.
2. **[mos9527/SonyHeadphonesClient](https://github.com/mos9527/SonyHeadphonesClient)**:
   - Reverse-engineered protocol definitions and implementation reference for Sony MDR Bluetooth RFCOMM communication.

---

## Disclaimer

This is an unofficial, independent community project developed for Linux desktop integration. It is not affiliated with, authorized, maintained, sponsored, or endorsed by Sony Corporation or any of its subsidiaries. "Sony", "WH-1000XM5", and related marks are registered trademarks of Sony Corporation.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
