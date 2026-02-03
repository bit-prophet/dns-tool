#!/bin/bash

# Installation script for dns-tool
# This script installs the dns-tool command to /usr/local/bin

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="dns-tool.sh"
INSTALL_DIR="/usr/local/bin"
INSTALL_NAME="dns-tool"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  DNS Configuration Tool Installer"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    echo "Usage: sudo ./install.sh"
    exit 1
fi

# Check if script exists
if [ ! -f "$SCRIPT_DIR/$SCRIPT_NAME" ]; then
    echo -e "${RED}Error: $SCRIPT_NAME not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Check if already installed
if [ -f "$INSTALL_DIR/$INSTALL_NAME" ]; then
    echo -e "${YELLOW}Warning: $INSTALL_NAME is already installed at $INSTALL_DIR/$INSTALL_NAME${NC}"
    read -p "Do you want to overwrite it? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

# Install the script
echo "Installing $INSTALL_NAME to $INSTALL_DIR..."
cp "$SCRIPT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$INSTALL_NAME"
chmod +x "$INSTALL_DIR/$INSTALL_NAME"

# Verify installation
if [ -f "$INSTALL_DIR/$INSTALL_NAME" ] && [ -x "$INSTALL_DIR/$INSTALL_NAME" ]; then
    echo -e "${GREEN}✓ Successfully installed $INSTALL_NAME${NC}"
    echo ""
    echo "You can now use the command:"
    echo -e "  ${GREEN}sudo $INSTALL_NAME${NC}"
    echo ""
    
    # Ask if user wants to run it now
    read -p "Would you like to run $INSTALL_NAME now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "=========================================="
        echo ""
        # Run the installed script
        "$INSTALL_DIR/$INSTALL_NAME"
    else
        echo ""
        echo "To test all DNS servers and choose the best one:"
        echo -e "  ${GREEN}sudo $INSTALL_NAME${NC}"
        echo "  (Then select option 9)"
    fi
else
    echo -e "${RED}✗ Installation failed${NC}"
    exit 1
fi

echo ""
echo "=========================================="

