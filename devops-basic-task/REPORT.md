# DevOps Task Review - Vault Sweep

## 1. Threats Tracked & Why They Matter
* **Destructive Shell Commands:** Caught via tracking strings like `rm -rf /` or `mkfs`. Running these by accident or via a compromised script completely wipes nodes or halts execution.
* **Insecure File Permissions:** Triggers on any file that is world-writable (`777` or `o+w`). If files can be overwritten by any local context, malicious actors can hijack execution logic.
* **Direct Shell Piping:** Tracking `curl ... | sh` streams. Running online scripts straight into the environment without validation skips basic signature checks.
* **Reverse Shell Connections (Bonus 4):** Flags instances using network redirection flags like `/dev/tcp/` or `nc -e`. These indicate an attacker trying to maintain a command socket back to their host.

## 2. Environment File Parsing Limitations
The sanitation flow forces standard format structures using POSIX compliance rules (`^[A-Z0-9_]+=`). Lines get thrown out for the following reasons:
* **Whitespaces:** `KEY = value` syntax fails because Linux environments break on assignment spacing.
* **Invalid Characters:** Things like hyphens (`SERVER-NAME`) are dropped to protect default shell variables.
* **Quote Enclosures:** Dropping wrapping quotes (`USER="admin"`) to normalize clean configuration blocks.
* **Sensitive Identifiers:** Completely skipping fields matching `PASSWORD`, `SECRET`, or `TOKEN`. Plain text secrets should not sit in environment configurations.
* **Variable Hijacking:** Dropping redefinitions of critical system targets like `PATH`.

## 3. Real Bugs Encountered & Solutions
* **The Loop Prompt Lock:** When processing directories recursively inside a loop, using standard `read` commands for user prompts breaks because it tries to consume the pipe buffer instead of real keyboard interaction. Fixed this by forcing standard input to map straight to the host interface stream (`< /dev/tty`).
* **Infinite File Output Loops:** Generating `.env.sanitized` assets inside the evaluated folder was triggering successive recursive parsing loops. Squashed this by adding explicit filter overrides inside the `find` options (`! -name "*.sanitized"`).
* **Inherited Folder Permissions:** Output assets were inheriting insecure wide-open parent permissions on creation. Fixed this by assertively forcing a tight `chmod 600` on the destination file stream immediately.