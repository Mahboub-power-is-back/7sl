#!/bin/bash

read -p "NS Domains : " -e -i ns.domain.com DnsNS
read -p "PORTFORWARD : " -e -i 22 PORT


wget -c https://www.dropbox.com/s/vq5k1qixtersd80/dnstt-server?dl=0 -O /usr/local/bin/dnstt-server;
chmod +x /usr/local/bin/dnstt-server
clear

echo 'DNSTT SERVICE'

cat <<EOF > /etc/systemd/system/dnstt-service.service

[Unit]
Description=DNSTT Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/root
ExecStartPre=/sbin/iptables -A INPUT -p udp --dport 5300 -j ACCEPT
ExecStartPre=/sbin/iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
ExecStart=/root/dnstt-server -udp :5300 -privkey 926d2e559047d381dfb6f66e020ce5e1f4d9199d3eea71ac9681112b0a2031f6 $DnsNS 127.0.0.1:$PORT
StandardOutput=append:/var/log/dnstt.log
StandardError=append:/var/log/dnstt.log
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
systemctl daemon-reload
systemctl start dnstt-service
systemctl enable --now dnstt-service
