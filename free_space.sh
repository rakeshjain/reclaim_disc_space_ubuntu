#!/bin/bash
# ======================================================================
# Ubuntu Disk Space Manager - Comprehensive System Cleanup
# Author: Rakesh Jain's Assistant 😊
#
# Features:
#   - System-wide cleanup of package cache, logs, and temporary files
#   - Removes old kernels, unused packages, and dependencies
#   - Cleans user-specific caches and temporary files
#   - Manages systemd journal logs and other system logs
#   - Identifies and optionally removes large files and directories
#   - Provides detailed disk usage statistics before and after cleanup
#
# NOTE: Run this script with sudo for full effectiveness.
# ======================================================================

set -e

# -----------------------------
# Color and helper functions
# -----------------------------
if [ -t 1 ]; then
  BOLD="\e[1m"; RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
step()    { echo -e "${YELLOW}👉 ${BOLD}$*${RESET}"; }
success() { echo -e "${GREEN}[DONE]${RESET} $*"; }
warn()    { echo -e "${RED}[WARN]${RESET} $*"; }
header()  { echo -e "\n${BOLD}${BLUE}=== $* ===${RESET}\n"; }

# -----------------------------
# Initial System Information
# -----------------------------
header "SYSTEM DISK USAGE BEFORE CLEANUP"
step "Overall disk usage:"
df -hT

echo -e "\n${YELLOW}Top 10 largest directories in /var:${RESET}"
sudo du -h --max-depth=2 /var 2>/dev/null | sort -hr | head -n 10

echo -e "\n${YELLOW}Top 10 largest directories in /home:${RESET}"
sudo du -h --max-depth=2 /home 2>/dev/null | sort -hr | head -n 10

echo -e "\n${YELLOW}Top 10 largest files in / (larger than 100MB):${RESET}"
sudo find / -type f -size +100M -exec ls -lah {} \; 2>/dev/null | sort -k 5 -hr | head -n 10

echo "------------------------------------------------------------"

# -----------------------------
# System Package Cleanup
# -----------------------------
header "SYSTEM PACKAGE CLEANUP"

step "Updating package lists..."
sudo apt-get update

step "Cleaning APT cache..."
sudo apt-get clean
sudo apt-get autoclean
success "APT cache cleaned."

step "Removing unused packages and dependencies..."
sudo apt-get autoremove -y --purge
success "Unused packages removed."

step "Removing residual config packages..."
sudo dpkg -l | grep '^rc' | awk '{print $2}' | xargs -r sudo dpkg --purge 2>/dev/null || true
success "Residual config packages removed."

step "Safely managing kernel versions..."
# Get current kernel version (just the version number)
CURRENT_KERNEL=$(uname -r | sed -r 's/-[a-z]+//')

# Get all installed kernel packages (linux-image-*)
KERNEL_PKGS=$(dpkg --list | grep '^ii\s*linux-image-[0-9]' | awk '{print $2}' | sort -V)

if [ -z "$KERNEL_PKGS" ]; then
    info "No kernel packages found to manage."
    return 0
fi

# Find the index of the current kernel in the sorted list
CURRENT_INDEX=0
INDEX=1
for pkg in $KERNEL_PKGS; do
    if [[ $pkg == *"$CURRENT_KERNEL"* ]]; then
        CURRENT_INDEX=$INDEX
        break
    fi
    ((INDEX++))
done

# Determine which kernels to keep (current and one previous if it exists)
KEEP_INDICES="$CURRENT_INDEX"
if [ $CURRENT_INDEX -gt 1 ]; then
    PREV_INDEX=$((CURRENT_INDEX - 1))
    KEEP_INDICES="$PREV_INDEX $KEEP_INDICES"
fi

# Generate lists of kernels to keep and remove
KEEP_KERNELS=""
REMOVE_KERNELS=""
INDEX=1
for pkg in $KERNEL_PKGS; do
    if [[ " $KEEP_INDICES " == *" $INDEX "* ]]; then
        KEEP_KERNELS="$KEEP_KERNELS $pkg"
    else
        REMOVE_KERNELS="$REMOVE_KERNELS $pkg"
    fi
    ((INDEX++))
done

# Trim whitespace
KEEP_KERNELS=$(echo $KEEP_KERNELS | xargs)
REMOVE_KERNELS=$(echo $REMOVE_KERNELS | xargs)

if [ -n "$REMOVE_KERNELS" ]; then
    echo -e "\n${YELLOW}The following old kernels can be safely removed:${RESET}"
    echo "$REMOVE_KERNELS" | tr ' ' '\n' | sed 's/^/  - /'
    echo -e "\n${GREEN}The following kernels will be kept:${RESET}"
    echo "$KEEP_KERNELS" | tr ' ' '\n' | sed 's/^/  - /'
    
    read -p "Do you want to remove the old kernels listed above? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for kernel in $REMOVE_KERNELS; do
            sudo apt-get remove --purge -y "$kernel"
        done
        sudo update-grub
        success "Old kernels removed successfully."
    else
        info "Skipping kernel removal as requested."
    fi
else
    info "No old kernels found to remove."
    info "Current kernel: $(uname -r)"
fi

# -----------------------------
# System Logs Cleanup
# -----------------------------
header "SYSTEM LOGS CLEANUP"

step "Cleaning systemd journal logs (retaining 7 days)..."
sudo journalctl --vacuum-time=7d
sudo journalctl --vacuum-size=100M
success "Journal logs cleaned."

step "Removing old log files..."
sudo find /var/log -type f -name "*.gz" -delete
sudo find /var/log -type f -name "*.log.*" -delete
sudo find /var/log -type f -name "*.1" -delete
success "Old log files removed."

step "Rotating log files..."
sudo logrotate -f /etc/logrotate.conf 2>/dev/null || true
success "Log files rotated."

# -----------------------------
# System Journal Configuration
# -----------------------------
header "SYSTEM JOURNAL CONFIGURATION"

step "Checking current systemd journal log size limit..."
CURRENT_LIMIT=$(grep -E '^SystemMaxUse=' /etc/systemd/journald.conf 2>/dev/null | cut -d= -f2 || echo "Not Set")
info "Current SystemMaxUse: ${CURRENT_LIMIT:-Default (10% of filesystem)}"

read -p "👉 Enter new journal log size limit (e.g., 200M, 500M, 1G) or press Enter to skip: " NEW_LIMIT
if [ ! -z "$NEW_LIMIT" ]; then
  # Backup current config
  sudo cp /etc/systemd/journald.conf /etc/systemd/journald.conf.bak
  
  # Update or add SystemMaxUse
  if grep -q '^SystemMaxUse=' /etc/systemd/journald.conf 2>/dev/null; then
    sudo sed -i "s/^SystemMaxUse=.*/SystemMaxUse=${NEW_LIMIT}/" /etc/systemd/journald.conf
  else
    echo "SystemMaxUse=${NEW_LIMIT}" | sudo tee -a /etc/systemd/journald.conf > /dev/null
  fi
  
  # Also set other sensible defaults if not present
  for setting in "SystemMaxFileSize=100M" "MaxRetentionSec=1month" "MaxFileSec=7day"; do
    key=$(echo "$setting" | cut -d= -f1)
    if ! grep -q "^${key}=" /etc/systemd/journald.conf 2>/dev/null; then
      echo "$setting" | sudo tee -a /etc/systemd/journald.conf > /dev/null
    fi
  done
  
  sudo systemctl restart systemd-journald
  success "Journal configuration updated. Size limit set to ${NEW_LIMIT}."
  info "Original configuration backed up to /etc/systemd/journald.conf.bak"
else
  info "No changes made to journal configuration."
fi

# -----------------------------
# User Cache and Temporary Files Cleanup
# -----------------------------
header "USER CACHE AND TEMPORARY FILES CLEANUP"

step "Cleaning user thumbnail cache..."
rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
rm -rf ~/.thumbnails/* 2>/dev/null || true

step "Cleaning user application cache..."
rm -rf ~/.cache/* 2>/dev/null || true

step "Cleaning temporary files..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
rm -rf ~/.local/share/Trash/* 2>/dev/null
rm -rf ~/.local/share/recently-used.xbel 2>/dev/null

step "Cleaning package manager cache..."
if command -v flatpak &> /dev/null; then
    flatpak uninstall --unused -y 2>/dev/null || true
fi

if command -v snap &> /dev/null; then
    sudo snap refresh --list 2>/dev/null || true
    sudo rm -f /var/lib/snapd/cache/* 2>/dev/null || true
fi

if command -v pip &> /dev/null; then
    pip cache purge 2>/dev/null || true
fi

if command -v npm &> /dev/null; then
    npm cache clean --force 2>/dev/null || true
fi

success "User cache and temporary files cleaned."

# -----------------------------
# Final Cleanup and Summary
# -----------------------------
header "FINAL SYSTEM CLEANUP"

step "Cleaning up package manager..."
sudo apt-get clean
sudo apt-get autoremove -y

step "Updating system databases..."
sudo updatedb 2>/dev/null || true

# -----------------------------
# Final Disk Usage Summary
# -----------------------------
header "DISK USAGE SUMMARY"

echo -e "\n${GREEN}=== BEFORE CLEANUP ===${RESET}"
echo -e "${YELLOW}Total disk usage before cleanup:${RESET}"
df -hT /

echo -e "\n${GREEN}=== LARGEST DIRECTORIES IN /var ===${RESET}"
sudo du -h --max-depth=2 /var 2>/dev/null | sort -hr | head -n 10

echo -e "\n${GREEN}=== LARGEST DIRECTORIES IN /home ===${RESET}"
sudo du -h --max-depth=2 /home 2>/dev/null | sort -hr | head -n 10

success "\n✅ Disk cleanup and optimization completed successfully! 🎉"

# Show additional cleanup tips
echo -e "\n${YELLOW}Additional cleanup suggestions:${RESET}"
echo "1. Check for large files: sudo find / -type f -size +500M -exec ls -lh {} \; 2>/dev/null | sort -k 5 -hr"
echo "2. Clean old snaps: sudo snap list --all | while read snapname ver rev trk pub note; do if [[ $note = *disabled* ]]; then sudo snap remove "$snapname" --revision="$rev"; fi; done"
echo "3. Clean Docker (if installed): docker system prune -a"

echo -e "\n${BOLD}You may need to restart your system for all changes to take effect.${RESET}"
