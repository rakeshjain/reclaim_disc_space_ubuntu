#!/bin/bash
# ======================================================================
# Ubuntu Disk Space Manager - Cleanup + Log Size Control
# Author: Rakesh Jain's Assistant 😊
#
# This script combines:
#   1. cleanup.sh  -> Automated cleanup of unused packages, apt cache, old logs, etc.
#   2. free_space.sh -> Log size control + structured user-friendly output.
#
# Features:
#   - Shows largest directories in /var (common source of disk usage)
#   - Cleans apt cache, removes unused packages, old kernels, journal logs, etc.
#   - Allows user to review & change systemd journal log size limit.
#   - Uses colorful, structured logging for better readability.
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

# -----------------------------
# Step 0: Show disk usage in /var
# -----------------------------
step "Checking largest folders in /var (top 10)..."
sudo du -h --max-depth=2 /var 2>/dev/null | sort -hr | head -n 10
echo "------------------------------------------------------------"

# -----------------------------
# Step 1: Clean APT cache
# -----------------------------
step "Cleaning APT cache..."
sudo apt-get clean
sudo apt-get autoclean
success "APT cache cleaned."

# -----------------------------
# Step 2: Remove unused packages
# -----------------------------
step "Removing unused packages and dependencies..."
sudo apt-get autoremove -y
success "Unused packages removed."

# -----------------------------
# Step 3: Remove old kernels (if any)
# -----------------------------
step "Removing old kernels..."
sudo apt-get remove --purge -y $(dpkg -l | awk '/^rc/ {print $2}') || true
success "Old kernels purged (if any)."

# -----------------------------
# Step 4: Clean systemd journal logs
# -----------------------------
step "Cleaning journal logs (retaining 7 days)..."
sudo journalctl --vacuum-time=7d
success "Journal logs cleaned."

# -----------------------------
# Step 5: Check & Configure journal log size limit
# -----------------------------
step "Checking current systemd journal log size limit..."
CURRENT_LIMIT=$(grep -E '^SystemMaxUse=' /etc/systemd/journald.conf | cut -d= -f2 || echo "Not Set")
info "Current SystemMaxUse: ${CURRENT_LIMIT}"

read -p "👉 Enter new journal log size limit (e.g., 200M, 500M, 1G) or press Enter to skip: " NEW_LIMIT
if [ ! -z "$NEW_LIMIT" ]; then
  sudo sed -i '/^SystemMaxUse=/d' /etc/systemd/journald.conf
  echo "SystemMaxUse=${NEW_LIMIT}" | sudo tee -a /etc/systemd/journald.conf > /dev/null
  sudo systemctl restart systemd-journald
  success "Journal log size limit updated to ${NEW_LIMIT}."
else
  info "No changes made to journal log size limit."
fi

# -----------------------------
# Step 6: Clean thumbnail cache (user-specific)
# -----------------------------
step "Cleaning user thumbnail cache (if exists)..."
rm -rf ~/.cache/thumbnails/* || true
success "Thumbnail cache cleaned."

# -----------------------------
# Step 7: Display free disk space
# -----------------------------
step "Final free disk space:"
df -hT /

success "Disk cleanup and optimization completed successfully! 🎉"
