#!/bin/bash
# Autoscript by Mahboub Million 🛡️

read -p "NS Domain : " -e -i ns.domain.com DnsNS
read -p "Ports to forward (comma-separated, e.g. 22,443,80): " -e -i 22 PORTS

# Download DNSTT server binary if not exists
[[ -f /usr/local/bin/dnstt-server ]] || {
  wget -c https://www.dropbox.com/s/vq5k1qixtersd80/dnstt-server?dl=0 -O /usr/local/bin/dnstt-server
  chmod +x /usr/local/bin/dnstt-server
}

clear
echo '=== Installing DNSTT Multi-Port Services ==='

IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

for PORT in "${PORT_ARRAY[@]}"; do
  SERVICE_NAME="dnstt-$PORT.service"

  cat <<EOF > /etc/systemd/system/$SERVICE_NAME
[Unit]
Description=DNSTT Server forwarding to port $PORT
After=network.target

[Service]
Type=simple
WorkingDirectory=/root
ExecStartPre=iptables -C INPUT -p udp --dport 5300 -j ACCEPT || iptables -A INPUT -p udp --dport 5300 -j ACCEPT
ExecStartPre=iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5300 || iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5300
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey 926d2e559047d381dfb6f66e020ce5e1f4d9199d3eea71ac9681112b0a2031f6 $DnsNS 127.0.0.1:$PORT
StandardOutput=append:/var/log/dnstt-$PORT.log
StandardError=append:/var/log/dnstt-$PORT.log
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now $SERVICE_NAME
  echo "✅ Started: $SERVICE_NAME forwarding to 127.0.0.1:$PORT"
done
