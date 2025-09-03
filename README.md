# Ubuntu Disk Space Reclaimer

A simple, interactive bash script to help reclaim disk space on Ubuntu by cleaning caches, pruning old packages, trimming logs, and more.

## IMPORTANT DISCLAIMER

- Use at your own risk.
- You are solely responsible for any damage, data loss, or system issues caused by running this script.
- Always back up important data before proceeding.
- Review each step carefully; some actions cannot be undone.
- At launch, you'll be asked to explicitly accept a risk disclaimer before any changes are made.

## What the script does (with your confirmation at each step)

1. APT cache cleanup
   - Runs `apt-get clean` and `apt-get autoclean` to remove cached .deb files (does not remove installed software)
2. Remove unused packages
   - Runs `apt-get autoremove -y` to prune orphaned dependencies
3. Clean old system logs
   - Runs `journalctl --vacuum-time=7d` and removes compressed/rotated logs to free space
4. Purge old kernels
   - Keeps current (and typically previous) kernel; removes older ones using apt
5. Clean old Snap revisions
   - Removes disabled (old) Snap package revisions while keeping active ones
6. Identify large files
   - Lists top 20 files larger than 100MB for your manual review (no automatic deletion)
7. Configure journald log size (optional)
   - Backs up `/etc/systemd/journald.conf` and lets you set limits like SystemMaxUse, SystemKeepFree, etc., then restarts journald

The script also shows disk usage (df -h) before and after cleanup and prints an approximate "space reclaimed" summary.

## Requirements

- Ubuntu (or Ubuntu-based) system
- Terminal access
- Sudo privileges (the script will invoke sudo for specific steps)

## Getting Started

1. Clone this repository
   ```bash
   git clone https://github.com/your-username/reclaim_disc_space_ubuntu.git
   cd reclaim_disc_space_ubuntu
   ```

2. Make the script executable
   ```bash
   chmod +x free_space.sh
   ```

3. Run the script
   ```bash
   ./free_space.sh
   ```
   - The script is interactive and will ask for confirmation before each operation.
   - You can safely answer "n" to skip any step you do not want to run.
   - On start, you'll be prompted to accept a risk disclaimer to proceed.

## Safety tips

- Test on a non-production machine or VM first.
- Ensure you have a recent backup or snapshot.
- Note your current kernel (`uname -r`) before purging old kernels.
- Review the list of large files before deleting anything manually.
- For journald changes, the script creates a timestamped backup of `/etc/systemd/journald.conf` so you can restore it if needed.

### Restore journald config (if needed)

If you want to revert journald changes, find the backup created by the script (e.g., `/etc/systemd/journald.conf.bak.YYYY-MM-DD-THH:MM:SS`) and restore:
```bash
sudo cp /etc/systemd/journald.conf.bak.* /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
```

## Troubleshooting

- Permission denied: run with execution permission and let sudo prompts appear when needed
  ```bash
  chmod +x free_space.sh
  ./free_space.sh
  ```
- If a step fails, read the on-screen message and try rerunning that step later.
- If the system behaves unexpectedly after cleanup, reboot and check logs: `journalctl -xe`.
- If Snap is not installed, the Snap cleanup step will be skipped automatically.
- If `journalctl` is unavailable or `/etc/systemd/journald.conf` is missing, journald-related steps will be skipped.

## License

MIT. See LICENSE for details.

---

By using this script you acknowledge and agree that the author is not responsible for any damage, data loss, or system issues that may arise.