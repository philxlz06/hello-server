#!/bin/bash
set -euo pipefail

cd /home/ubuntu/hello-server
git pull
.venv/bin/pip install -r requirements.txt --quiet
sudo systemctl restart hello-server
sleep 2
curl -fsS localhost:8000/health
echo ""
echo "deployed ✓"