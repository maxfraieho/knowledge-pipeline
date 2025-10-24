#!/data/data/com.termux/files/usr/bin/bash
# infra-report-termux.sh - Infrastructure report for Termux/Android
# Version: 5.2-termux

set -euo pipefail

# ========== Configuration ==========
REPORT_VERSION="5.2-termux"
REPORT_TYPE="termux-infrastructure"

# ========== Output Setup ==========
TS="$(date +%Y%m%d_%H%M%S)"
ISO_TIME="$(date -Iseconds 2>/dev/null || date)"
REPORT_FILE="$HOME/infra-report-${TS}.md"

# ========== Console Logging ==========
log_info() { echo "ℹ️  $1" >&2; }
log_success() { echo "✅ $1" >&2; }
log_warn() { echo "⚠️  $1" >&2; }

# ========== Helper Functions ==========
have() { command -v "$1" >/dev/null 2>&1; }

# ========== Markdown Helpers ==========
H1() { echo ""; echo "# $1"; echo ""; }
H2() { echo ""; echo "## $1"; echo ""; }
H3() { echo "### $1"; echo ""; }
KV() { echo "- **$1:** ${2:-unknown}"; }
CODE() {
    local lang="${1:-text}"
    shift || true
    local body="${*:-}"
    if [ -n "$(echo "$body" | tr -d '[:space:]')" ]; then
        echo '```'"$lang"
        echo "$body"
        echo '```'
        echo
    fi
}

# ========== Main Report ==========
generate_report() {
    # Header
    H1 "Termux Infrastructure Report"
    KV "Generated" "$ISO_TIME"
    KV "Report Version" "$REPORT_VERSION"
    KV "Device" "$(getprop ro.product.model 2>/dev/null || echo 'Android Device')"
    KV "Android Version" "$(getprop ro.build.version.release 2>/dev/null || echo 'unknown')"
    
    # System Info
    H2 "System Information"
    KV "Termux Version" "$(termux-info 2>/dev/null | grep TERMUX_VERSION | cut -d= -f2 || echo 'unknown')"
    KV "Architecture" "$(uname -m)"
    KV "Kernel" "$(uname -r)"
    KV "Shell" "$SHELL"
    
    # Storage
    H2 "Storage Information"
    CODE "text" "$(df -h $HOME 2>/dev/null || df -h)"
    
    # Memory (if available)
    if have free; then
        H2 "Memory Information"
        CODE "text" "$(free -h 2>/dev/null || echo 'free command not available')"
    fi
    
    # Network
    H2 "Network Information"
    
    H3 "IP Addresses"
    if have ip; then
        CODE "text" "$(ip addr show 2>/dev/null | grep -E 'inet |inet6 ' || echo 'No IP info')"
    fi
    
    H3 "Active Connections"
    if have netstat; then
        CODE "text" "$(netstat -tuln 2>/dev/null | head -20 || echo 'netstat not available')"
    fi
    
    H3 "Current IP"
    if have curl; then
        CURRENT_IP=$(curl -s https://ipapi.co/json/ 2>/dev/null || echo '{}')
        CODE "json" "$CURRENT_IP"
    fi
    
    # Processes
    H2 "Running Processes"
    
    H3 "All Processes"
    CODE "text" "$(ps aux 2>/dev/null | head -20 || ps)"
    
    H3 "Python Processes"
    PYTHON_PROCS=$(ps aux | grep python | grep -v grep || echo "No Python processes")
    CODE "text" "$PYTHON_PROCS"
    
    H3 "SSH Processes"
    SSH_PROCS=$(ps aux | grep sshd | grep -v grep || echo "No SSH processes")
    CODE "text" "$SSH_PROCS"
    
    # Services
    H2 "Termux Services"
    
    if [ -d "$PREFIX/var/service" ]; then
        H3 "Active Services"
        CODE "text" "$(ls -la $PREFIX/var/service/ 2>/dev/null || echo 'No services')"
    fi
    
    # VPN Status
    if [ -f "$HOME/vpn/manager.sh" ]; then
        H2 "VPN Status"
        CODE "text" "$($HOME/vpn/manager.sh status 2>/dev/null || echo 'VPN manager not responding')"
    fi
    
    # Installed Software
    H2 "Installed Software"
    
    check_pkg() {
        local name=$1
        local cmd=${2:-$1}
        if have "$cmd"; then
            local ver=$(${cmd} --version 2>&1 | head -1 || echo "installed")
            KV "$name" "$ver"
        else
            KV "$name" "not installed"
        fi
    }
    
    check_pkg "Python" "python3"
    check_pkg "Node.js" "node"
    check_pkg "npm" "npm"
    check_pkg "Git" "git"
    check_pkg "OpenSSH" "sshd"
    check_pkg "curl" "curl"
    check_pkg "wget" "wget"
    check_pkg "tmux" "tmux"
    
    # Package Stats
    H2 "Package Statistics"
    if have pkg; then
        PKG_COUNT=$(pkg list-installed 2>/dev/null | wc -l || echo "unknown")
        KV "Installed Packages" "$PKG_COUNT"
    fi
    
    # Environment
    H2 "Environment Variables"
    CODE "bash" "$(env | grep -E 'PATH|HOME|PREFIX|TERMUX' | sort)"
    
    # Python Packages (if exists)
    if have pip; then
        H2 "Python Packages"
        CODE "text" "$(pip list 2>/dev/null | head -20 || echo 'pip not available')"
    fi
    
    # Boot Scripts
    if [ -d "$HOME/.termux/boot" ]; then
        H2 "Boot Scripts"
        CODE "text" "$(ls -lh $HOME/.termux/boot/ 2>/dev/null || echo 'No boot scripts')"
    fi
    
    # Footer
    echo ""
    echo "---"
    echo ""
    echo "*Report generated: ${ISO_TIME}*"
    echo "*Script version: ${REPORT_VERSION}*"
}

# ========== Main ==========
main() {
    log_info "Generating Termux infrastructure report..."
    log_info "Report file: $REPORT_FILE"
    
    generate_report > "$REPORT_FILE" 2>&1
    
    log_success "Report generated!"
    log_success "Location: $REPORT_FILE"
    
    # Preview
    echo "" >&2
    log_info "Preview:" >&2
    echo "" >&2
    head -40 "$REPORT_FILE" >&2
    echo "" >&2
    log_info "Full report: cat $REPORT_FILE" >&2
}

main "$@"