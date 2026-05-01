#!/bin/bash
# ── Smart Shopper — Update Script ────────────────────────────────────────────
# استخدمه كل مرة تحدّث الكود على GitHub
# sudo bash update.sh

set -e

echo "▶ Pulling latest code..."
cd /home/app
git pull

echo "▶ Installing any new dependencies..."
cd smart_shopper_backend
source venv/bin/activate
pip install -r requirements.txt

echo "▶ Restarting service..."
systemctl restart smartshopper

echo "✅ Updated! Check status:"
systemctl status smartshopper --no-pager
