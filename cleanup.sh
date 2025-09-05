#!/bin/bash
# cleanup.sh - Clean up disk space safely on Ubuntu/Debian

echo "=== Starting cleanup ==="

# Step 0: Show top 10 disk usage in /var
echo "Checking largest folders in /var..."
sudo du -h --max-depth=2 /var 2>/dev/null | sort -hr | head -n 10

echo "-----------------------------------"
echo "Now starting cleanup..."
echo "-----------------------------------"

# Step 1: Clean apt cache
echo "Cleaning apt cache..."
sudo apt-get clean
sudo apt-get autoclean

# Step 2: Remove unused packages
echo "Removing unused packages..."
sudo apt-get autoremove -y

# Step 3: Clean systemd journal logs
echo "Cleaning journal logs..."
sudo journalctl --vacuum-time=7d

# Step 4: Clean old logs in /var/log
echo "Cleaning old logs in /var/log..."
sudo find /var/log -type f -name "*.gz" -delete
sudo find /var/log -type f -name "*.1" -delete
sudo truncate -s 0 /var/log/*.log 2>/dev/null

# Step 5: Clear thumbnail cache
echo "Cleaning thumbnail cache..."
rm -rf ~/.cache/thumbnails/*

# Step 6: Ask user about deleting trash
read -p "Do you want to empty Trash? (y/n): " choice
if [ "$choice" = "y" ]; then
  rm -rf ~/.local/share/Trash/*
  echo "Trash cleaned."
fi

# Step 7: Check if Docker exists
if command -v docker &> /dev/null; then
  read -p "Do you want to clean unused Docker images/containers? (y/n): " docker_choice
  if [ "$docker_choice" = "y" ]; then
    echo "Cleaning unused Docker data..."
    sudo docker system prune -af
  fi
fi

# Step 8: Show freed space
echo "=== Cleanup complete. Current disk usage: ==="
df -h /
