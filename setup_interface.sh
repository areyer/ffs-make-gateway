setup_interface_seg00() {
cat <<EOF >/etc/network/interfaces.d/ffs-seg00
auto br00
iface br00 inet static
	bridge_hw 02:00:0a:39:00:$GWLID
        address $LEGIP
        netmask 255.255.192.0
        bridge_ports none
        bridge_fd 0
        bridge_maxwait 0
	broadcast 172.21.63.255
        # be sure all incoming traffic is handled by the appropriate rt_table
        post-up         /sbin/ip rule add iif \$IFACE table stuttgart priority 10000 || true
        pre-down        /sbin/ip rule del iif \$IFACE table stuttgart priority 10000 || true
        post-up         /sbin/ip rule add iif \$IFACE table nodefault priority 10001 || true
        pre-down        /sbin/ip rule del iif \$IFACE table nodefault priority 10001 || true
        # default route is unreachable
        post-up         /sbin/ip route add 172.21.0.0/18 dev \$IFACE table stuttgart || true
        post-up         /sbin/ip route add unreachable default table nodefault || true
        post-down       /sbin/ip route del unreachable default table nodefault || true
        post-down       /sbin/ip route del 172.21.0.0/18 dev \$IFACE table stuttgart || true
 
iface br00 inet6 static
        address fd21:b4dc:4b1e::a38:$GWLID
        netmask 64
        # ULA route mz for rt_table stuttgart
        post-up         /sbin/ip -6 route add fd21:b4dc:4b1e::/64 proto static dev \$IFACE table stuttgart || true
        post-down       /sbin/ip -6 route del fd21:b4dc:4b1e::/64 proto static dev \$IFACE table stuttgart || true

allow-hotplug bat00
iface bat00 inet6 manual
        pre-up          /sbin/modprobe batman-adv || true
        pre-up          /sbin/ip link set \$IFACE address 02:00:0a:39:00:$GWLID up || true
        post-up         /sbin/ip link set \$IFACE up || true
        post-up         /sbin/brctl addif br00 \$IFACE || true
        post-up         /usr/sbin/batctl -m \$IFACE it 10000 || true
        post-up         /usr/sbin/batctl -m \$IFACE vm server || true
        post-up         /usr/sbin/batctl -m \$IFACE gw server  50mbit/50mbit || true
        pre-down        /sbin/brctl delif br00 \$IFACE || true
	post-up         /usr/sbin/service alfred@00 start || true
	pre-down        /usr/sbin/service alfred@00 stop || true

allow-hotplug vpn00
iface vpn00 inet6 manual
	hwaddress 02:00:0a:38:00:${GWLID}
	pre-up		/sbin/modprobe batman_adv || true
        pre-up          /sbin/ip link set \$IFACE address 02:00:0a:38:00:$GWLID up || true
        post-up         /sbin/ip link set dev \$IFACE up || true
        post-up         /usr/sbin/batctl -m bat00 if add \$IFACE || true
EOF
}
