#!/bin/bash
# Ubuntu Disk Cleanup Script
# Frees up space safely with confirmation prompts

set -e

echo "=============================="
echo "   Ubuntu Disk Cleanup Tool"
echo "=============================="
echo

# Show current usage
echo "[INFO] Current disk usage:"
df -h
echo

# 1. Clean apt cache
read -p "Clean apt cache? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo apt-get clean
  sudo apt-get autoclean
  echo "[DONE] Apt cache cleaned."
fi
echo

# 2. Remove unused packages
read -p "Remove unused packages? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo apt-get autoremove -y
  echo "[DONE] Unused packages removed."
fi
echo

# 3. Clean system logs
read -p "Clean system logs older than 7 days? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo journalctl --vacuum-time=7d
  sudo rm -f /var/log/*.gz /var/log/*.[0-9] 2>/dev/null || true
  echo "[DONE] Old logs removed."
fi
echo

# 4. Remove old kernels
read -p "Purge old kernels (keep current + 1)? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo apt-get autoremove --purge -y
  echo "[DONE] Old kernels purged."
fi
echo

# 5. Clean old snap versions
read -p "Remove old snap versions? (y/n): " choice
if [[ $choice == "y" ]]; then
  LANG=C snap list --all | awk '/disabled/{print $1, $3}' |
  while read snapname revision; do
    sudo snap remove "$snapname" --revision="$revision"
  done
  echo "[DONE] Old snap versions removed."
fi
echo

# 6. Show top 20 biggest files
read -p "Do you want to list top 20 biggest files on system? (y/n): " choice
if [[ $choice == "y" ]]; then
  sudo find / -type f -size +100M -exec du -h {} + 2>/dev/null | sort -hr | head -20
  echo "[INFO] Review above files manually before deleting."
fi
echo

# Show usage after cleanup
echo "[INFO] Disk usage after cleanup:"
df -h
echo
echo "🎉 Cleanup complete!"
