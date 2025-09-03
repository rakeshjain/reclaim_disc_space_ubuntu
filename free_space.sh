#!/bin/bash
# Ubuntu Disk Manager - Cleanup + Log Size Control
# Author: Rakesh Jain's Assistant 😊

set -e

# Color and helper functions for user-friendly output
if [ -t 1 ]; then
  BOLD="\e[1m"; RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

info() { echo -e "${BLUE}[INFO]${RESET} $*"; }
step() { echo -e "${YELLOW}👉 ${BOLD}$*${RESET}"; }
success() { echo -e "${GREEN}[DONE]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*"; }

prompt_yes_no() {
  local prompt="${1:-Proceed?} [y/N]: "
  local answer
  while true; do
    read -r -p "$prompt" answer
    case "$answer" in
      [yY]|[yY][eE][sS]) return 0 ;;
      [nN]|[nN][oO]|"") return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Safely set or append a key=value in a config file
set_conf_value() {
  local file="$1" key="$2" val="$3"
  if grep -qE "^[#]*${key}=" "$file"; then
    sudo sed -i "s|^[#]*${key}=.*|${key}=${val}|" "$file"
  else
    echo "${key}=${val}" | sudo tee -a "$file" >/dev/null
  fi
}

CONF_FILE="/etc/systemd/journald.conf"


# Banner
echo -e "${BOLD}==============================${RESET}"
echo -e "${BOLD}   Ubuntu Disk Manager Tool   ${RESET}"
echo -e "${BOLD}==============================${RESET}"
echo
warn "This script makes system-level changes. Proceed with caution."
warn "You are solely responsible for any damage or data loss."
if ! prompt_yes_no "Do you understand and accept the risks?"; then
  info "Exiting without making changes."
  exit 0
fi
echo

# Show current usage
info "Current disk usage:"
df -h
echo
# Capture available space on root filesystem before cleanup (in bytes)
AVAIL_BEFORE=$(df --output=avail -B1 / 2>/dev/null | tail -1 | tr -d ' ')
bytes_to_human() { numfmt --to=iec --suffix=B --format="%.1f" "$1" 2>/dev/null || echo "$1 bytes"; }

# 1. Clean apt cache
step "Step 1: Clean apt cache"
info "Removes cached .deb package files that are safe to delete. Does NOT remove installed software."
if prompt_yes_no "Clean apt cache now?"; then
  sudo apt-get clean
  sudo apt-get autoclean
  success "Apt cache cleaned."
fi
echo

# 2. Remove unused packages
step "Step 2: Remove unused packages"
info "Removes libraries/software automatically installed but no longer required by any package."
if prompt_yes_no "Remove unused packages now?"; then
  sudo apt-get autoremove -y
  success "Unused packages removed."
fi
echo

# 3. Clean system logs
step "Step 3: Clean system logs"
info "Deletes logs older than 7 days and compressed old logs. Useful if /var/log is large."
if prompt_yes_no "Clean old logs now?"; then
  if have_cmd journalctl; then
    sudo journalctl --vacuum-time=7d
  else
    warn "journalctl not found; skipping journald vacuum."
  fi
  sudo rm -f /var/log/*.gz /var/log/*.[0-9] 2>/dev/null || true
  success "Old logs removed."
fi
echo

# 4. Remove old kernels
step "Step 4: Remove old kernels"
info "Deletes old Linux kernel versions while keeping the current (and typically previous) one."
info "Current kernel: $(uname -r)"
if prompt_yes_no "Purge old kernels now?"; then
  sudo apt-get autoremove --purge -y
  success "Old kernels purged."
fi
echo

# 5. Clean old snap versions
step "Step 5: Clean old snap versions"
info "Snap keeps multiple revisions of apps. This removes disabled (old) revisions, keeping current ones."
if have_cmd snap; then
  if prompt_yes_no "Remove old snap revisions now?"; then
    LANG=C snap list --all | awk '/disabled/{print $1, $3}' |
    while read -r snapname revision; do
      sudo snap remove "$snapname" --revision="$revision"
    done
    success "Old snap versions removed."
  fi
else
  warn "snap is not installed; skipping snap cleanup."
fi
echo

# 6. Show top 20 biggest files
step "Step 6: Identify large files"
info "Scans and lists the 20 largest files over 100MB. No files are deleted automatically."
if prompt_yes_no "List top 20 largest files now?"; then
  sudo find / -type f -size +100M -exec du -h {} + 2>/dev/null | sort -hr | head -20
  info "Review the files above manually before deleting."
fi
echo

# 7. Configure journald log size
step "Step 7: Configure journald log size"
info "System logs are stored by systemd-journald and can grow large. Set persistent size limits here."
if prompt_yes_no "Configure journald log size limits now?"; then
  if [ ! -f "$CONF_FILE" ]; then
    warn "Config file $CONF_FILE not found. Skipping journald configuration."
  else
    echo
    info "Current journald.conf values:"
    grep -E "^(SystemMaxUse|SystemKeepFree|SystemMaxFileSize|SystemMaxFiles)=" "$CONF_FILE" || echo "(none set, defaults in use)"
    echo

    # Ask new settings
    read -r -p "Enter new SystemMaxUse value (e.g., 500M, 1G, leave blank to skip): " MAX_USE
    read -r -p "Enter new SystemKeepFree value (e.g., 100M, leave blank to skip): " KEEP_FREE
    read -r -p "Enter new SystemMaxFileSize value (e.g., 50M, leave blank to skip): " MAX_FILE
    read -r -p "Enter new SystemMaxFiles value (e.g., 10, leave blank to skip): " MAX_FILES
    echo

    # Backup config
    BACKUP_PATH="${CONF_FILE}.bak.$(date +%F-%T)"
    sudo cp "$CONF_FILE" "$BACKUP_PATH"
    info "Backup saved as $BACKUP_PATH"

    # Apply new values
    if [[ -n "$MAX_USE" ]]; then set_conf_value "$CONF_FILE" SystemMaxUse "$MAX_USE"; fi
    if [[ -n "$KEEP_FREE" ]]; then set_conf_value "$CONF_FILE" SystemKeepFree "$KEEP_FREE"; fi
    if [[ -n "$MAX_FILE" ]]; then set_conf_value "$CONF_FILE" SystemMaxFileSize "$MAX_FILE"; fi
    if [[ -n "$MAX_FILES" ]]; then set_conf_value "$CONF_FILE" SystemMaxFiles "$MAX_FILES"; fi

    echo
    info "Restarting systemd-journald service..."
    sudo systemctl restart systemd-journald
    success "Journald limits updated."
  fi
fi
echo

# Final usage
info "Disk usage after cleanup:"
df -h
echo
AVAIL_AFTER=$(df --output=avail -B1 / 2>/dev/null | tail -1 | tr -d ' ')
if [[ -n "$AVAIL_BEFORE" && -n "$AVAIL_AFTER" ]]; then
  DELTA=$(( AVAIL_AFTER - AVAIL_BEFORE ))
  if (( DELTA >= 0 )); then
    success "Approx. space reclaimed: $(bytes_to_human "$DELTA")"
  else
    warn "Available space decreased by: $(bytes_to_human "$(( -DELTA ))")"
  fi
fi
echo
echo "🎉 Disk management complete!"
