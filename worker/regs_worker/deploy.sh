#!/bin/bash
# Deploy script for the Regulations Worker
# Run this on the droplet after SSH'ing in

set -e

echo "=========================================="
echo "Deploying Regulations Worker"
echo "=========================================="

cd /opt/regs_worker_repo

echo "[1/6] Pulling latest code..."
git fetch origin
git reset --hard origin/main

echo "[2/6] Installing dependencies..."
cd worker/regs_worker
npm install --production

echo "[3/6] Building TypeScript..."
npm run build

echo "[4/6] Copying to deployment location..."
cp -r dist/* /opt/regs_worker/dist/
cp package.json /opt/regs_worker/
cp -r node_modules /opt/regs_worker/

echo "[5/6] Updating systemd service..."
cp regs-worker.service /etc/systemd/system/
systemctl daemon-reload

echo "[6/6] Restarting worker..."
systemctl restart regs-worker

echo ""
echo "=========================================="
echo "Deployment complete!"
echo "=========================================="
echo ""
echo "Checking worker status..."
sleep 2
systemctl status regs-worker --no-pager || true

echo ""
echo "Following logs (Ctrl+C to stop)..."
journalctl -u regs-worker -f --no-pager
