#!/usr/bin/env bash
# infra-report-improved.sh - Universal infrastructure report for any Linux host
# Version: 5.0 - Multi-host SSH and Role Detection
# Works on: Oracle Cloud, local servers, Tailscale networks

set -euo pipefail

# ========== Configuration ==========
REPORT_VERSION="5.0-multi-host"
REPORT_TYPE="infrastructure-analysis"

# ========== Output Setup ==========
TS="$(date +%Y%m%d_%H%M%S)"
ISO_TIME="$(date -Iseconds)"
# In remote mode, these files are created on the remote host, but the primary output is stdout.
REPORT_FILE="./infra-report-${TS}.md"
JSON_FILE="./infra-report-${TS}.json"

# ========== Console Logging (to stderr to avoid JSON pollution) ==========
log_info() { echo "ℹ️ $1" >&2; }
log_success() { echo "✅ $1" >&2; }
log_warn() { echo "⚠️ $1" >&2; }
log_error() { echo "❌ $1" >&2; }

# ========== Helper Functions ==========
have() { command -v "$1" >/dev/null 2>&1; }
val_or() { [ -n "${1:-}" ] && printf "%s" "$1" || printf "%s" "$2"; }

json_escape() {
    local text="$1"
    # Remove ANSI color codes and escape JSON special chars
    text=$(echo "$text" | sed 's/\x1b\[[0-9;]*m//g')
    text=$(echo "$text" | sed 's/\\/\\\\/g; s/"/\"/g; s/ /\t/g' | tr -d '\n\r')
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

# ========== Markdown Helpers (now output to stdout) ==========
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
            echo '```'"$lang""
            echo "$body"
            echo '```'
            echo
        }
    fi
}

# ========== System Detection ==========
collect_system_info() {
    local hostname=$(hostname)
    local kernel=$(uname -r)
    local arch=$(uname -m)
    local os=$(detect_os)
    local os_version=""
    if [ -f /etc/os-release ]; then
        os_version=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
    fi
    local uptime_str=$(uptime -p 2>/dev/null || uptime | sed 's/^ *//')
    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    # Memory info
    local mem_total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
    local mem_free_kb=$(awk '/MemFree/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
    local mem_available_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
    local swap_total_kb=$(awk '/SwapTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
    local swap_free_kb=$(awk '/SwapFree/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
    # Disk info
    local disk_line=$(df -h / 2>/dev/null | tail -1)
    local disk_usage=$(echo "$disk_line" | awk '{print $5}' | tr -d '%')
    local disk_available=$(echo "$disk_line" | awk '{print $4}')
    # Network info
    local internal_ip="unknown"
    if have ip;
        internal_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || echo "unknown")
    fi
    local external_ip="unknown"
    if have curl;
        external_ip=$(timeout 2 curl -fsS ifconfig.me 2>/dev/null || echo "unknown")
    elif have wget;
        external_ip=$(timeout 2 wget -qO- ifconfig.me 2>/dev/null || echo "unknown")
    fi
    # Cloud detection
    local cloud_provider="unknown"
    local instance_type="unknown"
    if have curl && have timeout;
        if timeout 1 curl -fsS http://169.254.169.254/opc/v2/instance/ -H "Authorization: Bearer Oracle" >/dev/null 2>&1;
            cloud_provider="Oracle Cloud"
            instance_type=$(timeout 1 curl -fsS http://169.254.169.254/opc/v2/instance/shape -H "Authorization: Bearer Oracle" 2>/dev/null || echo "unknown")
        elif timeout 1 curl -fsS http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1;
            cloud_provider="AWS"
        fi
    fi
    # Create JSON
    cat <<EOF
{
    "hostname": "$(json_escape "$hostname")",
    "os": "$(json_escape "$os")",
    "os_version": "$(json_escape "$os_version")",
    "kernel": "$(json_escape "$kernel")",
    "arch": "$(json_escape "$arch")",
    "uptime": "$(json_escape "$uptime_str")",
    "cpu_cores": $cpu_cores,
    "memory": {
        "total_kb": $mem_total_kb,
        "free_kb": $mem_free_kb,
        "available_kb": $mem_available_kb,
        "swap_total_kb": $swap_total_kb,
        "swap_free_kb": $swap_free_kb
    },
    "disk": {
        "usage_percent": $disk_usage,
        "available": "$(json_escape "$disk_available")"
    },
    "network": {
        "internal_ip": "$(json_escape "$internal_ip")",
        "external_ip": "$(json_escape "$external_ip")"
    },
    "cloud": {
        "provider": "$(json_escape "$cloud_provider")",
        "instance_type": "$(json_escape "$instance_type")"
    }
}
EOF
}

# ========== Docker Analysis ==========
analyze_docker() {
    local docker_info='{"installed": false}"
    if ! have docker;
        echo "$docker_info"
        return
    fi
    local docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo "unknown")
    local daemon_running="false"
    local container_count=0
    local containers='[]'
    if docker info >/dev/null 2>&1;
        daemon_running="true"
        container_count=$(docker ps -q 2>/dev/null | wc -l)
        # Get container details
        if [ "$container_count" -gt 0 ];
            containers=$(docker ps --format '{"name":"{{.Names}}","status":"{{.Status}}","image":"{{.Image}}"}' 2>/dev/null |
                awk 'BEGIN{print "["} {print $0",} END{print "null]"}' | sed 's/,null]/]/'
        fi
    fi
    # Compose detection
    local compose_version="not_found"
    local compose_command=""
    if docker compose version >/dev/null 2>&1;
        compose_version=$(docker compose version --short 2>/dev/null || echo "2.x")
        compose_command="docker compose"
    elif have docker-compose;
        compose_version=$(docker-compose --version 2>/dev/null | awk '{print $4}' | tr -d ',' || echo "1.x")
        compose_command="docker-compose"
    fi
    cat <<EOF
{
    "installed": true,
    "version": "$(json_escape "$docker_version")",
    "daemon_running": $daemon_running,
    "container_count": $container_count,
    "compose": {
        "version": "$(json_escape "$compose_version")",
        "command": "$(json_escape "$compose_command")"
    },
    "containers": $containers
}
EOF
}

# ========== Application Stack Analysis ==========
analyze_applications() {
    local n8n_status="not_found"
    local postgres_status="not_found"
    local cloudflared_status="not_found"
    local tailscale_status="not_found"
    local tailscale_ip=""
    local portainer_status="not_found"
    # Check Docker containers
    if have docker && docker info >/dev/null 2>&1;
        # N8N
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -qE '(^|[_-])n8n($|[_-])';
            n8n_status="running"
            # Check API
            if curl -sf http://localhost:5678/healthz >/dev/null 2>&1;
                n8n_status="running_healthy"
            fi
        fi
        # PostgreSQL
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi postgres;
            postgres_status="running"
        fi
        # Portainer
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi portainer;
            portainer_status="running"
        fi
    fi
    # Cloudflared
    if have systemctl;
        if systemctl is-active cloudflared >/dev/null 2>&1;
            cloudflared_status="active"
        elif systemctl is-enabled cloudflared >/dev/null 2>&1;
            cloudflared_status="enabled_not_active"
        fi
    fi
    # Tailscale
    if have tailscale;
        if tailscale status >/dev/null 2>&1;
            tailscale_status="connected"
            tailscale_ip=$(tailscale ip -4 2>/dev/null || echo "")
        else
            tailscale_status="installed_not_connected"
        fi
    fi
    cat <<EOF
{
    "n8n": "$(json_escape "$n8n_status")",
    "postgres": "$(json_escape "$postgres_status")",
    "cloudflared": "$(json_escape "$cloudflared_status")",
    "tailscale": "$(json_escape "$tailscale_status")",
    "tailscale_ip": "$(json_escape "$tailscale_ip")",
    "portainer": "$(json_escape "$portainer_status")"
}
EOF
}

# ========== Compose Files Discovery ==========
discover_compose_files() {
    local roots=()
    # Add common locations
    [ -d "$HOME" ] && roots+=("$HOME")
    [ -d "/opt" ] && roots+=("/opt")
    [ -d "/srv" ] && roots+=("/srv")
    if [ ${#roots[@]} -eq 0 ];
        echo "[]"
        return
    fi
    local files=$(find "${roots[@]}" -maxdepth 4 -type f \
        \( -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "compose.yml" -o -name "compose.yaml" \)
        2>/dev/null | head -20 || true)
    if [ -z "$files" ];
        echo "[]"
    else
        echo "$files" | awk 'BEGIN{print "["} {printf "\"%s\",", $0} END{print "null]"}' | sed 's/,null]/]/'
    fi
}

# ========== NEW: Pipeline Role Detection ==========
determine_pipeline_role() {
    local apps_json="$1"
    local docker_json="$2"
    local role="Невідома / Базова Інфраструктура"

    # Check for N8N (Orchestrator)
    local n8n_status=$(echo "$apps_json" | grep -o '"n8n": *"[^"]*"' | cut -d'"' -f4)
    if [[ "$n8n_status" == "running" || "$n8n_status" == "running_healthy" ]];
        role="Оркестратор (n8n)"
        echo "$role"
        return
    fi

    # Check for MinIO (Storage)
    if echo "$docker_json" | grep -q '"image":"[^\"]*minio';
        role="Сховище (MinIO)"
        echo "$role"
        return
    fi
    
    # Fallback for Model server - if no other specific role is found
    # This logic can be improved if a specific model container name is known
    local is_docker_running=$(echo "$docker_json" | grep -o '"daemon_running": *[a-z]*' | awk '{print $2}')
    if [[ "$is_docker_running" == "true" ]];
         # Assuming if Docker is running but it's not n8n or minio, it might be the model
         role="Модель (Llama.cpp/AI)"
    fi

    echo "$role"
}


# ========== Main Report Generation ==========
generate_report() {
    # Collect all data to variables first
    local system_json=$(collect_system_info)
    local docker_json=$(analyze_docker)
    local apps_json=$(analyze_applications)
    local compose_files=$(discover_compose_files)
    local pipeline_role=$(determine_pipeline_role "$apps_json" "$docker_json")

    # Generate combined JSON and save to file
    cat > "$JSON_FILE" <<EOF
{
    "version": "$REPORT_VERSION",
    "timestamp": "$ISO_TIME",
    "system": $system_json,
    "docker": $docker_json,
    "applications": $apps_json,
    "compose_files": $compose_files,
    "pipeline_role": "$(json_escape "$pipeline_role")"
}
EOF

    # Generate Markdown report to stdout
    H1 "🌐 Infrastructure Report"
    KV "Version" "$REPORT_VERSION"
    KV "Generated" "$ISO_TIME"
    
    # System section
    H2 "📋 System Information"
    local hostname=$(echo "$system_json" | grep -o '"hostname": *"[^"]*"' | cut -d'"' -f4)
    local os=$(echo "$system_json" | grep -o '"os": *"[^"]*"' | cut -d'"' -f4)
    local kernel=$(echo "$system_json" | grep -o '"kernel": *"[^"]*"' | cut -d'"' -f4)
    local cpu_cores=$(echo "$system_json" | grep -o '"cpu_cores": *[0-9]*' | awk '{print $2}')
    local uptime=$(echo "$system_json" | grep -o '"uptime": *"[^"]*"' | cut -d'"' -f4)
    KV "Hostname" "$hostname"
    KV "OS" "$os"
    KV "Kernel" "$kernel"
    KV "CPU Cores" "$cpu_cores"
    KV "Uptime" "$uptime"

    # Pipeline Role Section
    H2 "🚀 Knowledge Pipeline Role"
    KV "Detected Role" "$pipeline_role"

    # Memory section
    H2 "💾 Memory & Swap"
    CODE "" "$(free -h 2>/dev/null || echo 'free command not available')"
    if have swapon && [ -r /proc/swaps ];
        local swap_info=$(swapon --show 2>/dev/null || cat /proc/swaps 2>/dev/null)
        if [ -n "$swap_info" ];
            CODE "" "$swap_info"
        else
            APP "> No swap configured"
        fi
    else
        APP "> Swap information not available (need sudo or /proc/swaps access)"
    fi

    # Disk section
    H2 "💿 Disk Usage"
    CODE "" "$(df -h 2>/dev/null | head -20)"

    # Docker section
    H2 "🐳 Docker"
    local docker_installed=$(echo "$docker_json" | grep -o '"installed": *[a-z]*' | awk '{print $2}')
    if [ "$docker_installed" = "true" ];
        local docker_version=$(echo "$docker_json" | grep -o '"version": *"[^"]*"' | cut -d'"' -f4)
        local daemon_running=$(echo "$docker_json" | grep -o '"daemon_running": *[a-z]*' | awk '{print $2}')
        local container_count=$(echo "$docker_json" | grep -o '"container_count": *[0-9]*' | awk '{print $2}')
        KV "Docker Version" "$docker_version"
        KV "Daemon Status" "$([ "$daemon_running" = "true" ] && echo "Running ✅" || echo "Not running ❌")"
        KV "Containers" "$container_count"
        if [ "$daemon_running" = "true" ] && [ "$container_count" -gt 0 ];
            CODE "" "$(docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>/dev/null)"
        fi
    else
        APP "> Docker not installed"
    fi

    # Applications section
    H2 "📦 Application Stack"
    local n8n_status=$(echo "$apps_json" | grep -o '"n8n": *"[^"]*"' | cut -d'"' -f4)
    local postgres_status=$(echo "$apps_json" | grep -o '"postgres": *"[^"]*"' | cut -d'"' -f4)
    local cloudflared_status=$(echo "$apps_json" | grep -o '"cloudflared": *"[^"]*"' | cut -d'"' -f4)
    local tailscale_status=$(echo "$apps_json" | grep -o '"tailscale": *"[^"]*"' | cut -d'"' -f4)
    local portainer_status=$(echo "$apps_json" | grep -o '"portainer": *"[^"]*"' | cut -d'"' -f4)
    [ "$n8n_status" = "running_healthy" ] && KV "N8N" "Running ✅ (API healthy)" || \
    [ "$n8n_status" = "running" ] && KV "N8N" "Running ⚠️ (API not responding)" || \
    KV "N8N" "Not found ❌"
    [ "$postgres_status" = "running" ] && KV "PostgreSQL" "Running ✅" || KV "PostgreSQL" "Not found ❌"
    [ "$portainer_status" = "running" ] && KV "Portainer" "Running ✅" || KV "Portainer" "Not found ❌"
    [ "$cloudflared_status" = "active" ] && KV "Cloudflared" "Active ✅" || \
    [ "$cloudflared_status" = "enabled_not_active" ] && KV "Cloudflared" "Enabled but not active ⚠️" || \
    KV "Cloudflared" "Not found ❌"
    [ "$tailscale_status" = "connected" ] && KV "Tailscale" "Connected ✅" || \
    [ "$tailscale_status" = "installed_not_connected" ] && KV "Tailscale" "Installed but not connected ⚠️" || \
    KV "Tailscale" "Not installed ❌"

    # Network section
    H2 "🌐 Network"
    local internal_ip=$(echo "$system_json" | grep -o '"internal_ip": *"[^"]*"' | cut -d'"' -f4)
    local external_ip=$(echo "$system_json" | grep -o '"external_ip": *"[^"]*"' | cut -d'"' -f4)
    KV "Internal IP" "$internal_ip"
    KV "External IP" "$external_ip"
    if [ "$tailscale_status" = "connected" ];
        local tailscale_ip=$(echo "$apps_json" | grep -o '"tailscale_ip": *"[^"]*"' | cut -d'"' -f4)
        KV "Tailscale IP" "$tailscale_ip"
    fi

    # Recommendations
    H2 "💡 Recommendations"
    local mem_total_kb=$(echo "$system_json" | grep -o '"total_kb": *[0-9]*' | head -1 | awk '{print $2}')
    local mem_gb=$(awk "BEGIN {printf \"%.1f\", $mem_total_kb/1024/1024}")
    if (( $(echo "$mem_gb < 2" | bc -l 2>/dev/null || echo "0") ));
        APP "### Low Memory System ($mem_gb GB)"
        APP "- Enable swap (2GB recommended)"
        APP "- Use memory limits in Docker containers"
        APP "- Enable execution pruning in N8N"
        APP "- Optimize PostgreSQL for low memory"
    fi
    local disk_usage=$(echo "$system_json" | grep -o '"usage_percent": *[0-9]*' | awk '{print $2}')
    if [ "$disk_usage" -gt 80 ];
        APP "### High Disk Usage (${disk_usage}%)"
        APP "- Run \`docker system prune -af\`"
        APP "- Check Docker logs size"
        APP "- Review old backups and temp files"
    fi

    # Summary
    H2 "✅ Summary"
    APP "Infrastructure analysis completed successfully!"
    APP ""
    APP "**Key Points:**"
    APP "- System: $hostname ($os on $kernel)"
    APP "- Role: $pipeline_role"
    APP "- Resources: $cpu_cores CPU cores, $mem_gb GB RAM"
    APP "- Docker: $([ "$docker_installed" = "true" ] && echo "Installed" || echo "Not installed")"
    APP "- Stack: $([ "$n8n_status" = "running" ] || [ "$n8n_status" = "running_healthy" ] && echo "N8N running" || echo "N8N not found")"
    APP ""
    APP "🇺🇦 **Слава Україні!**"
}

# ========== Tailscale Installation Prompt ==========
maybe_install_tailscale() {
    if have tailscale;
        return 0
    fi
    echo ""
    read -r -p "Tailscale is not installed. Install it now? [y/N]: " ans
    case "${ans:-N}" in
        y|Y)
            log_info "Installing Tailscale..."
            if have curl;
                curl -fsSL https://tailscale.com/install.sh | sudo sh
            elif have wget;
                wget -qO- https://tailscale.com/install.sh | sudo sh
            else
                log_error "Need curl or wget to install."
                return 1
            fi
            log_success "Tailscale installed!"
            ;;*
            log_info "Skipping Tailscale installation."
            ;;*
    esac
}

# ========== Main Execution ==========
main() {
    # Remote execution mode
    if [ "$#" -gt 0 ];
        log_info "REMOTE MODE: Generating reports for hosts: $@"
        : > "$REPORT_FILE" # Clear local report file
        
        for HOST in "$@";
            log_info "Connecting to $HOST..."
            # Execute this script on the remote host and capture its stdout
            if remote_report=$(ssh -T "$HOST" 'bash -s' < "$0");
                echo "---" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"
                # The H1 helper adds its own newlines
                (H1 "Report for Host: \
`$HOST`") >> "$REPORT_FILE"
                echo "$remote_report" >> "$REPORT_FILE"
                log_success "Successfully generated report for $HOST"
            else
                log_error "Failed to generate report for $HOST"
                echo "---" >> "$REPORT_FILE"
                (H1 "Report for Host: \
`$HOST`") >> "$REPORT_FILE"
                echo "### ❌ FAILED to retrieve report from this host." >> "$REPORT_FILE"
            fi
        done

        log_success "Multi-host report generation complete!"
        echo "📄 Combined Markdown Report: $REPORT_FILE" >&2

    # Local execution mode
    else
        # Check if running interactively
        if [ -t 0 ] && [ -t 1 ];
            maybe_install_tailscale
        fi
        
        log_info "LOCAL MODE: Starting infrastructure analysis..."
        
        # Generate report and save to file
        generate_report > "$REPORT_FILE"
        
        # Final message
        log_success "Report generated successfully!"
        echo "📄 Markdown: $REPORT_FILE" >&2
        echo "📊 JSON: $JSON_FILE" >&2
    fi
}

# Run main
main "$@"
