#!/bin/bash

read -p "NS Domain        : " -e -i ns.domain.com DnsNS
read -p "Ports to forward (comma-separated, e.g. 22,443,80): " -e -i 22 PORTS
read -p "Tunnel Interface : " -e -i tun0 TUN_NAME
read -p "Tunnel IP Range  : " -e -i 10.10.10.1/24 TUN_ADDR

WAN_IFACE=$(ip route | grep default | awk '{print $5}')

# Download dnstt-server if missing
[[ -f /usr/local/bin/dnstt-server ]] || {
  wget -c https://www.dropbox.com/s/vq5k1qixtersd80/dnstt-server?dl=0 -O /usr/local/bin/dnstt-server
  chmod +x /usr/local/bin/dnstt-server
}

echo '=== Installing DNSTT Multi-Port with TUN, SEGMENT and NAT ==='
IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

# Clean any previous services
for PORT in "${PORT_ARRAY[@]}"; do
  systemctl stop dnstt-${PORT}.service &>/dev/null
  systemctl disable dnstt-${PORT}.service &>/dev/null
  rm -f /etc/systemd/system/dnstt-${PORT}.service
done

for PORT in "${PORT_ARRAY[@]}"; do
  cat <<EOF > /etc/systemd/system/dnstt-${PORT}.service
[Unit]
Description=DNSTT Server with TUN + Segment on port $PORT
After=network.target

[Service]
Type=simple
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStartPre=/sbin/iptables -C INPUT -p udp --dport 5300 -j ACCEPT || /sbin/iptables -A INPUT -p udp --dport 5300 -j ACCEPT
ExecStartPre=/sbin/iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 || /sbin/iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
ExecStartPre=/sbin/iptables -t nat -C POSTROUTING -s ${TUN_ADDR%/*} -o $WAN_IFACE -j MASQUERADE || /sbin/iptables -t nat -A POSTROUTING -s ${TUN_ADDR%/*} -o $WAN_IFACE -j MASQUERADE
ExecStartPre=/sbin/iptables -C FORWARD -i $TUN_NAME -o $WAN_IFACE -j ACCEPT || /sbin/iptables -A FORWARD -i $TUN_NAME -o $WAN_IFACE -j ACCEPT
ExecStartPre=/sbin/iptables -C FORWARD -i $WAN_IFACE -o $TUN_NAME -m state --state RELATED,ESTABLISHED -j ACCEPT || /sbin/iptables -A FORWARD -i $WAN_IFACE -o $TUN_NAME -m state --state RELATED,ESTABLISHED -j ACCEPT
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
  echo "✅ Started: dnstt-${PORT}.service → 127.0.0.1:$PORT"
done

sysctl -w net.ipv4.ip_forward=1
grep -qxF "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

echo
echo "✅ All DNSTT services running with TUN + SEGMENT on ports: ${PORT_ARRAY[*]}"