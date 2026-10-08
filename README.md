# Ionfetch

> An ultra-fast, zero-dependency, minimal homelab and server status fetch utility written in pure Bash.

Designed to be snappy and lightweight as an SSH login banner (MOTD) or quick diagnostic command like `neofetch`, without the overhead.

```text
CORE SERVER
HOSTNAME / server01
----------------------------
IP      192.168.1.100
UPTIME  14d 06h 23m
RAM     [####......]  41%  6.5/16.0 GiB
DISK 1 [/] [######....]  62%  28.4/45.8 GiB
DISK 2 [/mnt/storage] [####......]  41%  120.0/300.0 GiB
LOAD    0.45 / 4 cores  (42°C)
FAILED  0 services
```

---

## Quick Install

Install `ionfetch` with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/sirayu-pn/Ionfetch/main/install.sh | bash
```

Once installed, simply run:

```bash
ionfetch
```

> **Note:** If installing without `sudo` privileges, you can install to `~/.local/bin`:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/sirayu-pn/Ionfetch/main/install.sh | bash -s -- --user
> ```

---

## Manual Installation

To clone and install locally:

```bash
git clone https://github.com/sirayu-pn/Ionfetch.git
cd Ionfetch
chmod +x install.sh
sudo ./install.sh
```

---

## Usage

Run `ionfetch` anytime directly from your terminal:

```bash
ionfetch
```

### CLI Options

| Flag | Description |
| :--- | :--- |
| `-h`, `--help` | Show help and available options |
| `-v`, `--version` | Display current version |
| `--no-color` | Disable ANSI colored output |

Multiple options can be combined. Unknown options return an error and exit with status `2`.

### Development Checks

Run the built-in smoke tests with Bash:

```bash
bash tests/test_ionfetch.sh
```

---

## Run Automatically on SSH Login (MOTD)

To run `ionfetch` automatically every time you log in to your server:

### Option A: For Your User Only
Add this line to the end of your `~/.bashrc` or `~/.zshrc`:
```bash
echo "ionfetch" >> ~/.bashrc
```

### Option B: System-wide (All Users)
Create a profile script in `/etc/profile.d/`:
```bash
sudo tee /etc/profile.d/ionfetch.sh > /dev/null << 'EOF'
# Only run on interactive login shells
if [ -t 1 ] && command -v ionfetch >/dev/null 2>&1; then
    ionfetch
fi
EOF
```

---

## Features

- **Kernel Direct:** Reads metrics directly from `/proc` and `/sys` for near-instant execution without launching heavy tools.
- **CPU Temperature:** Automatically detects CPU temperature via sysfs thermal zone with color thresholds.
- **Multiple Storage:** Detects mounted storage filesystems and displays each one as `DISK 1`, `DISK 2`, etc., while ignoring system pseudo-filesystems.
- **Custom Storage Target:** Inspect only the filesystem containing a selected path via `IONFETCH_DISK_PATH`. Without it, all detected storage filesystems are shown.
- **Systemd Health:** Detects failed systemd services, lists the top 3 with clean bullets, and links to `systemctl --failed`.
- **Reboot Alerts:** Displays a warning notice if a system reboot is pending after kernel or security updates (`/var/run/reboot-required`).

---

## Customization

Customize behavior by setting environment variables in your shell or `.bashrc`:

```bash
# In your ~/.bashrc or export before running:
export IONFETCH_TITLE="PROXMOX NODE 01"
export IONFETCH_SUBTITLE="HOME-DATACENTER / rack-01"
export IONFETCH_DISK_PATH="/mnt/storage"  # optional: show only this filesystem
```

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `IONFETCH_TITLE` | Distribution name or `CORE SERVER` | Primary header title |
| `IONFETCH_SUBTITLE` | `HOSTNAME / <hostname>` | Subtitle text |
| `IONFETCH_DISK_PATH` | *(unset)* | Optional path; show only the filesystem containing this path |
| `NO_COLOR` | *(empty)* | Set to `1` or pass `--no-color` to strip color codes |

---

## Uninstallation

To remove `ionfetch` from your system:

```bash
# If you have the repo:
sudo ./install.sh --uninstall

# Or using curl:
curl -fsSL https://raw.githubusercontent.com/sirayu-pn/Ionfetch/main/install.sh | bash -s -- --uninstall
```

---

## Requirements and Compatibility

- **OS:** Linux (Debian, Ubuntu, Arch, Fedora, Alpine, Proxmox VE, Raspberry Pi OS, etc.)
- **Shell:** `bash`
- **Dependencies:** Standard core utilities (`awk`, `df`, `ip` or `hostname`, `/proc` filesystem)
- **Fast:** Executes in milliseconds without calling heavyweight tools (`top`, `free`, or `python`).

---

## License

MIT License.
