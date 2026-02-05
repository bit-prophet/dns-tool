#!/bin/bash

# DNS Configuration Script
# Provides a menu to select and set DNS servers

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# DNS server configurations (ordered by popularity)
declare -A DNS_SERVERS
DNS_SERVERS[1_name]="Google"
DNS_SERVERS[1_primary]="8.8.8.8"
DNS_SERVERS[1_secondary]="8.8.4.4"

DNS_SERVERS[2_name]="Cloudflare"
DNS_SERVERS[2_primary]="1.1.1.1"
DNS_SERVERS[2_secondary]="1.0.0.1"

DNS_SERVERS[3_name]="OpenDNS"
DNS_SERVERS[3_primary]="208.67.222.222"
DNS_SERVERS[3_secondary]="208.67.220.220"

DNS_SERVERS[4_name]="Quad9"
DNS_SERVERS[4_primary]="9.9.9.9"
DNS_SERVERS[4_secondary]="149.112.112.112"

DNS_SERVERS[5_name]="AdGuard"
DNS_SERVERS[5_primary]="94.140.14.14"
DNS_SERVERS[5_secondary]="94.140.15.15"

DNS_SERVERS[6_name]="Shecan Free"
DNS_SERVERS[6_primary]="178.22.122.100"
DNS_SERVERS[6_secondary]="185.51.200.2"

DNS_SERVERS[7_name]="Shecan Pro"
DNS_SERVERS[7_primary]="178.22.122.101"
DNS_SERVERS[7_secondary]="185.51.200.1"

# Function to display menu
show_menu() {
    clear
    echo "=========================================="
    echo "      DNS Server Configuration"
    echo "=========================================="
    echo ""
    echo "Please select a DNS server:"
    echo "  0) Test all DNS servers (choose best)"
    echo "  1) Google"
    echo "  2) Cloudflare"
    echo "  3) OpenDNS"
    echo "  4) Quad9"
    echo "  5) AdGuard"
    echo "  6) Shecan Free"
    echo "  7) Shecan Pro"
    echo "  8) Automatic (None)"
    echo ""
}

# Function to set DNS using systemd-resolved
set_dns_systemd() {
    local primary=$1
    local secondary=$2
    local dns_name=$3
    
    if [ -z "$primary" ]; then
        # Reset to automatic - remove custom DNS config
        rm -f /etc/systemd/resolved.conf.d/custom-dns.conf
        systemctl restart systemd-resolved 2>/dev/null || true
        echo -e "${GREEN}Default DNS restored via systemd-resolved${NC}"
    else
        # Create systemd-resolved config directory
        mkdir -p /etc/systemd/resolved.conf.d
        
        # Create custom DNS config
        cat > /etc/systemd/resolved.conf.d/custom-dns.conf <<EOF
[Resolve]
DNS=$primary $secondary
Domains=~.
EOF
        systemctl restart systemd-resolved 2>/dev/null || true
        echo -e "${GREEN}$dns_name DNS enabled via systemd-resolved${NC}"
    fi
    
    # Verify
    sleep 1
    if [ -n "$primary" ]; then
        # Use portable sed instead of grep -oP (Perl regex not available on all systems)
        current_dns=$(resolvectl dns 2>/dev/null | sed -n 's/.*DNS Servers: //p' | head -n1)
        if [ -n "$current_dns" ]; then
            echo -e "${GREEN}✓ $dns_name DNS is now active${NC}"
            echo "Current DNS: $current_dns"
        fi
    fi
}

# Function to set DNS using NetworkManager
set_dns_nmcli() {
    local primary=$1
    local secondary=$2
    local dns_name=$3
    
    # Get active connection
    local connection=$(nmcli -t -f NAME connection show --active | head -n1)
    
    if [ -z "$connection" ]; then
        echo -e "${RED}Error: No active network connection found${NC}"
        return 1
    fi
    
    if [ -z "$primary" ]; then
        # Reset to automatic
        nmcli connection modify "$connection" ipv4.dns "" 2>/dev/null
        nmcli connection modify "$connection" ipv4.ignore-auto-dns no 2>/dev/null
        nmcli connection up "$connection" > /dev/null 2>&1
        echo -e "${GREEN}Default DNS restored via NetworkManager${NC}"
    else
        nmcli connection modify "$connection" ipv4.dns "$primary,$secondary" 2>/dev/null
        nmcli connection modify "$connection" ipv4.ignore-auto-dns yes 2>/dev/null
        nmcli connection up "$connection" > /dev/null 2>&1
        echo -e "${GREEN}$dns_name DNS enabled via NetworkManager${NC}"
        echo "Current DNS: $primary $secondary"
    fi
}

# Function to set DNS using resolvconf utility
set_dns_resolvconf_util() {
    local primary=$1
    local secondary=$2
    local dns_name=$3
    
    if [ -z "$primary" ]; then
        # Reset to automatic
        echo "" | resolvconf -a eth0 2>/dev/null || true
        echo -e "${GREEN}Default DNS restored via resolvconf${NC}"
    else
        # Set DNS using resolvconf
        {
            echo "nameserver $primary"
            echo "nameserver $secondary"
        } | resolvconf -a eth0 2>/dev/null || {
            echo "nameserver $primary" | resolvconf -a lo 2>/dev/null || true
            echo "nameserver $secondary" | resolvconf -a lo 2>/dev/null || true
        }
        echo -e "${GREEN}$dns_name DNS enabled via resolvconf${NC}"
        echo "Current DNS: $primary $secondary"
    fi
}

# Function to set DNS using netplan (Ubuntu)
set_dns_netplan() {
    local primary=$1
    local secondary=$2
    local dns_name=$3
    local netplan_dir="/etc/netplan"
    local netplan_file=""
    
    # Find netplan config file
    if [ -d "$netplan_dir" ]; then
        netplan_file=$(ls "$netplan_dir"/*.yaml 2>/dev/null | head -n1)
    fi
    
    if [ -z "$netplan_file" ] || [ ! -f "$netplan_file" ]; then
        echo -e "${YELLOW}Warning: No netplan configuration found${NC}"
        return 1
    fi
    
    # Backup netplan file
    if [ ! -f "${netplan_file}.backup" ]; then
        cp "$netplan_file" "${netplan_file}.backup"
    fi
    
    if [ -z "$primary" ]; then
        # Reset to automatic - restore from backup
        if [ -f "${netplan_file}.backup" ]; then
            cp "${netplan_file}.backup" "$netplan_file"
            netplan apply 2>/dev/null || true
            echo -e "${GREEN}Default DNS restored via netplan${NC}"
        fi
    else
        # Try using netplan set command if available (Ubuntu 18.04+)
        if command -v netplan &> /dev/null; then
            # Get interface name from netplan file
            local interface=$(grep -E "^[[:space:]]*[a-z0-9]+:" "$netplan_file" | head -n1 | sed 's/[[:space:]]*\([^:]*\):.*/\1/')
            if [ -n "$interface" ] && [ "$interface" != "network" ]; then
                # Try to set DNS using netplan set (if supported)
                netplan set network.ethernets."$interface".nameservers.addresses="[$primary,$secondary]" 2>/dev/null
                if [ $? -eq 0 ]; then
                    netplan apply 2>/dev/null || true
                    echo -e "${GREEN}$dns_name DNS enabled via netplan${NC}"
                    echo "Current DNS: $primary $secondary"
                    return 0
                fi
            fi
        fi
        
        # Fallback: Provide instructions for manual editing
        echo -e "${YELLOW}Note: Automatic netplan modification requires netplan set command${NC}"
        echo -e "${YELLOW}Please manually edit $netplan_file and add under your interface:${NC}"
        echo "  nameservers:"
        echo "    addresses: [$primary, $secondary]"
        echo "Then run: ${GREEN}sudo netplan apply${NC}"
        echo ""
        echo -e "${BLUE}Attempting fallback method...${NC}"
        return 1
    fi
}

# Function to set DNS using resolv.conf (fallback)
set_dns_resolvconf() {
    local primary=$1
    local secondary=$2
    local dns_name=$3
    local backup_file="/tmp/resolv.conf.backup"
    local resolv_conf="/etc/resolv.conf"
    
    # Check if resolv.conf is a symlink (common on modern systems)
    if [ -L "$resolv_conf" ]; then
        echo -e "${YELLOW}Warning: /etc/resolv.conf is a symlink. Changes may be overwritten.${NC}"
    fi
    
    # Backup original resolv.conf if not already backed up
    if [ ! -f "$backup_file" ] && [ -f "$resolv_conf" ]; then
        cp "$resolv_conf" "$backup_file"
    fi
    
    if [ -z "$primary" ]; then
        # Reset to automatic - restore from backup if exists
        if [ -f "$backup_file" ]; then
            cp "$backup_file" "$resolv_conf"
            echo -e "${GREEN}Default DNS restored from backup${NC}"
        else
            # Remove custom DNS entries
            sed -i '/^nameserver/d' "$resolv_conf" 2>/dev/null || true
            echo -e "${GREEN}Default DNS restored${NC}"
        fi
    else
        # Remove existing nameserver entries
        sed -i '/^nameserver/d' "$resolv_conf" 2>/dev/null || true
        # Add new DNS servers
        echo "nameserver $primary" >> "$resolv_conf"
        echo "nameserver $secondary" >> "$resolv_conf"
        echo -e "${GREEN}$dns_name DNS enabled via resolv.conf${NC}"
    fi
    
    # Verify
    sleep 1
    current_dns=$(grep "^nameserver" "$resolv_conf" 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    if [ -n "$current_dns" ]; then
        echo -e "${GREEN}✓ DNS is now active${NC}"
        echo "Current DNS: $current_dns"
    fi
}

# Main function to set DNS
set_dns() {
    local primary=$1
    local secondary=$2
    local dns_name=$3
    
    # Try systemd-resolved first (systemd-based distros: Ubuntu, Debian, Fedora, Arch, etc.)
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        set_dns_systemd "$primary" "$secondary" "$dns_name"
    # Try NetworkManager (most modern Linux distributions)
    elif command -v nmcli &> /dev/null && nmcli -t -f NAME connection show --active | head -n1 | grep -q .; then
        set_dns_nmcli "$primary" "$secondary" "$dns_name"
    # Try netplan (Ubuntu 18.04+)
    elif [ -d "/etc/netplan" ] && ls /etc/netplan/*.yaml 2>/dev/null | grep -q .; then
        set_dns_netplan "$primary" "$secondary" "$dns_name" || set_dns_resolvconf "$primary" "$secondary" "$dns_name"
    # Try resolvconf utility (older Debian/Ubuntu systems)
    elif command -v resolvconf &> /dev/null; then
        set_dns_resolvconf_util "$primary" "$secondary" "$dns_name" || set_dns_resolvconf "$primary" "$secondary" "$dns_name"
    # Fallback to direct resolv.conf modification
    else
        set_dns_resolvconf "$primary" "$secondary" "$dns_name"
    fi
}

# Function to test DNS server response time
test_dns_server() {
    local dns_ip=$1
    local test_domain="github.com"
    local total_time=0
    local successful_tests=0
    local test_count=3
    
    # Test using dig if available (most accurate for DNS resolution time)
    if command -v dig &> /dev/null; then
        # Check if timeout command is available
        local timeout_cmd=""
        if command -v timeout &> /dev/null; then
            timeout_cmd="timeout 5"
        fi
        
        for ((i=1; i<=test_count; i++)); do
            # Use dig to query DNS server directly and measure query time
            # Use +noall +stats to get stats without the answer section
            # +time=3 sets the query timeout to 3 seconds
            local dig_output=$($timeout_cmd dig @"$dns_ip" "$test_domain" +noall +stats +time=3 +tries=1 2>&1)
            
            # Extract query time (format: ";; Query time: 32 msec")
            # Look for the number before "msec"
            local query_time=$(echo "$dig_output" | grep -i "Query time:" | sed 's/.*Query time: *\([0-9]*\).*/\1/' | head -n1)
            
            # Also check if the query was successful (should have SERVER line)
            local server_line=$(echo "$dig_output" | grep -i "SERVER:")
            
            # Validate the extracted time is a valid number
            if [ -n "$query_time" ] && [ -n "$server_line" ]; then
                # Check if query_time is a valid positive integer
                if [[ "$query_time" =~ ^[0-9]+$ ]] && [ "$query_time" -gt 0 ] && [ "$query_time" -lt 10000 ]; then
                    total_time=$((total_time + query_time))
                    successful_tests=$((successful_tests + 1))
                fi
            fi
            sleep 0.3
        done
        
        if [ $successful_tests -gt 0 ]; then
            local avg_time=$((total_time / successful_tests))
            echo "$avg_time"
        else
            echo "9999"
        fi
    # Fallback: test DNS resolution + ping to github.com
    elif command -v host &> /dev/null && command -v ping &> /dev/null; then
        # Resolve github.com using the specific DNS server
        # host command syntax: host domain dns_server
        local host_output=$(host -W 3 -T "$test_domain" "$dns_ip" 2>&1)
        local resolved_ip=$(echo "$host_output" | grep -oE 'has address [0-9.]+' | grep -oE '[0-9.]+' | head -n1)
        
        if [ -n "$resolved_ip" ]; then
            # Ping the resolved IP multiple times and get average
            local ping_output=$(ping -c 3 -W 3 "$resolved_ip" 2>/dev/null)
            local avg_ping=$(echo "$ping_output" | grep -oE 'min/avg/max/[^=]+= [0-9.]+' | grep -oE '[0-9.]+' | tail -n1)
            
            if [ -n "$avg_ping" ]; then
                # Convert to integer milliseconds using awk (more portable than bc)
                local ms_time=$(awk "BEGIN {printf \"%.0f\", $avg_ping * 1000}")
                echo "$ms_time"
            else
                echo "9999"
            fi
        else
            echo "9999"
        fi
    # Last resort: simple connectivity test - ping the DNS server itself
    elif command -v ping &> /dev/null; then
        # Try to ping the DNS server itself to test connectivity
        local ping_output=$(ping -c 2 -W 2 "$dns_ip" 2>/dev/null)
        local avg_ping=$(echo "$ping_output" | grep -oE 'min/avg/max/[^=]+= [0-9.]+' | grep -oE '[0-9.]+' | tail -n1)
        
        if [ -n "$avg_ping" ]; then
            # Convert to integer milliseconds
            local ms_time=$(awk "BEGIN {printf \"%.0f\", $avg_ping * 1000}")
            echo "$ms_time"
        else
            echo "9999"
        fi
    else
        echo "9999"
    fi
}

# Function to test all DNS servers and find the best one
test_all_dns() {
    echo ""
    echo "=========================================="
    echo "  Testing DNS Servers..."
    echo "=========================================="
    echo ""
    echo -e "${YELLOW}Testing DNS servers by pinging github.com...${NC}"
    echo "This may take a few moments..."
    echo ""
    
    local best_time=9999
    local best_option=0
    local best_name=""
    local results=()
    
    # Test each DNS server (options 1-7)
    for i in 1 2 3 4 5 6 7; do
        local dns_name="${DNS_SERVERS[${i}_name]}"
        local dns_primary="${DNS_SERVERS[${i}_primary]}"
        
        echo -n "Testing ${dns_name} (${dns_primary})... "
        
        # Test the primary DNS server
        local response_time=$(test_dns_server "$dns_primary")
        
        if [ "$response_time" = "9999" ] || [ -z "$response_time" ]; then
            echo -e "${RED}Failed${NC}"
            results+=("$i|$dns_name|$dns_primary|Failed")
        else
            echo -e "${GREEN}${response_time}ms${NC}"
            results+=("$i|$dns_name|$dns_primary|$response_time")
            
            # Check if this is the best so far
            if [ "$response_time" -lt "$best_time" ]; then
                best_time=$response_time
                best_option=$i
                best_name="$dns_name"
            fi
        fi
        
        # Small delay between tests
        sleep 0.5
    done
    
    echo ""
    echo "=========================================="
    echo "  Test Results Summary"
    echo "=========================================="
    echo ""
    
    # Display results sorted by time
    printf "%-20s %-20s %-10s\n" "DNS Server" "IP Address" "Response Time"
    echo "------------------------------------------------------------"
    
    for result in "${results[@]}"; do
        IFS='|' read -r option name ip time <<< "$result"
        if [ "$time" = "Failed" ]; then
            printf "%-20s %-20s ${RED}%-10s${NC}\n" "$name" "$ip" "$time"
        else
            if [ "$option" = "$best_option" ]; then
                printf "${GREEN}%-20s %-20s %-10sms${NC} ⭐\n" "$name" "$ip" "$time"
            else
                printf "%-20s %-20s %-10sms\n" "$name" "$ip" "$time"
            fi
        fi
    done
    
    echo ""
    echo "=========================================="
    
    if [ "$best_option" -gt 0 ]; then
        echo -e "\n${GREEN}Best DNS Server: $best_name (${DNS_SERVERS[${best_option}_primary]})${NC}"
        echo -e "Response Time: ${GREEN}${best_time}ms${NC}"
        echo ""
        read -p "Do you want to set this DNS server? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            local primary="${DNS_SERVERS[${best_option}_primary]}"
            local secondary="${DNS_SERVERS[${best_option}_secondary]}"
            local name="${DNS_SERVERS[${best_option}_name]}"
            set_dns "$primary" "$secondary" "$name"
            echo ""
            echo "=========================================="
        else
            echo "DNS not changed."
        fi
    else
        echo -e "\n${RED}Error: Could not test DNS servers properly.${NC}"
    fi
}

# Function to install the script
install_script() {
    local script_path="$0"
    local install_dir="/usr/local/bin"
    local install_name="dns-tool"
    
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Error: Installation requires root privileges (use sudo)${NC}"
        echo "Usage: sudo $0 install"
        exit 1
    fi
    
    echo "=========================================="
    echo "  Installing DNS Configuration Tool"
    echo "=========================================="
    echo ""
    
    # Check if already installed
    if [ -f "$install_dir/$install_name" ]; then
        echo -e "${YELLOW}Warning: $install_name is already installed${NC}"
        read -p "Do you want to overwrite it? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi
    fi
    
    # Install
    cp "$script_path" "$install_dir/$install_name"
    chmod +x "$install_dir/$install_name"
    
    if [ -f "$install_dir/$install_name" ] && [ -x "$install_dir/$install_name" ]; then
        echo -e "${GREEN}✓ Successfully installed $install_name${NC}"
        echo ""
        echo "You can now use: ${GREEN}sudo $install_name${NC}"
        echo ""
    else
        echo -e "${RED}✗ Installation failed${NC}"
        exit 1
    fi
    
    echo "=========================================="
}

# Check for install argument
if [ "$1" = "install" ]; then
    install_script
    exit 0
fi

# Main script
show_menu
read -p "Enter your choice (0-8): " choice

case $choice in
    0)
        test_all_dns
        exit 0
        ;;
    1)
        set_dns "${DNS_SERVERS[1_primary]}" "${DNS_SERVERS[1_secondary]}" "${DNS_SERVERS[1_name]}"
        ;;
    2)
        set_dns "${DNS_SERVERS[2_primary]}" "${DNS_SERVERS[2_secondary]}" "${DNS_SERVERS[2_name]}"
        ;;
    3)
        set_dns "${DNS_SERVERS[3_primary]}" "${DNS_SERVERS[3_secondary]}" "${DNS_SERVERS[3_name]}"
        ;;
    4)
        set_dns "${DNS_SERVERS[4_primary]}" "${DNS_SERVERS[4_secondary]}" "${DNS_SERVERS[4_name]}"
        ;;
    5)
        set_dns "${DNS_SERVERS[5_primary]}" "${DNS_SERVERS[5_secondary]}" "${DNS_SERVERS[5_name]}"
        ;;
    6)
        set_dns "${DNS_SERVERS[6_primary]}" "${DNS_SERVERS[6_secondary]}" "${DNS_SERVERS[6_name]}"
        ;;
    7)
        set_dns "${DNS_SERVERS[7_primary]}" "${DNS_SERVERS[7_secondary]}" "${DNS_SERVERS[7_name]}"
        ;;
    8)
        set_dns "" "" "Automatic"
        ;;
    *)
        echo -e "${RED}Invalid choice. Please select a number between 0 and 8.${NC}"
        exit 1
        ;;
esac

echo ""
echo "=========================================="

