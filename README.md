# DNS Manager

A powerful, interactive bash script to easily configure DNS servers on Linux systems. Test all DNS servers and automatically select the fastest one based on response time.

## Features

- 🎯 **Interactive Menu**: Easy-to-use menu interface
- ⚡ **DNS Testing**: Test all DNS servers and find the fastest one
- 🔧 **Multiple DNS Options**: 
  - Shecan Free & Pro
  - Google DNS
  - Cloudflare DNS
  - Quad9 (Security-focused)
  - OpenDNS
  - AdGuard (Ad-blocking)
  - Automatic (System Default)
- 🚀 **Auto-Detection**: Automatically detects and uses systemd-resolved, NetworkManager, or direct resolv.conf
- ✅ **Smart Testing**: Tests DNS servers by querying google.com and measures response time

## Supported DNS Servers

| Option | DNS Server | Primary DNS | Secondary DNS |
|--------|-----------|-------------|---------------|
| 1 | Google | 8.8.8.8 | 8.8.4.4 |
| 2 | Cloudflare | 1.1.1.1 | 1.0.0.1 |
| 3 | OpenDNS | 208.67.222.222 | 208.67.220.220 |
| 4 | Quad9 | 9.9.9.9 | 149.112.112.112 |
| 5 | AdGuard | 94.140.14.14 | 94.140.15.15 |
| 6 | Shecan Free | 178.22.122.100 | 185.51.200.2 |
| 7 | Shecan Pro | 178.22.122.100 | 185.51.200.2 |
| 8 | Automatic | System Default | System Default |

## Installation

### Quick Install (One-liner)

**Option 1: Direct install from GitHub:**

```bash
curl -sSL https://raw.githubusercontent.com/bit-prophet/dns-tool/main/dns-tool.sh | sudo bash -s install
```

**Option 2: Download and install manually:**

```bash
# Download the script
curl -O https://raw.githubusercontent.com/bit-prophet/dns-tool/main/dns-tool.sh

# Make it executable
chmod +x dns-tool.sh

# Install it
sudo ./dns-tool.sh install
```

### Manual Installation

```bash
# Clone or download the repository
git clone https://github.com/bit-prophet/dns-tool.git
cd dns-tool

# Make the script executable
chmod +x dns-tool.sh

# Install to system
sudo cp dns-tool.sh /usr/local/bin/dns-tool
sudo chmod +x /usr/local/bin/dns-tool
```

## Usage

### Basic Usage

Simply run the command:

```bash
sudo dns-tool
```

You'll see an interactive menu:

```
==========================================
      DNS Server Configuration
==========================================

Please select a DNS server:
  1) Google
  2) Cloudflare
  3) OpenDNS
  4) Quad9
  5) AdGuard
  6) Shecan Free
  7) Shecan Pro
  8) Automatic (None)
  9) Test all DNS servers (choose best)

Enter your choice (1-9):
```

### Test All DNS Servers

Choose option **9** to test all DNS servers. The script will:
1. Test each DNS server by querying google.com
2. Measure response times
3. Display results sorted by speed
4. Highlight the fastest DNS server
5. Ask if you want to automatically set the best one

Example output:

```
==========================================
  Testing DNS Servers...
==========================================

Testing Google (8.8.8.8)... 18ms
Testing Cloudflare (1.1.1.1)... 15ms
Testing OpenDNS (208.67.222.222)... 22ms
Testing Quad9 (9.9.9.9)... 20ms
Testing AdGuard (94.140.14.14)... 25ms
Testing Shecan Free (178.22.122.100)... 24ms
Testing Shecan Pro (178.22.122.100)... 25ms

==========================================
  Test Results Summary
==========================================

DNS Server          IP Address           Response Time
------------------------------------------------------------
Cloudflare          1.1.1.1             15ms ⭐
Google              8.8.8.8             18ms
Quad9               9.9.9.9             20ms
OpenDNS             208.67.222.222      22ms
Shecan Free         178.22.122.100      24ms
AdGuard             94.140.14.14        25ms
Shecan Pro          178.22.122.100      25ms

Best DNS Server: Cloudflare (1.1.1.1)
Response Time: 15ms

Do you want to set this DNS server? (y/n):
```

## Requirements

- Linux operating system
- Root/sudo access
- One of the following DNS management systems (automatically detected):
  - `systemd-resolved` (systemd-based distributions)
  - `NetworkManager` (via `nmcli`)
  - `netplan` (Ubuntu 18.04+)
  - `resolvconf` utility (older Debian/Ubuntu)
  - Direct `/etc/resolv.conf` access (universal fallback)

### Optional Tools (for DNS testing)

- `dig` (recommended for accurate DNS testing)
- `host` and `ping` (fallback for DNS testing)

## Supported Linux Distributions

The script is designed to work across a wide range of Linux distributions:

- **Ubuntu** (all versions) - systemd-resolved, NetworkManager, or netplan
- **Debian** (all versions) - systemd-resolved, NetworkManager, or resolvconf
- **Fedora** - systemd-resolved or NetworkManager
- **CentOS/RHEL** - NetworkManager or systemd-resolved
- **Arch Linux** - systemd-resolved or NetworkManager
- **openSUSE** - systemd-resolved or NetworkManager
- **Alpine Linux** - resolv.conf (fallback method)
- **Other distributions** - Uses resolv.conf fallback method

## How It Works

The script automatically detects your system's DNS management method in this order:

1. **systemd-resolved**: Creates configuration in `/etc/systemd/resolved.conf.d/` (systemd-based distros)
2. **NetworkManager**: Uses `nmcli` to modify network connections (most modern distributions)
3. **netplan**: Uses `netplan set` command (Ubuntu 18.04+)
4. **resolvconf**: Uses resolvconf utility (older Debian/Ubuntu systems)
5. **Direct resolv.conf**: Modifies `/etc/resolv.conf` directly with backup (universal fallback)

## Uninstallation

To remove the script:

```bash
sudo rm /usr/local/bin/dns-tool
```

## Troubleshooting

### "Command not found" after installation

Make sure `/usr/local/bin` is in your PATH:
```bash
echo $PATH | grep -q /usr/local/bin || export PATH=$PATH:/usr/local/bin
```

### DNS changes not taking effect

1. Restart your network connection
2. Flush DNS cache (depending on your system):
   ```bash
   # For systemd-resolved
   sudo systemd-resolve --flush-caches
   sudo resolvectl flush-caches
   
   # For NetworkManager
   sudo systemctl restart NetworkManager
   
   # For netplan (Ubuntu)
   sudo netplan apply
   ```
3. If using resolv.conf directly, ensure it's not a symlink that gets overwritten

### Testing shows "Failed" for all DNS servers

- Make sure you have internet connectivity
- Check if `dig` or `host` commands are available: `which dig host`
- Try running the test with verbose output (check script for debug mode)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - feel free to use this script in your projects.

## Author

Created for easy DNS management on Linux systems.

---

**Note**: This script requires root/sudo privileges to modify system DNS settings.

