#!/usr/bin/env bash
# infra-report-improved.sh - Universal infrastructure report for any Linux host
# Version: 5.1 - Fixed file output
# Works on: Oracle Cloud, local servers, Tailscale networks

set -euo pipefail

# ========== Configuration ==========
REPORT_VERSION="5.1-multi-host"
REPORT_TYPE="infrastructure-analysis"

# ========== Output Setup ==========
TS="$(date +%Y%m%d_%H%M%S)"
ISO_TIME="$(date -Iseconds)"
REPORT_FILE="./infra-report-${TS}.md"

# ========== Console Logging (to stderr) ==========
log_info() { echo "ℹ️  $1" >&2; }
log_success() { echo "✅ $1" >&2; }
log_warn() { echo "⚠️  $1" >&2; }
log_error() { echo "❌ $1" >&2; }

# ========== Helper Functions ==========
have() { command -v "$1" >/dev/null 2>&1; }
val_or() { [ -n "${1:-}" ] && printf "%s" "$1" || printf "%s" "$2"; }

json_escape() {
    local text="$1"
    text=$(echo "$text" | sed 's/\x1b\[[0-9;]*m//g')
    text=$(echo "$text" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr -d '\n\r')
    echo "$text"
}

detect_os() {
    local os="unknown"
    if [ -f /etc/os-release ]; then
        os=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown")
    elif [ -f /etc/alpine-release ]; then
        os="alpine"
    elif [ -f /etc/debian_version ]; then
        os="debian"
    elif [ -f /etc/redhat-release ]; then
        os="redhat"
    fi
    echo "$os"
}

# ========== Markdown Helpers ==========
H1() { echo ""; echo "# $1"; echo ""; }
H2() { echo ""; echo "## $1"; echo ""; }
H3() { echo ""; echo "### $1"; echo ""; }
KV() { echo "- **$1:** ${2:-unknown}"; }
APP() { echo "$*"; }
CODE() {
    local lang="${1:-}"
    shift || true
    local body="${*:-}"
    if [ -n "$(echo "$body" | tr -d '[:space:]')" ]; then
        {
            echo '```'"$lang"
            echo "$body"
            echo '```'
            echo
        }
    fi
}

# ========== Main Report Generation ==========
generate_report() {
    log_info "Starting infrastructure report generation..."
    
    # Header
    H1 "Infrastructure Report"
    KV "Generated" "$ISO_TIME"
    KV "Report Version" "$REPORT_VERSION"
    KV "Hostname" "$(hostname)"
    
    # System Information
    H2 "System Information"
    
    OS_TYPE=$(detect_os)
    KV "OS Type" "$OS_TYPE"
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        KV "OS Name" "${PRETTY_NAME:-unknown}"
        KV "OS Version" "${VERSION:-unknown}"
    fi
    
    KV "Kernel" "$(uname -r)"
    KV "Architecture" "$(uname -m)"
    KV "Uptime" "$(uptime -p 2>/dev/null || uptime)"
    
    # CPU Information
    H2 "CPU Information"
    
    if [ -f /proc/cpuinfo ]; then
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        CPU_CORES=$(grep -c "^processor" /proc/cpuinfo)
        KV "CPU Model" "$CPU_MODEL"
        KV "CPU Cores" "$CPU_CORES"
    fi
    
    # Memory Information
    H2 "Memory Information"
    
    if have free; then
        MEM_INFO=$(free -h | grep "^Mem:")
        MEM_TOTAL=$(echo "$MEM_INFO" | awk '{print $2}')
        MEM_USED=$(echo "$MEM_INFO" | awk '{print $3}')
        MEM_FREE=$(echo "$MEM_INFO" | awk '{print $4}')
        
        KV "Total Memory" "$MEM_TOTAL"
        KV "Used Memory" "$MEM_USED"
        KV "Free Memory" "$MEM_FREE"
    fi
    
    # Disk Information
    H2 "Disk Information"
    
    if have df; then
        H3 "Disk Usage"
        CODE "text" "$(df -h | grep -v "tmpfs\|devtmpfs")"
    fi
    
    # Network Information
    H2 "Network Information"
    
    H3 "Network Interfaces"
    if have ip; then
        CODE "text" "$(ip -br addr show)"
    elif have ifconfig; then
        CODE "text" "$(ifconfig)"
    fi
    
    H3 "Listening Ports"
    if have ss; then
        CODE "text" "$(ss -tulpn 2>/dev/null | head -20)"
    elif have netstat; then
        CODE "text" "$(netstat -tulpn 2>/dev/null | head -20)"
    fi
    
    # Docker Information
    if have docker; then
        H2 "Docker Information"
        
        DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
        KV "Docker Version" "$DOCKER_VERSION"
        
        H3 "Running Containers"
        CODE "text" "$(docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo 'No containers running')"
        
        H3 "Docker Images"
        CODE "text" "$(docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' 2>/dev/null || echo 'No images found')"
        
        H3 "Docker Networks"
        CODE "text" "$(docker network ls 2>/dev/null || echo 'No networks found')"
        
        H3 "Docker Volumes"
        CODE "text" "$(docker volume ls 2>/dev/null || echo 'No volumes found')"
    fi
    
    # Services Information
    H2 "System Services"
    
    if have systemctl; then
        H3 "Active Services"
        CODE "text" "$(systemctl list-units --type=service --state=running --no-pager | head -20)"
        
        H3 "Failed Services"
        FAILED=$(systemctl list-units --type=service --state=failed --no-pager)
        if [ -n "$(echo "$FAILED" | grep -v "0 loaded")" ]; then
            CODE "text" "$FAILED"
        else
            APP "No failed services ✓"
        fi
    fi
    
    # Process Information
    H2 "Top Processes (by CPU)"
    
    if have ps; then
        CODE "text" "$(ps aux --sort=-%cpu | head -11)"
    fi
    
    # Security Information
    H2 "Security Information"
    
    H3 "SSH Configuration"
    if [ -f /etc/ssh/sshd_config ]; then
        SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
        SSH_ROOT=$(grep "^PermitRootLogin " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "unknown")
        
        KV "SSH Port" "$SSH_PORT"
        KV "Root Login" "$SSH_ROOT"
    fi
    
    H3 "Firewall Status"
    if have ufw; then
        CODE "text" "$(sudo ufw status 2>/dev/null || echo 'UFW not active or no permission')"
    elif have firewall-cmd; then
        CODE "text" "$(sudo firewall-cmd --list-all 2>/dev/null || echo 'Firewalld not active or no permission')"
    fi
    
    # Installed Software
    H2 "Key Software"
    
    APP "Checking installed software..."
    echo ""
    
    check_software() {
        local name=$1
        local cmd=${2:-$1}
        if have "$cmd"; then
            local version=$(${cmd} --version 2>&1 | head -1 || echo "installed")
            KV "$name" "$version"
        fi
    }
    
    check_software "Git" "git"
    check_software "Node.js" "node"
    check_software "npm" "npm"
    check_software "Python" "python3"
    check_software "Docker" "docker"
    check_software "Docker Compose" "docker-compose"
    check_software "Nginx" "nginx"
    check_software "Apache" "apache2"
    
    # Footer
    echo ""
    echo "---"
    echo ""
    APP "*Report generated by infra-report.sh v${REPORT_VERSION}*"
    APP "*Time: ${ISO_TIME}*"
}

# ========== Main Execution ==========
main() {
    log_info "Report will be saved to: $REPORT_FILE"
    
    # Generate report and save to file
    generate_report > "$REPORT_FILE"
    
    log_success "Report generated successfully!"
    log_success "Saved to: $REPORT_FILE"
    
    # Show preview
    echo "" >&2
    log_info "Preview (first 30 lines):" >&2
    echo "" >&2
    head -30 "$REPORT_FILE" >&2
    echo "" >&2
    log_info "..." >&2
    echo "" >&2
    log_info "Full report: cat $REPORT_FILE" >&2
}

main "$@"