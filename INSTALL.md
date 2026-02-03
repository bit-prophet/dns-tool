# Quick Installation Guide

## Method 1: One-Line Install (Easiest)

```bash
curl -sSL https://raw.githubusercontent.com/bit-prophet/dns-tool/main/dns-tool.sh | sudo bash -s install
```

## Method 2: Clone and Install

```bash
# Clone the repository
git clone https://github.com/bit-prophet/dns-tool.git
cd dns-tool

# Install using the script's built-in installer
sudo ./dns-tool.sh install

# Or use the separate install script
sudo ./install.sh
```

## Method 3: Manual Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/bit-prophet/dns-tool/main/dns-tool.sh

# Make executable
chmod +x dns-tool.sh

# Copy to system
sudo cp dns-tool.sh /usr/local/bin/dns-tool
sudo chmod +x /usr/local/bin/dns-tool
```

## Usage

After installation, simply run:

```bash
sudo dns-tool
```

Choose option **9** to test all DNS servers and automatically select the fastest one!

## Uninstall

```bash
sudo rm /usr/local/bin/dns-tool
```

