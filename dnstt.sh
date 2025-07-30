#!/bin/bash
# Autoscript by Mahboub Million 🛡️

read -p "NS Domain        : " -e -i ns.domain.com DnsNS
read -p "Ports to forward (comma-separated, e.g. 22,443,80): " -e -i 22 PORTS
read -p "Tunnel IP Range (base, e.g. 10.10.10) : " -e -i 10.10.10 TUN_BASE

WAN_IFACE=$(ip route | grep default | awk '{print $5}')

[[ -f /usr/local/bin/dnstt-server ]] || {
  wget -c https://www.dropbox.com/s/vq5k1qixtersd80/dnstt-server?dl=0 -O /usr/local/bin/dnstt-server
  chmod +x /usr/local/bin/dnstt-server
}

echo '=== Installing DNSTT Multi-Port with Unique TUN, SEGMENT and NAT ==='
IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
COUNT=1

for PORT in "${PORT_ARRAY[@]}"; do
  TUN_NAME="tun$PORT"
  TUN_ADDR="${TUN_BASE}.${COUNT}/24"
  COUNT=$((COUNT+1))

  systemctl stop dnstt-${PORT}.service &>/dev/null
  systemctl disable dnstt-${PORT}.service &>/dev/null
  rm -f /etc/systemd/system/dnstt-${PORT}.service

  cat <<EOF > /etc/systemd/system/dnstt-${PORT}.service
[Unit]
Description=DNSTT Server with Unique TUN + Segment on port $PORT
After=network.target

[Service]
Type=simple
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStartPre=iptables -C INPUT -p udp --dport 5300 -j ACCEPT || iptables -A INPUT -p udp --dport 5300 -j ACCEPT
ExecStartPre=iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 || iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
ExecStartPre=iptables -t nat -C POSTROUTING -s ${TUN_ADDR%/*} -o $WAN_IFACE -j MASQUERADE || iptables -t nat -A POSTROUTING -s ${TUN_ADDR%/*} -o $WAN_IFACE -j MASQUERADE
ExecStartPre=iptables -C FORWARD -i $TUN_NAME -o $WAN_IFACE -j ACCEPT || iptables -A FORWARD -i $TUN_NAME -o $WAN_IFACE -j ACCEPT
ExecStartPre=iptables -C FORWARD -i $WAN_IFACE -o $TUN_NAME -m state --state RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i $WAN_IFACE -o $TUN_NAME -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStart=/usr/local/bin/dnstt-server --tun --tun-device $TUN_NAME --tun-address $TUN_ADDR -segment 4 -udp :5300 -privkey 926d2e559047d381dfb6f66e020ce5e1f4d9199d3eea71ac9681112b0a2031f6 $DnsNS 127.0.0.1:$PORT
StandardOutput=append:/var/log/dnstt-$PORT.log
StandardError=append:/var/log/dnstt-$PORT.log
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now dnstt-${PORT}.service
  echo "✅ Started: dnstt-${PORT}.service → 127.0.0.1:$PORT with TUN $TUN_NAME ($TUN_ADDR)"
done

sysctl -w net.ipv4.ip_forward=1
grep -qxF "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

echo
echo "✅ All DNSTT services running with unique TUN + SEGMENT per port."