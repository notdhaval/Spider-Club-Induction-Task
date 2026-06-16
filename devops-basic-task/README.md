# Spider DevOps - Vault Sweep System

My submission for the Spider DevOps Basic Task. Built a security audit script that checks for compromised directories, strips out bad/unsecure configs from `.env` files, tracks execution histories in a central log, and hooks into an automated watchdog daemon.

## Folder Layout
* `scripts/vault_sweep.sh` - Core logic for finding threats, cleaning up `.env` files, and scanning code.
* `scripts/watchdog.sh` - Handles automated execution via crontab and fires system broadcasts if things look sketchy.
* `test_dir/` - Sandbox folder containing broken environment configs, dummy malicious tools, and loose permissions.
* `logs/vault_sweep.log` - Central tracker file protected by restricted directory permissions.

## Setup & Running Instructions

1. **Make scripts executable:**
   ```bash
   chmod +x scripts/vault_sweep.sh scripts/watchdog.sh

2. **Trigger a manual folder sweep:**
   ```bash
   ./scripts/vault_sweep.sh test_dir

3. **Setting up the 30-Minute Watchdog Automation:**
   Open up your crontab configuration:
   ```bash
   crontab -e

4. Drop this entry at the very bottom of the file (adjust the absolute path depending on where you cloned the repo):

   Plaintext:

   */30 * * * * /mnt/c/Users/reald/OneDrive/Desktop/devops-basic-task/scripts/watchdog.sh

## To Clear the Generated Logs and other stuff:

### 1. Delete all generated sanitized env files:
rm -f test_dir/*.sanitized

### 2. Clear out the contents of your log file without deleting the file itself:
> logs/vault_sweep.log

## To Revert File Permissions:
chmod 777 test_dir/dangerous.sh test_dir/auth.js test_dir/clean.sh test_dir/hack.py test_dir/.env
