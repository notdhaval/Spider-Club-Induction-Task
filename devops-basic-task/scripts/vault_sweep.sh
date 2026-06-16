#!/bin/bash

# handle automation flag
BG_MODE=false
if [ "$1" == "-b" ]; then
    BG_MODE=true
    shift
fi

# check input dir
if [ -z "$1" ]; then
    echo "Error: pass a target dir"
    echo "Usage: $0 [-b] <dir>"
    exit 1
fi

TARGET_DIR="$1"
LOG_FILE="$(pwd)/logs/vault_sweep.log"

# init log setup
mkdir -p "$(dirname "$LOG_FILE")"
chmod 700 "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

get_time() {
    date "+%Y-%m-%d %H:%M:%S"
}

# check for base64 blocks / long strings
check_entropy() {
    local f="$1"
    local idx=1
    while IFS= read -r line || [ -n "$line" ]; do
        if echo "$line" | grep -qE '[A-Za-z0-9+/]{40,}'; then
            echo "LINE:$idx"
            return 0
        fi
        ((idx++))
    done < "$f"
    return 1
}

echo "--> Starting sweep on: $TARGET_DIR"

# 1. PERMISSIONS & DANGEROUS COMMANDS
find "$TARGET_DIR" -type f ! -name "*.sanitized" | while read -r file; do
    fname=$(basename "$file")
    is_bad=false
    has_malicious_code=false
    msg=""
    perm_issue=false
    
    # check if world writable
    if [ -w "$file" ] && [ "$(stat -c '%a' "$file" 2>/dev/null | grep -E '.[2367].')" ] || [ "$(stat -c '%a' "$file" 2>/dev/null | grep -E '..[2367]')" ]; then
        is_bad=true
        perm_issue=true
        msg="World Writeable ($(stat -c '%a' "$file" 2>/dev/null))"
    fi
    
    # deep script parsing
    if [[ "$fname" == *.sh ]] || file "$file" | grep -q "shell script"; then
        if grep -qE "rm -rf /|mkfs|shutdown|reboot" "$file"; then
            is_bad=true
            has_malicious_code=true
            msg="Destructive commands found"
        elif grep -qE "(curl|wget).*\|\s*(sh|bash)" "$file"; then
            is_bad=true
            has_malicious_code=true
            msg="Suspicious piping execution"
        elif grep -qE "/dev/tcp/|/dev/udp/|nc -e|bash -i" "$file"; then
            is_bad=true
            has_malicious_code=true
            msg="Reverse shell payload found"
        fi
    fi
    
    if [ "$is_bad" = true ]; then
        echo "[WARN] $file - Reason: $msg"
        echo "[$(get_time)] [WARN] $file -> $msg" >> "$LOG_FILE"
        
        if [ "$perm_issue" = true ]; then
            # Prompt only if it's a script backgrounded, not an sh file, or doesn't have active bad code payload
            if [ "$BG_MODE" = true ] || [[ "$fname" != *.sh ]] || [ "$has_malicious_code" = false ]; then
                # fix quietly for clean files or data assets
                chmod o-w "$file" 2>/dev/null
                echo "[FIX] Stripped permissions: $file"
                echo "[$(get_time)] [FIX] Auto-fixed perms on $file" >> "$LOG_FILE"
            else
                # interactively prompt ONLY for dangerous scripts carrying real bad code payloads
                echo -n "Strip world-write from dangerous script $file? (yes/no): "
                read -r ans < /dev/tty
                if [ "$ans" = "yes" ]; then
                    chmod o-w "$file" 2>/dev/null
                    echo "[FIX] Fixed permissions for $file"
                    echo "[$(get_time)] [FIX] User fixed perms on $file" >> "$LOG_FILE"
                fi
            fi
        fi
    fi
done

# 2. SANITIZE .ENV FILES
find "$TARGET_DIR" -type f -name ".env*" ! -name "*.sanitized" | while read -r env_file; do
    out_file="${env_file}.sanitized"
    rm -f "$out_file"
    touch "$out_file"
    chmod 600 "$out_file" 2>/dev/null
    
    good=0
    bad=0
    skips=()
    
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ -z "${line// }" ]] || [[ "$line" =~ ^# ]]; then
            echo "$line" >> "$out_file"
            continue
        fi
        
        if [[ "$line" =~ ^[A-Z0-9_]+=[^[:space:]]+ ]]; then
            k=$(echo "$line" | cut -d= -f1)
            v=$(echo "$line" | cut -d= -f2-)
            
            if [[ "$k" == *"PASSWORD"* ]] || [[ "$k" == *"SECRET"* ]] || [[ "$k" == *"TOKEN"* ]] || [[ "$k" == "PATH" ]]; then
                ((bad++))
                skips+=("$k")
            elif [[ "$v" =~ ^\".*\"$ ]] || [[ "$v" =~ ^\'.*\'$ ]]; then
                ((bad++))
                skips+=("$k")
            else
                echo "$line" >> "$out_file"
                ((good++))
            fi
        else
            ((bad++))
            bk=$(echo "$line" | cut -d= -f1 | xargs)
            skips+=("$bk")
        fi
    done < "$env_file"
    
    echo "[$(get_time)] [INFO] $env_file - Valid tokens: $good, Dropped: $bad" >> "$LOG_FILE"
    if [ ${#skips[@]} -gt 0 ]; then
        skip_list=$(IFS=,; echo "${skips[*]}")
        echo "[$(get_time)] [SKIP] $env_file - Rejected: $skip_list" >> "$LOG_FILE"
    fi
    echo "Generated sanitized file: $out_file"
done

# 3. CODE SCANNER (.js / .py)
find "$TARGET_DIR" -type f \( -name "*.js" -o -name "*.py" \) | while read -r src; do
    l_idx=1
    while IFS= read -r line || [ -n "$line" ]; do
        if echo "$line" | grep -iqE '(api_key|apikey|secret|token|password|passwd)\s*='; then
            if echo "$line" | grep -qE "['\"]"; then
                echo "[WARN] $src:$l_idx - Hardcoded credentials assigned"
            fi
        fi
        ((l_idx++))
    done < "$src"
    
    ent_line=$(check_entropy "$src")
    if [ -n "$ent_line" ]; then
        echo "[WARN] $src - Found high-entropy/Base64 pattern at $ent_line"
    fi
done

echo "--> Done. History logged to $LOG_FILE"