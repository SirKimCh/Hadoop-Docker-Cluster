#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Khong tim thay file .env"
    exit 1
fi

source "$ENV_FILE"

SSH_USER="${SSH_USER:-ubuntu}"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

WORKERS=()
if [ -n "$WORKER1_IP" ]; then WORKERS+=("$WORKER1_IP"); fi
if [ -n "$WORKER2_IP" ]; then WORKERS+=("$WORKER2_IP"); fi

if [ ${#WORKERS[@]} -eq 0 ]; then
    echo "ERROR: Khong co WORKER1_IP hoac WORKER2_IP trong .env"
    exit 1
fi

echo "=== Cau hinh sudoers cho Workers ==="
echo "Workers: ${WORKERS[*]}"
echo ""

for W in "${WORKERS[@]}"; do
    echo "--- $SSH_USER@$W ---"
    echo "Nhap mat khau cua $SSH_USER tren $W khi duoc yeu cau:"
    ssh $SSH_OPTS "$SSH_USER@$W" "echo '$SSH_USER ALL=(ALL) NOPASSWD: /opt/hadoop/bin/*, /opt/hadoop/sbin/*, /usr/bin/jps' | sudo tee /etc/sudoers.d/hadoop > /dev/null && sudo chmod 440 /etc/sudoers.d/hadoop && echo '  -> Da cau hinh sudoers thanh cong'"
    echo ""
done

echo "=== HOAN THANH ==="
echo "Bay gio co the chay: ./scripts/start-hadoop.sh"
