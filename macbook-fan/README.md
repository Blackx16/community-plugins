# MacBook Fan

MacBook fan speed and thermal monitor for Noctalia with live RPM gauges, CPU package temperature readout, and mbpfan daemon integration.

## Plugin

| Field | Value |
| --- | --- |
| ID | `blackx16/macbook-fan` |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service` |

## Requirements

The plugin relies on standard system utilities declared in `dependencies`:

- `cat` on `PATH`
- `sh` on `PATH`
- `systemctl` on `PATH`

### Hardware & Kernel Requirements

- **Apple SMC Driver**: The `applesmc` kernel driver exposes `/sys/devices/platform/applesmc.*/fan1_input` for fan telemetry. It is standard in modern Linux kernels for Intel MacBooks.
- **mbpfan Daemon**: The `mbpfan` daemon controls the fan speed curve based on temperature thresholds.

An automated diagnostic and setup script is bundled with the plugin to verify and install these requirements:

```sh
./scripts/setup-requirements.sh
```

## Usage

Add the `widget` bar entry from Noctalia's Add-widget picker. The widget displays live fan speed in a themed pill badge with dynamic colorization based on CPU temperature and fan load.

Clicking the bar widget opens an attached telemetry popup panel showing:

- Current RPM, percentage, and an animated progress bar bounded by the MacBook's physical limits (1200–6500 RPM).
- Real-time CPU package temperature and controller daemon status.
- Interactive buttons to toggle display modes (RPM, percentage, or both).
- Health check indicators and a one-click button to run the requirements setup script.

The panel can also be opened via IPC:

```sh
noctalia msg panel-toggle blackx16/macbook-fan:panel
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `display_mode` | `select` | `rpm` | Choose whether to display fan speed as `rpm`, `percent`, or `both`. |
| `colorize_by_temp` | `bool` | `true` | Colorizes the widget glyph and pill badge based on temperature and RPM load. |
| `poll_interval_ms` | `int` | `2000` | Telemetry refresh interval in milliseconds (clamped between 500ms and 30000ms). |
| `allow_popup` | `bool` | `true` | Opens the attached detail panel on clicking the bar widget. |

## IPC

The panel supports standard Noctalia panel commands:

```sh
noctalia msg panel-toggle blackx16/macbook-fan:panel
noctalia msg panel-open blackx16/macbook-fan:panel
noctalia msg panel-close blackx16/macbook-fan:panel
```

## Notes

- **Non-root Telemetry**: Sensor reading is fully unprivileged. Fan RPM and CPU temperature are read from world-readable sysfs nodes (`/sys/devices/platform/applesmc.*` and `/sys/devices/platform/coretemp.0`).
- **mbpfan Integration**: The background service passively monitors whether `mbpfan.service` is active using `systemctl is-active mbpfan` without altering daemon configuration unless explicitly triggered by the user via the setup script.
