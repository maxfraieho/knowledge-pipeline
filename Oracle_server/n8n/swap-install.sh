#!/usr/bin/env bash
# swap-install.sh — idempotent swap + low-RAM sysctl tuner for Ubuntu/OCI
# - fixes CRLF in /etc/fstab
# - removes duplicate /swapfile entries (incl. /swapfile\r)
# - creates/resizes swap if needed
# - applies safe kernel tunings for 1GB RAM boxes
set -euo pipefail

# ====== CONFIG ======
SWAPFILE="/swapfile"
SWAPSIZE="2G"          # e.g. 1G, 2G, 4096M
SWAP_PRI="100"         # swap priority
SYSCTL_FILE="/etc/sysctl.d/99-lowram.conf"
# ====================

need_root() { if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)"; exit 1; fi; }
bytes_of() { # parse human size like 2G/2048M -> bytes
  local s="$1"
  case "$s" in
    *G|*g) echo $(( ${s%[Gg]} * 1024 * 1024 * 1024 ));;
    *M|*m) echo $(( ${s%[Mm]} * 1024 * 1024 ));;
    *K|*k) echo $(( ${s%[Kk]} * 1024 ));;
    *[0-9]) echo "$s";;  # already bytes
    *) echo "Invalid size: $s" >&2; exit 1;;
  esac
}

ensure_swapfile() {
  local desired_bytes; desired_bytes="$(bytes_of "$SWAPSIZE")"
  local recreate="no"

  if [[ -e "$SWAPFILE" ]]; then
    # check size
    current_bytes="$(stat -c '%s' "$SWAPFILE")" || current_bytes=0
    if [[ "$current_bytes" -ne "$desired_bytes" ]]; then
      echo "[i] resizing swapfile ($current_bytes -> $desired_bytes bytes)"
      recreate="yes"
    fi
  else
    recreate="yes"
  fi

  if [[ "$recreate" == "yes" ]]; then
    echo "[i] creating $SWAPFILE of size $SWAPSIZE"
    swapoff "$SWAPFILE" 2>/dev/null || true
    rm -f "$SWAPFILE"
    if fallocate -l "$SWAPSIZE" "$SWAPFILE" 2>/dev/null; then
      :
    else
      echo "[i] fallocate unavailable; using dd"
      dd if=/dev/zero of="$SWAPFILE" bs=1M count=$(( $(bytes_of "$SWAPSIZE") / 1048576 )) status=progress
    fi
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE" >/dev/null
  fi

  # ensure on
  if ! swapon --show=NAME | grep -Fxq "$SWAPFILE"; then
    swapon "$SWAPFILE"
  fi
}

fix_fstab() {
  echo "[i] fixing /etc/fstab CRLF & duplicates"
  cp -a /etc/fstab /etc/fstab.bak.$(date +%Y%m%d-%H%M%S)
  # strip CR from line endings
  sed -i 's/\r$//' /etc/fstab
  # remove any line referencing /swapfile (including weird /swapfile^M)
  sed -i '\|/swapfile|d' /etc/fstab
  # append canonical entry once
  echo "$SWAPFILE none swap sw,pri=${SWAP_PRI} 0 0" >> /etc/fstab
}

apply_sysctl() {
  echo "[i] applying low-RAM sysctl"
  cat > "$SYSCTL_FILE" <<'EOF'
vm.swappiness=60
vm.vfs_cache_pressure=200
vm.min_free_kbytes=65536
net.core.somaxconn=1024
fs.file-max=500000
EOF

  if sysctl --help 2>&1 | grep -q -- '--system'; then
    sysctl -p "$SYSCTL_FILE" >/dev/null
  else
    sysctl -p "$SYSCTL_FILE" >/dev/null
  fi
}

cleanup_weird_swaps() {
  # turn off any swap entries that are not the canonical path
  while read -r name _; do
    [[ -z "${name:-}" ]] && continue
    [[ "$name" == "$SWAPFILE" ]] && continue
    echo "[i] disabling stray swap: $name"
    swapoff "$name" || true
  done < <(swapon --show=NAME | tail -n +2)
}

main() {
  need_root
  fix_fstab
  ensure_swapfile
  cleanup_weird_swaps
  apply_sysctl

  echo "---- SWAP ----"
  swapon --show
  echo "---- MEM ----"
  free -h
  echo "[ok] done"
}

main "$@"
