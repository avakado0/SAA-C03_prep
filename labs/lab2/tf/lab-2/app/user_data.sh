#!/bin/bash
set -euxo pipefail

# Amazon Linux 2023 uses dnf.
dnf install -y python3.11 python3.11-pip

# Install the minimal application dependencies.
python3.11 -m pip install fastapi uvicorn

mkdir -p /opt/lab2

cat > /opt/lab2/app.py <<'PYEOF'
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def home():
    return {
        "message": "Hello from Lab 2 EC2!",
        "lab": "AWS SAA Lab 2",
        "status": "public",
    }
PYEOF

# Run FastAPI as a systemd service so it starts automatically.
cat > /etc/systemd/system/lab2-fastapi.service <<'SERVICEEOF'
[Unit]
Description=Lab 2 FastAPI application
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lab2
ExecStart=/usr/local/bin/python3.11 -m uvicorn app:app --host 0.0.0.0 --port 80
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable --now lab2-fastapi.service
