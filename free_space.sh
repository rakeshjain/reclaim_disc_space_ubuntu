#!/bin/bash
# Ubuntu Disk Manager - Cleanup + Log Size Control
# Author: Rakesh Jain's Assistant 😊

set -e

CONF_FILE="/etc/systemd/journald.conf"

echo "=============================="
echo "   Ubuntu Disk Manager Tool"
echo "=============================="
echo

# Show current usage
echo "[INFO] Current disk usage:"
df -h
echo

# 1. Clean apt cache
echo "👉 Step 1: Clean apt cache"
echo "This removes cached .deb package files that are safe to delete."
echo "It will NOT remove installed software."
read -p "Do you want to clean apt cache? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo apt-get clean
  sudo apt-get autoclean
  echo "[DONE] Apt cache cleaned."
fi
echo

# 2. Remove unused packages
echo "👉 Step 2: Remove unused packages"
echo "This removes old libraries and software automatically installed"
echo "but no longer required by any package."
read -p "Do you want to remove unused packages? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo apt-get autoremove -y
  echo "[DONE] Unused packages removed."
fi
echo

# 3. Clean system logs
echo "👉 Step 3: Clean system logs"
echo "This deletes logs older than 7 days and compressed old logs."
echo "Useful if /var/log is using too much space."
read -p "Do you want to clean old logs? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo journalctl --vacuum-time=7d
  sudo rm -f /var/log/*.gz /var/log/*.[0-9] 2>/dev/null || true
  echo "[DONE] Old logs removed."
fi
echo

# 4. Remove old kernels
echo "👉 Step 4: Remove old kernels"
echo "This deletes old Linux kernel versions but keeps the current"
echo "and the previous one for safety."
read -p "Do you want to purge old kernels? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo apt-get autoremove --purge -y
  echo "[DONE] Old kernels purged."
fi
echo

# 5. Clean old snap versions
echo "👉 Step 5: Clean old snap versions"
echo "Snap keeps multiple revisions of applications, wasting space."
echo "This will remove disabled (old) versions but keep current ones."
read -p "Do you want to remove old snap versions? (y/n): " choice
if [[ $choice == "y" ]]; then
  LANG=C snap list --all | awk '/disabled/{print $1, $3}' |
  while read snapname revision; do
    sudo snap remove "$snapname" --revision="$revision"
  done
  echo "[DONE] Old snap versions removed."
fi
echo

# 6. Show top 20 biggest files
echo "👉 Step 6: Identify large files"
echo "This will scan your system and list the 20 largest files over 100MB."
echo "You can then decide manually if you want to delete them."
read -p "Do you want to list top 20 biggest files? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo find / -type f -size +100M -exec du -h {} + 2>/dev/null | sort -hr | head -20
  echo "[INFO] Review above files manually before deleting."
fi
echo

# 7. Configure journald log size
echo "👉 Step 7: Configure journald log size"
echo "System logs are stored by systemd-journald. By default, they can grow large."
echo "Here you can set permanent size limits for logs."
read -p "Do you want to configure journald log size limits? (y/n): " choice
if [[ $choice == "y" ]]; then
  echo
  echo "[INFO] Current journald.conf values:"
  grep -E "SystemMaxUse|SystemKeepFree|SystemMaxFileSize|SystemMaxFiles" $CONF_FILE | grep -v '^#' || echo "(none set, defaults in use)"
  echo

  # Ask new settings
  read -p "Enter new SystemMaxUse value (e.g., 500M, 1G, leave blank to skip): " MAX_USE
  read -p "Enter new SystemKeepFree value (e.g., 100M, leave blank to skip): " KEEP_FREE
  read -p "Enter new SystemMaxFileSize value (e.g., 50M, leave blank to skip): " MAX_FILE
  read -p "Enter new SystemMaxFiles value (e.g., 10, leave blank to skip): " MAX_FILES
  echo

  # Backup config
  sudo cp $CONF_FILE ${CONF_FILE}.bak.$(date +%F-%T)
  echo "[INFO] Backup saved as ${CONF_FILE}.bak.$(date +%F-%T)"

  # Apply new values
  if [[ -n "$MAX_USE" ]]; then
    sudo sed -i "s/^#*SystemMaxUse=.*/SystemMaxUse=$MAX_USE/" $CONF_FILE || echo "SystemMaxUse=$MAX_USE" | sudo tee -a $CONF_FILE
  fi
  if [[ -n "$KEEP_FREE" ]]; then
    sudo sed -i "s/^#*SystemKeepFree=.*/SystemKeepFree=$KEEP_FREE/" $CONF_FILE || echo "SystemKeepFree=$KEEP_FREE" | sudo tee -a $CONF_FILE
  fi
  if [[ -n "$MAX_FILE" ]]; then
    sudo sed -i "s/^#*SystemMaxFileSize=.*/SystemMaxFileSize=$MAX_FILE/" $CONF_FILE || echo "SystemMaxFileSize=$MAX_FILE" | sudo tee -a $CONF_FILE
  fi
  if [[ -n "$MAX_FILES" ]]; then
    sudo sed -i "s/^#*SystemMaxFiles=.*/SystemMaxFiles=$MAX_FILES/" $CONF_FILE || echo "SystemMaxFiles=$MAX_FILES" | sudo tee -a $CONF_FILE
  fi

  echo
  echo "[INFO] Restarting systemd-journald service..."
  sudo systemctl restart systemd-journald
  echo "[DONE] Journald limits updated."
fi
echo

# Final usage
echo "[INFO] Disk usage after cleanup:"
df -h
echo
echo "🎉 Disk management complete!"
