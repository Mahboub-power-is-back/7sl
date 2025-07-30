#!/bin/bash

read -p "NS Domain: " -e -i ns.domain.com DnsNS
read -p "PORTS TO FORWARD (e.g. 22,443,80): " -e -i 22 PORTS
read -p "SEGMENT COUNT (recommended 2-4): " -e -i 3 SEGMENT

# Download DNSTT binary
wget -q -c https://www.dropbox.com/s/vq5k1qixtersd80/dnstt-server?dl=0 -O /usr/local/bin/dnstt-server
chmod +x /usr/local/bin/dnstt-server
clear

echo '=== Installing DNSTT Multi-Port Services with Segmentation ==='

i=0
for PORT in $(echo $PORTS | tr ',' ' ')
do
  DNS_PORT=$((5300 + i))

  cat <<EOF > /etc/systemd/system/dnstt-$PORT.service
[Unit]
Description=DNSTT Server Port $PORT
After=network.target

[Service]
Type=simple
WorkingDirectory=/root
ExecStartPre=/sbin/iptables -A INPUT -p udp --dport $DNS_PORT -j ACCEPT
ExecStartPre=/sbin/iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port=$DNS_PORT
ExecStart=/usr/local/bin/dnstt-server -udp :$DNS_PORT -privkey 926d2e559047d381dfb6f66e020ce5e1f4d9199d3eea71ac9681112b0a2031f6 -segment $SEGMENT $DnsNS 127.0.0.1:$PORT
StandardOutput=append:/var/log/dnstt-$PORT.log
StandardError=append:/var/log/dnstt-$PORT.log
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  # Start and enable service
  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable dnstt-$PORT
  systemctl restart dnstt-$PORT

  echo "✅ Service dnstt-$PORT running on UDP :$DNS_PORT → 127.0.0.1:$PORT with -segment $SEGMENT"

  i=$((i + 1))
done
