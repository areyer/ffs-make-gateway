setup_firewall() {
  if [ "x$OPT_FWLIHAS" == "x1" ]; then
    mkdir -p /etc/firewall.lihas.d/interface-lo
    # Uplink VPN Interface
    mkdir -p /etc/firewall.lihas.d/interface-tun9
    # Externes Interface
    mkdir -p /etc/firewall.lihas.d/interface-$EXT_IF_V4
    ensureline 0.0.0.0/0 /etc/firewall.lihas.d/interface-$EXT_IF_V4/network
    ensureline 0.0.0.0/0 /etc/firewall.lihas.d/interface-lo/network
    for port in 10037 $(seq 10040 10044); do
      ensureline "0.0.0.0/0 0.0.0.0/0 udp $port" /etc/firewall.lihas.d/interface-$EXT_IF_V4/privclients
      ensureline "0.0.0.0/0 0.0.0.0/0 udp $port" /etc/firewall.lihas.d/interface-lo/privclients
    done
    # monitoring from lenny.ua25.de
    ensureline "88.198.194.43 0.0.0.0/0 tcp 6556" /etc/firewall.lihas.d/interface-$EXT_IF_V4/privclients
    ensureline "0.0.0.0/0 0.0.0.0/0 udp 67" /etc/firewall.lihas.d/interface-lo/privclients
    ensureline "0.0.0.0/0 0.0.0.0/0 tcp 4242" /etc/firewall.lihas.d/interface-lo/privclients
    # tinc geht zu irgend welchen Ports
    ensureline "0.0.0.0/0 0.0.0.0/0 udp 0" /etc/firewall.lihas.d/interface-lo/privclients
    ensureline "0.0.0.0/0 0.0.0.0/0 tcp 0" /etc/firewall.lihas.d/interface-lo/privclients
    ensureline "0.0.0.0/0 0.0.0.0/0 icmp 0" /etc/firewall.lihas.d/interface-lo/privclients
    # Referenz Interface Freifunk
    mkdir -p /etc/firewall.lihas.d/interface-br00
    for i in $(seq 1 4); do
      if [ ! -e /etc/firewall.lihas.d/interface-br0$i ]; then
        ln -s /etc/firewall.lihas.d/interface-br00 /etc/firewall.lihas.d/interface-br0$i
      fi
      if [ ! -e /etc/firewall.lihas.d/interface-bat0$i ]; then
        ln -s /etc/firewall.lihas.d/interface-br00 /etc/firewall.lihas.d/interface-bat0$i
      fi
    done
    if [ ! -e /etc/firewall.lihas.d/interface-bat00 ]; then
      ln -s /etc/firewall.lihas.d/interface-br00 /etc/firewall.lihas.d/interface-bat00
    fi
    ensureline 172.21.0.0/16 /etc/firewall.lihas.d/interface-br00/network
    ensureline 10.190.0.0/15 /etc/firewall.lihas.d/interface-br00/network
    ensureline dhcpd /etc/firewall.lihas.d/interface-br00/mark
    ensureline "0.0.0.0/0 hostgroup-gw$GWLID tcp 0" /etc/firewall.lihas.d/interface-br00/privclients
    ensureline "0.0.0.0/0 hostgroup-gw$GWLID udp 0" /etc/firewall.lihas.d/interface-br00/privclients
    ensureline "0.0.0.0/0 hostgroup-gw$GWLID icmp 0" /etc/firewall.lihas.d/interface-br00/privclients
    ensureline "hostgroup-gw$GWLID 255.255.255.255 udp 68" /etc/firewall.lihas.d/interface-br00/privclients
    for iface in tun9 br00 br01 br03 br04 ffsbb; do
      ensureline "0.0.0.0/0 0.0.0.0/0 tcp 0 $iface" /etc/firewall.lihas.d/interface-br00/privclients
      ensureline "0.0.0.0/0 0.0.0.0/0 udp 0 $iface" /etc/firewall.lihas.d/interface-br00/privclients
      ensureline "0.0.0.0/0 0.0.0.0/0 icmp 0 $iface" /etc/firewall.lihas.d/interface-br00/privclients
    done
    for iface in tun9 $EXT_IF_V4; do
      ensureline "0.0.0.0/0 0.0.0.0/0 tcp 0" /etc/firewall.lihas.d/interface-$iface/masquerade
      ensureline "0.0.0.0/0 0.0.0.0/0 udp 0" /etc/firewall.lihas.d/interface-$iface/masquerade
      ensureline "0.0.0.0/0 0.0.0.0/0 icmp 0" /etc/firewall.lihas.d/interface-$iface/masquerade
    done
    for i in $(seq 0 4); do
      for j in $(seq 0 4); do
        ensureline "IPT_FILTER '-A FORWARD -j ACCEPT -i br0$i -o br0$j'" /etc/firewall.lihas.d/localhost
      done
    done
    ensureline "IPT_FILTER '-A FORWARD -j ACCEPT -i ffsbb -o ffsbb'" /etc/firewall.lihas.d/localhost
    ensureline "IPT_FILTER '-A INPUT -j ACCEPT -i ffsbb -p 2'" /etc/firewall.lihas.d/localhost
    ensureline "IPT_FILTER '-A INPUT -j ACCEPT -i ffsbb -p 89'" /etc/firewall.lihas.d/localhost
    ensureline "IPT_FILTER '-A OUTPUT -j ACCEPT -o ffsbb -p 2'" /etc/firewall.lihas.d/localhost
    ensureline "IPT_FILTER '-A OUTPUT -j ACCEPT -o ffsbb -p 89'" /etc/firewall.lihas.d/localhost
    if [ "x$DIRECTTCP" != "x" ]; then
      for port in $DIRECTTCP; do
        ensureline "0.0.0.0/0 0.0.0.0/0 tcp $port" /etc/firewall.lihas.d/interface-br00/privclients
      done
    fi
    ensureline "0.0.0.0/0 0.0.0.0/0 icmp 3" /etc/firewall.lihas.d/interface-br00/privclients
    ensureline "0.0.0.0/0 0.0.0.0/0 icmp 4" /etc/firewall.lihas.d/interface-br00/privclients
    # Loopback, was lokale ausgehend ist
    if [ "x$OTHERGW_IP" != "x" ]; then
      mkdir -p /etc/firewall.lihas.d/policy-routing-othergw
        echo othergw > /etc/firewall.lihas.d/policy-routing-othergw/comment
        echo 0x1000 > /etc/firewall.lihas.d/policy-routing-othergw/key
        echo NET br00 $OTHERGW_IP > /etc/firewall.lihas.d/policy-routing-othergw/gateway
        ensureline "0.0.0.0/0 0.0.0.0/0 tcp 0 othergw" /etc/firewall.lihas.d/policy-routing
        ensureline "0.0.0.0/0 0.0.0.0/0 udp 0 othergw" /etc/firewall.lihas.d/policy-routing
        ensureline "0.0.0.0/0 0.0.0.0/0 icmp 0 othergw" /etc/firewall.lihas.d/policy-routing
    fi
    if [ "x$DIRECTTCP" != "x" ]; then
      mkdir -p /etc/firewall.lihas.d/policy-routing-direct
        echo direct > /etc/firewall.lihas.d/policy-routing-direct/comment
        echo 0x2000 > /etc/firewall.lihas.d/policy-routing-direct/key
        echo NET $EXT_IF_V4 $EXT_GW_V4 > /etc/firewall.lihas.d/policy-routing-direct/gateway
      for port in $DIRECTTCP; do
        ensureline "0.0.0.0/0 0.0.0.0/0 tcp $port direct" /etc/firewall.lihas.d/policy-routing
      done
      for ip in $EXT_IP_V4; do
        ensureline "$ip 0.0.0.0/0 tcp 0 direct" /etc/firewall.lihas.d/policy-routing
        ensureline "$ip 0.0.0.0/0 udp 0 direct" /etc/firewall.lihas.d/policy-routing
        ensureline "$ip 0.0.0.0/0 icmp 0 direct" /etc/firewall.lihas.d/policy-routing
      done
    fi
    if [ ! -e /etc/firewall.lihas.d/interface-br00/policy-routing ]; then
      ln -s /etc/firewall.lihas.d/policy-routing /etc/firewall.lihas.d/interface-br00/policy-routing
    fi
    mkdir -p /etc/firewall.lihas.d/groups
      # Eigene IP Adressen
      echo $EXT_IP_V4 > /etc/firewall.lihas.d/groups/hostgroup-gw$GWLID
      echo $LEGIP >> /etc/firewall.lihas.d/groups/hostgroup-gw$GWLID
      b=190
      for seg in $(seq 0 $SEGMENTS); do
        c=$(($seg*64))
        if [ $c -gt 255 ]; then
          b=191
          c=$((c-256))
        fi
        echo 10.$b.$c.$GWID
      done >> /etc/firewall.lihas.d/groups/hostgroup-gw$GWLID
  fi
}
