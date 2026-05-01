#!/bin/bash
# ── Smart Shopper — Server Setup Script ──────────────────────────────────────
# شغّله مرة وحدة على السيرفر الجديد
# sudo bash setup_server.sh

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Smart Shopper — Server Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 1. System Update ──
echo "▶ Updating system..."
apt update && apt upgrade -y

# ── 2. Python & Tools ──
echo "▶ Installing Python & tools..."
apt install -y python3 python3-pip python3-venv git curl nginx libgl1

# ── 3. Clone Repo ──
echo "▶ Cloning repo..."
cd /home
git clone https://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@github.com/ji2v111/Smart-Shopper.git app
cd /home/app/smart_shopper_backend

# ── 4. Virtual Environment ──
echo "▶ Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# ── 5. Install Dependencies ──
echo "▶ Installing dependencies (this takes 5-10 minutes)..."
pip install --upgrade pip
pip install -r requirements.txt

# ── 6. .env File ──
echo "▶ Creating .env file..."
cat > .env << 'ENVEOF'
GEMINI_API_KEY=YOUR_GEMINI_KEY
SERPAPI_KEY=YOUR_SERPAPI_KEY
IMGBB_KEY=YOUR_IMGBB_KEY
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
DB_SECRET_KEY=YOUR_RANDOM_32CHAR_STRING
ENVEOF

echo "⚠️  عدّل ملف .env وحط مفاتيحك الحقيقية"
echo "    nano /home/app/smart_shopper_backend/.env"

# ── 7. Systemd Service ──
echo "▶ Creating systemd service..."
cat > /etc/systemd/system/smartshopper.service << 'SERVICEEOF'
[Unit]
Description=Smart Shopper Backend
After=network.target

[Service]
User=root
WorkingDirectory=/home/app/smart_shopper_backend
Environment="PATH=/home/app/smart_shopper_backend/venv/bin"
ExecStart=/home/app/smart_shopper_backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable smartshopper

# ── 8. Nginx ──
echo "▶ Configuring Nginx..."
cat > /etc/nginx/sites-available/smartshopper << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 20M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/smartshopper /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup complete!"
echo ""
echo "الخطوات التالية:"
echo "1. عدّل المفاتيح:  nano /home/app/smart_shopper_backend/.env"
echo "2. شغّل السيرفر:   systemctl start smartshopper"
echo "3. تحقق يشتغل:     systemctl status smartshopper"
echo "4. شوف اللوق:       journalctl -u smartshopper -f"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
