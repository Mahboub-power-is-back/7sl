#!/bin/bash

read -p "NS Domains : " -e -i ns.domain.com DnsNS
read -p "PORTFORWARD : " -e -i 22 PORT

# Download DNSTT server binary
wget -c https://www.dropbox.com/s/vq5k1qixtersd80/dnstt-server?dl=0 -O /usr/local/bin/dnstt-server
chmod +x /usr/local/bin/dnstt-server
clear

echo '=== Installing DNSTT SERVICE ==='

# Create systemd service
cat <<EOF > /etc/systemd/system/dnstt-service.service
[Unit]
Description=DNSTT Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/root
ExecStartPre=/sbin/iptables -A INPUT -p udp --dport 5300 -j ACCEPT
ExecStartPre=/sbin/iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey 926d2e559047d381dfb6f66e020ce5e1f4d9199d3eea71ac9681112b0a2031f6 $DnsNS 127.0.0.1:$PORT
StandardOutput=append:/var/log/dnstt.log
StandardError=append:/var/log/dnstt.log
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start the service
systemctl daemon-reload
systemctl start dnstt-service
systemctl enable dnstt-service

echo "✅ DNSTT server started on UDP port 53 → forwarded to $PORT"